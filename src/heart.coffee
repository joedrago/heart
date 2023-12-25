fs = require 'fs'
Discord = require 'discord.js'
readline = require 'readline'

discordID = null
discordConfig = null
discordClient = null
discordGuild = null
roleAllowed = {}

nukes = []

fatalError = (reason) ->
  console.error "FATAL [heart]: #{reason}"
  process.exit(1)

send = (channelName, text, images) ->
  if text.length < 1
    return
  if not discordGuild?
    return

  isThread = false
  if matches = channelName.match(/^@@@(.+)/)
    channelName = matches[1]
    isThread = true


  payload =
    content: text
  if images?
      payload.files = images.map (im) -> 
        if im.match(/^\/tmp\//)
          setTimeout ->
            try
              console.error "Removing: #{im}"
              fs.unlinkSync(im)
            catch
              # who cares
          , 10000
          return im
        return Buffer.from(im, 'base64')

  if isThread
    discordGuild.channels.fetchActiveThreads().then((fetched) ->
      fetched.threads.each (thread) ->
        if thread.name == channelName
          try
            await thread.send(payload)
          catch e
            thread.send("Video upload too big! (1)")
    ).catch(console.error)
  else
    channel = discordClient.channels.cache.find (c) ->
      #console.error "c.type: #{c.type}"
      (c.name == channelName) and (c.type == 'GUILD_TEXT')
    if channel?
      try
        await channel.send(payload)
      catch e
        console.error(e)
        channel.send("Video upload too big! (2)")
  return

reply = (username, text, images) ->
  if text.length < 1
    return
  user = discordGuild.members.cache.find (e) ->
    username == e.user.tag
  if user?
    try
      payload =
        content: text
      if images?
        payload.files = images.map (im) -> 
          if im.match(/^\/tmp\//)
            setTimeout ->
              try
                console.error "Removing: #{im}"
                fs.unlinkSync(im)
              catch
                # who cares
            , 10000
            return im
          return Buffer.from(im, 'base64')
      try
        await user.send(payload)
      catch e
        console.error e
        user.send("Video upload too big!(3)")

    catch
      # who cares
      console.error "didnt send message to #{username}, something dumb happened"
  else
    console.error "Can't find user: #{username}"
  return

findRoles = (user, roleNames, chan) ->
  for roleName in roleNames
    if not roleAllowed[roleName]
      send(chan, "ERROR: Role `#{roleName}` is unavailable to be modified this way.")
      return null
  roles = []
  discordGuild.roles.cache.each (e) ->
    for r in roleNames
      if e.name == r
        roles.push e
        break

  if roles.length == 0
    send(chan, "ERROR: Can't find any roles on the server.")
  return roles

findUser = (username, chan) ->
  user = discordGuild.members.cache.find (e) ->
    displayName = e.displayName
    if discordConfig.useTags
      displayName = e.user.tag
    displayName == username
  if not user?
    send(chan, "ERROR: Can't find user `#{username}` on the server.")
  return user

roleAdd = (username, roleNames, chan) ->
  roles = findRoles(user, roleNames, chan)
  if not roles?
    return
  user = findUser(username, chan)
  if not user?
    return
  rolePretty = roles.map (role) ->
    "`#{role.name}`"
  .join(", ")
  plural = ""
  if roles.length > 1
    plural = "s"
  user.roles.add(roles).then ->
    send(chan, "Added role#{plural} #{rolePretty} to user `#{username}`.")
  .catch (err) ->
    send(chan, "ERROR: Failed to add role #{rolePretty} to user `#{username}`: #{err}")

roleDel = (username, roleNames, chan) ->
  roles = findRoles(user, roleNames, chan)
  if not roles?
    return
  user = findUser(username, chan)
  if not user?
    return
  rolePretty = roles.map (role) ->
    "`#{role.name}`"
  .join(", ")
  plural = ""
  if roles.length > 1
    plural = "s"
  user.roles.remove(roles).then ->
    send(chan, "Removed role#{plural} #{rolePretty} from user `#{username}`.")
  .catch (err) ->
    send(chan, "ERROR: Failed to remove roles #{rolePretty} from user `#{username}`: #{err}")

roleList = (username, chan) ->
  user = findUser(username, chan)
  if not user?
    return
  myRoles = ""
  myRolesMap = {}
  user.roles.cache.each (role) ->
    if !roleAllowed[role.name]
      return
    if myRoles.length > 0
      myRoles += ", "
    myRoles += "`#{role.name}`"
    myRolesMap[role.name] = true
  if myRoles.length == 0
    myRoles = "`(none)`"

  availableList = ""
  for availableRole in discordConfig.roles
    if not myRolesMap[availableRole]
      if availableList.length > 0
        availableList += ", "
      availableList += "`#{availableRole}`"
  if availableList.length == 0
    availableList = "`(none)`"
  send(chan, "`#{username}`'s roles: #{myRoles}. Available: #{availableList}")

onTick = ->
  ev =
    type: 'tick'
  console.log JSON.stringify(ev)

onFastTick = ->
  ev =
    type: 'ftick'
  console.log JSON.stringify(ev)

onInputEvent = (ev) ->
  if ev.text? and (ev.text.length > 2000)
    ev.text = ev.text.substr(0, 1999)
  switch ev.type
    when 'msg'
      if ev.chan? and ev.text? and ev.delay?
        delay = parseInt(ev.delay)
        setTimeout ->
          send(ev.chan, ev.text, ev.images)
        , delay
    when 'reply'
      if ev.user? and ev.text?
        reply(ev.user, ev.text, ev.images)
    when 'radd'
      if ev.user? and ev.role? and ev.chan?
        roleAdd(ev.user, ev.role.split(/\s+/), ev.chan)
    when 'rdel'
      if ev.user? and ev.role? and ev.chan?
        roleDel(ev.user, ev.role.split(/\s+/), ev.chan)
    when 'rlist'
      if ev.user? and ev.chan?
        roleList(ev.user, ev.chan)
    else
      console.error "Unknown event type: #{ev.type}"
  return

main = ->
  args = process.argv.slice(2)
  configFilename = args.shift()
  if not configFilename?
    configFilename = "heart.json"

  if not fs.existsSync(configFilename)
    fatalError "Can't find " + configFilename

  discordConfig = JSON.parse(fs.readFileSync(configFilename, "utf8"))
  for role in discordConfig.roles
    roleAllowed[role] = true

  if discordConfig.nukes?
    nukes = discordConfig.nukes

  discordClient = new Discord.Client({ partials: ["CHANNEL"], intents: [Discord.Intents.FLAGS.GUILDS, Discord.Intents.FLAGS.GUILD_MESSAGES, Discord.Intents.FLAGS.DIRECT_MESSAGES]})
  discordClient.on 'ready', ->
    console.log JSON.stringify {
      type: 'login'
      tag: discordClient.user.tag
    }
    discordID = discordClient.user.id
    discordClient.guilds.fetch(discordConfig.guild).then (guild) ->
      discordGuild = guild

  discordClient.on 'messageCreate', (msg) ->
    if discordGuild == null
      return

    #msg.channel.threads.cache.each (thread) ->
    #  console.error "thread: ", thread

    discordGuild.members.fetch(msg).then (user) ->
      if user.id == discordClient.user.id
        # Don't respond to yourself
        return

      for nuke in nukes
        if msg.content.match(nuke.regex)
          if not nuke.ignoreChannels[msg.channel.name]
            if nuke.dm
              user.send("Message nuked by Skittles rule: `#{nuke.name}`\n> #{msg.content}")
            msg.delete()
            return

      channelName = msg.channel.name
      if msg.channel.isThread()
        channelName = "@@@" + channelName

      displayName = user.displayName
      if discordConfig.useTags
        displayName = user.user.tag

      if msg.channel.type == 'DM'
        ev =
          type: 'dm'
          user: user.user.tag
          tag: user.user.tag
          text: msg.content
      else
        ev =
          type: 'msg'
          chan: channelName
          user: displayName
          tag: user.user.tag
          text: msg.content

      if msg.attachments?
        msg.attachments.each (a) ->
          if a.url? and ((a.contentType == "image/png") or (a.contentType == "image/jpg") or (a.contentType == "image/jpeg"))
            ev.image = a.url

      console.log JSON.stringify(ev)

  setInterval onTick, (60 * 1000)
  setInterval onFastTick, (5 * 1000)

  rl = readline.createInterface {
    input: process.stdin
    #output: process.stderr
  }
  rl.on 'line', (rawJSON) ->
    ev = null
    try
      ev = JSON.parse(rawJSON)
    catch
      console.error "Ignoring invalid JSON: #{rawJSON}"
      return
    try
      onInputEvent(ev)
    catch e
      console.error(e)
      console.error("onInputEvent failed, caught!")

  discordClient.login(discordConfig.secrets.discord)

module.exports = main
