fs = require 'fs'
Discord = require 'discord.js'
readline = require 'readline'

discordID = null
discordConfig = null
discordClient = null
discordGuild = null

fatalError = (reason) ->
  console.error "FATAL [heart]: #{reason}"
  process.exit(1)

send = (channelName, text) ->
  channel = discordClient.channels.cache.find (c) ->
    c.name == channelName
  if channel?
    channel.send(text)
  return

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
    else
      console.error "Unknown event type: #{ev.type}"
  return

main = ->
  if not fs.existsSync("heart.json")
    fatalError "Can't find heart.json"

  discordConfig = JSON.parse(fs.readFileSync("heart.json", "utf8"))
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
        user: user.nickname
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
