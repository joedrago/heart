fs = require 'fs'
path = require 'path'
{spawn} = require 'child_process'
util = require 'util'
watch = require 'node-watch'

coffeeName = 'coffee'
if process.platform == 'win32'
  coffeeName += '.cmd'

buildTool = (callback) ->
  coffee = spawn coffeeName, ['-c', '-o', 'build', 'src']
  coffee.stderr.on 'data', (data) ->
    process.stderr.write data.toString()
    process.exit(-1)
  coffee.stdout.on 'data', (data) ->
    print data.toString()
  coffee.on 'exit', (code) ->
    util.log "Tool compilation finished."
    callback?() if code is 0

buildEverything = ->
  buildTool ->

task 'build', 'build JS bundle', (options) ->
  buildEverything()

watchEverything = ->
  util.log "Watching for changes in src"
  watch ['src','package.json'], (evt, filename) ->
    coffeeFileRegex = /\.coffee$/
    if coffeeFileRegex.test(filename) || (filename == 'package.json')
      util.log "Source code #{filename} changed."
      util.log "Regenerating..."
      buildEverything()
  buildEverything()

task 'watch', 'watch everything', (options) ->
  watchEverything()
