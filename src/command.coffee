fs = require 'fs'
path = require 'path'

S = require "#{__dirname}/src/strings"
libCmd = require "#{__dirname}/src/lib-commands"

argv = require('minimist')(process.argv[2..])

getOptionArg = (obj, char) -> obj[char] or obj[S.shortLongOptionMap[char]]
errorOut = (msg) ->
  console.error msg
  process.exit 1

help = getOptionArg argv, 'h'
version = getOptionArg argv, 'v'
noColor = getOptionArg argv, 'c'
server = getOptionArg argv, 's'
allTargets = getOptionArg argv, 'a'
allTargets = (allTargets is 'true') if typeof allTargets is 'string'

if version
  f = JSON.parse fs.readFileSync path.normalize(
    "#{__dirname}/#{S.packageFilename}")
  console.log f.version
  process.exit 0
else if help or (argv._.length is 0)
  console.log S.helpMsg
  process.exit 0
else
  command = argv._[0]
  cmdFun = libCmd.commands[libCmd.hyphenToCamel command]
  errorOut S.commandNotFound command unless cmdFun
  cmdFun process.cwd(), argv._[1], argv._[2..],
    {noColor, server, allTargets}, (err, output) ->
      if err then errorOut err
      else console.log output
