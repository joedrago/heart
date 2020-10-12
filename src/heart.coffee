fs = require 'fs'
Discord = require 'discord.js'
readline = require 'readline'

discordID = null
discordConfig = null
discordClient = null
discordGuild = null
roleAllowed = {}

fatalError = (reason) ->
  console.error "FATAL [heart]: #{reason}"
  process.exit(1)

send = (channelName, text) ->
  channel = discordClient.channels.cache.find (c) ->
    (c.name == channelName) and (c.type == 'text')
  if channel?
    channel.send(text)
  return

findRole = (user, roleName, chan) ->
  if not roleAllowed[roleName]
    send(chan, "ERROR: Role `#{roleName}` is unavailable to be modified this way.")
    return null
  role = discordGuild.roles.cache.find (e) ->
    e.name == roleName
  if not role?
    send(chan, "ERROR: Can't find role `#{roleName}` on the server.")
  return role

findUser = (username, chan) ->
  user = discordGuild.members.cache.find (e) ->
    e.displayName == username
  if not user?
    send(chan, "ERROR: Can't find user `#{username}` on the server.")
  return user

roleAdd = (username, roleName, chan) ->
  role = findRole(user, roleName, chan)
  if not role?
    return
  user = findUser(username, chan)
  if not user?
    return
  user.roles.add(role).then ->
    send(chan, "Added role `#{roleName}` to user `#{username}`.")
  .catch (err) ->
    send(chan, "ERROR: Failed to add role `#{roleName}` to user `#{username}`: #{err}")

roleDel = (username, roleName, chan) ->
  role = findRole(user, roleName, chan)
  if not role?
    return
  user = findUser(username, chan)
  if not user?
    return
  user.roles.remove(role).then ->
    send(chan, "Removed role `#{roleName}` from user `#{username}`.")
  .catch (err) ->
    send(chan, "ERROR: Failed to remove role `#{roleName}` from user `#{username}`: #{err}")

roleList = (chan) ->
  list = discordConfig.roles.map (role) ->
    "`#{role}`"
  .join(", ")
  send(chan, "Roles: #{list}")

onTick = ->
  ev =
    type: 'tick'
  console.log JSON.stringify(ev)

onInputEvent = (ev) ->
  switch ev.type
    when 'msg'
      if ev.chan? and ev.text? and ev.delay?
        delay = parseInt(ev.delay)
        setTimeout ->
          send(ev.chan, ev.text)
        , delay
    when 'radd'
      if ev.user? and ev.role? and ev.chan?
        roleAdd(ev.user, ev.role, ev.chan)
    when 'rdel'
      if ev.user? and ev.role? and ev.chan?
        roleDel(ev.user, ev.role, ev.chan)
    when 'rlist'
      if ev.chan?
        roleList(ev.chan)
    else
      console.error "Unknown event type: #{ev.type}"
  return

main = ->
  if not fs.existsSync("heart.json")
    fatalError "Can't find heart.json"

  discordConfig = JSON.parse(fs.readFileSync("heart.json", "utf8"))
  for role in discordConfig.roles
    roleAllowed[role] = true

  discordClient = new Discord.Client()
  discordClient.on 'ready', ->
    console.log JSON.stringify {
      type: 'login'
      tag: discordClient.user.tag
    }
    discordClient.guilds.fetch(discordConfig.guild).then (guild) ->
      discordGuild = guild

  discordClient.on 'message', (msg) ->
    if discordGuild == null
      return

    discordGuild.members.fetch(msg).then (user) ->
      if user.id == discordClient.user.id
        # Don't respond to yourself
        return

      ev =
        type: 'msg'
        chan: msg.channel.name
        user: user.displayName
        text: msg.content

      console.log JSON.stringify(ev)

  setInterval onTick, (60 * 1000)

  rl = readline.createInterface {
    input: process.stdin
    output: process.stderr
  }
  rl.on 'line', (rawJSON) ->
    ev = null
    try
      ev = JSON.parse(rawJSON)
    catch
      console.error "Ignoring invalid JSON: #{rawJSON}"
      return
    onInputEvent(ev)

  discordClient.login(discordConfig.secrets.discord)

module.exports = main
