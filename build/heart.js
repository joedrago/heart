// Generated by CoffeeScript 2.5.1
(function() {
  var Discord, discordClient, discordConfig, discordGuild, discordID, fatalError, findRoles, findUser, fs, main, nukes, onFastTick, onInputEvent, onTick, readline, reply, roleAdd, roleAllowed, roleDel, roleList, send;

  fs = require('fs');

  Discord = require('discord.js');

  readline = require('readline');

  discordID = null;

  discordConfig = null;

  discordClient = null;

  discordGuild = null;

  roleAllowed = {};

  nukes = [];

  fatalError = function(reason) {
    console.error(`FATAL [heart]: ${reason}`);
    return process.exit(1);
  };

  send = function(channelName, text, image) {
    var channel, isThread, matches, payload;
    if (text.length < 1) {
      return;
    }
    if (discordGuild == null) {
      return;
    }
    isThread = false;
    if (matches = channelName.match(/^@@@(.+)/)) {
      channelName = matches[1];
      isThread = true;
    }
    payload = {
      content: text
    };
    if (image != null) {
      payload.files = [Buffer.from(image, 'base64')];
    }
    if (isThread) {
      discordGuild.channels.fetchActiveThreads().then(function(fetched) {
        return fetched.threads.each(function(thread) {
          if (thread.name === channelName) {
            return thread.send(payload);
          }
        });
      }).catch(console.error);
    } else {
      channel = discordClient.channels.cache.find(function(c) {
        //console.error "c.type: #{c.type}"
        return (c.name === channelName) && (c.type === 'GUILD_TEXT');
      });
      if (channel != null) {
        channel.send(payload);
      }
    }
  };

  reply = function(username, text, image) {
    var payload, user;
    if (text.length < 1) {
      return;
    }
    user = discordGuild.members.cache.find(function(e) {
      return username === e.user.tag;
    });
    if (user != null) {
      try {
        payload = {
          content: text
        };
        if (image != null) {
          payload.files = [Buffer.from(image, 'base64')];
        }
        user.send(payload);
      } catch (error) {
        // who cares
        console.log(`didnt send message to ${username}, something dumb happened`);
      }
    } else {
      console.error(`Can't find user: ${username}`);
    }
  };

  findRoles = function(user, roleNames, chan) {
    var i, len, roleName, roles;
    for (i = 0, len = roleNames.length; i < len; i++) {
      roleName = roleNames[i];
      if (!roleAllowed[roleName]) {
        send(chan, `ERROR: Role \`${roleName}\` is unavailable to be modified this way.`);
        return null;
      }
    }
    roles = [];
    discordGuild.roles.cache.each(function(e) {
      var j, len1, r, results;
      results = [];
      for (j = 0, len1 = roleNames.length; j < len1; j++) {
        r = roleNames[j];
        if (e.name === r) {
          roles.push(e);
          break;
        } else {
          results.push(void 0);
        }
      }
      return results;
    });
    if (roles.length === 0) {
      send(chan, "ERROR: Can't find any roles on the server.");
    }
    return roles;
  };

  findUser = function(username, chan) {
    var user;
    user = discordGuild.members.cache.find(function(e) {
      var displayName;
      displayName = e.displayName;
      if (discordConfig.useTags) {
        displayName = e.user.tag;
      }
      return displayName === username;
    });
    if (user == null) {
      send(chan, `ERROR: Can't find user \`${username}\` on the server.`);
    }
    return user;
  };

  roleAdd = function(username, roleNames, chan) {
    var plural, rolePretty, roles, user;
    roles = findRoles(user, roleNames, chan);
    if (roles == null) {
      return;
    }
    user = findUser(username, chan);
    if (user == null) {
      return;
    }
    rolePretty = roles.map(function(role) {
      return `\`${role.name}\``;
    }).join(", ");
    plural = "";
    if (roles.length > 1) {
      plural = "s";
    }
    return user.roles.add(roles).then(function() {
      return send(chan, `Added role${plural} ${rolePretty} to user \`${username}\`.`);
    }).catch(function(err) {
      return send(chan, `ERROR: Failed to add role ${rolePretty} to user \`${username}\`: ${err}`);
    });
  };

  roleDel = function(username, roleNames, chan) {
    var plural, rolePretty, roles, user;
    roles = findRoles(user, roleNames, chan);
    if (roles == null) {
      return;
    }
    user = findUser(username, chan);
    if (user == null) {
      return;
    }
    rolePretty = roles.map(function(role) {
      return `\`${role.name}\``;
    }).join(", ");
    plural = "";
    if (roles.length > 1) {
      plural = "s";
    }
    return user.roles.remove(roles).then(function() {
      return send(chan, `Removed role${plural} ${rolePretty} from user \`${username}\`.`);
    }).catch(function(err) {
      return send(chan, `ERROR: Failed to remove roles ${rolePretty} from user \`${username}\`: ${err}`);
    });
  };

  roleList = function(username, chan) {
    var availableList, availableRole, i, len, myRoles, myRolesMap, ref, user;
    user = findUser(username, chan);
    if (user == null) {
      return;
    }
    myRoles = "";
    myRolesMap = {};
    user.roles.cache.each(function(role) {
      if (!roleAllowed[role.name]) {
        return;
      }
      if (myRoles.length > 0) {
        myRoles += ", ";
      }
      myRoles += `\`${role.name}\``;
      return myRolesMap[role.name] = true;
    });
    if (myRoles.length === 0) {
      myRoles = "`(none)`";
    }
    availableList = "";
    ref = discordConfig.roles;
    for (i = 0, len = ref.length; i < len; i++) {
      availableRole = ref[i];
      if (!myRolesMap[availableRole]) {
        if (availableList.length > 0) {
          availableList += ", ";
        }
        availableList += `\`${availableRole}\``;
      }
    }
    if (availableList.length === 0) {
      availableList = "`(none)`";
    }
    return send(chan, `\`${username}\`'s roles: ${myRoles}. Available: ${availableList}`);
  };

  onTick = function() {
    var ev;
    ev = {
      type: 'tick'
    };
    return console.log(JSON.stringify(ev));
  };

  onFastTick = function() {
    var ev;
    ev = {
      type: 'ftick'
    };
    return console.log(JSON.stringify(ev));
  };

  onInputEvent = function(ev) {
    var delay;
    if ((ev.text != null) && (ev.text.length > 2000)) {
      ev.text = ev.text.substr(0, 1999);
    }
    switch (ev.type) {
      case 'msg':
        if ((ev.chan != null) && (ev.text != null) && (ev.delay != null)) {
          delay = parseInt(ev.delay);
          setTimeout(function() {
            return send(ev.chan, ev.text, ev.image);
          }, delay);
        }
        break;
      case 'reply':
        if ((ev.user != null) && (ev.text != null)) {
          reply(ev.user, ev.text, ev.image);
        }
        break;
      case 'radd':
        if ((ev.user != null) && (ev.role != null) && (ev.chan != null)) {
          roleAdd(ev.user, ev.role.split(/\s+/), ev.chan);
        }
        break;
      case 'rdel':
        if ((ev.user != null) && (ev.role != null) && (ev.chan != null)) {
          roleDel(ev.user, ev.role.split(/\s+/), ev.chan);
        }
        break;
      case 'rlist':
        if ((ev.user != null) && (ev.chan != null)) {
          roleList(ev.user, ev.chan);
        }
        break;
      default:
        console.error(`Unknown event type: ${ev.type}`);
    }
  };

  main = function() {
    var i, len, ref, rl, role;
    if (!fs.existsSync("heart.json")) {
      fatalError("Can't find heart.json");
    }
    discordConfig = JSON.parse(fs.readFileSync("heart.json", "utf8"));
    ref = discordConfig.roles;
    for (i = 0, len = ref.length; i < len; i++) {
      role = ref[i];
      roleAllowed[role] = true;
    }
    if (discordConfig.nukes != null) {
      nukes = discordConfig.nukes;
    }
    discordClient = new Discord.Client({
      partials: ["CHANNEL"],
      intents: [Discord.Intents.FLAGS.GUILDS, Discord.Intents.FLAGS.GUILD_MESSAGES, Discord.Intents.FLAGS.DIRECT_MESSAGES]
    });
    discordClient.on('ready', function() {
      console.log(JSON.stringify({
        type: 'login',
        tag: discordClient.user.tag
      }));
      discordID = discordClient.user.id;
      return discordClient.guilds.fetch(discordConfig.guild).then(function(guild) {
        return discordGuild = guild;
      });
    });
    discordClient.on('messageCreate', function(msg) {
      if (discordGuild === null) {
        return;
      }
      //msg.channel.threads.cache.each (thread) ->
      //  console.error "thread: ", thread
      return discordGuild.members.fetch(msg).then(function(user) {
        var channelName, displayName, ev, j, len1, nuke;
        if (user.id === discordClient.user.id) {
          return;
        }
// Don't respond to yourself
        for (j = 0, len1 = nukes.length; j < len1; j++) {
          nuke = nukes[j];
          if (msg.content.match(nuke.regex)) {
            if (!nuke.ignoreChannels[msg.channel.name]) {
              if (nuke.dm) {
                user.send(`Message nuked by Skittles rule: \`${nuke.name}\`\n> ${msg.content}`);
              }
              msg.delete();
              return;
            }
          }
        }
        channelName = msg.channel.name;
        if (msg.channel.isThread()) {
          channelName = "@@@" + channelName;
        }
        displayName = user.displayName;
        if (discordConfig.useTags) {
          displayName = user.user.tag;
        }
        if (msg.channel.type === 'DM') {
          ev = {
            type: 'dm',
            user: user.user.tag,
            tag: user.user.tag,
            text: msg.content
          };
        } else {
          ev = {
            type: 'msg',
            chan: channelName,
            user: displayName,
            tag: user.user.tag,
            text: msg.content
          };
        }
        if (msg.attachments != null) {
          msg.attachments.each(function(a) {
            if ((a.url != null) && a.contentType === "image/png") {
              return ev.image = a.url;
            }
          });
        }
        return console.log(JSON.stringify(ev));
      });
    });
    setInterval(onTick, 60 * 1000);
    setInterval(onFastTick, 5 * 1000);
    rl = readline.createInterface({
      input: process.stdin,
      output: process.stderr
    });
    rl.on('line', function(rawJSON) {
      var ev;
      ev = null;
      try {
        ev = JSON.parse(rawJSON);
      } catch (error) {
        console.error(`Ignoring invalid JSON: ${rawJSON}`);
        return;
      }
      return onInputEvent(ev);
    });
    return discordClient.login(discordConfig.secrets.discord);
  };

  module.exports = main;

}).call(this);
