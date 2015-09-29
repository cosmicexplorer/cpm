fs = require 'fs'
path = require 'path'

S = require './strings'
libCmd = require './lib-command'

argv = require('minimist')(process.argv[2..])

getOptionArg = (obj, char) -> obj[char] or obj[S.shortLongOptionMap[char]]
errorOut = (msg) ->
  console.error msg
  process.exit 1

help = getOptionArg argv, 'h'
version = getOptionArg argv, 'v'
noColor = getOptionArg argv, 'c'
server = getOptionArg argv, 's'

if version
  f = JSON.parse fs.readFileSync path.normalize
    "#{__dirname}/../#{S.packageFilename}"
  console.log f.version
  process.exit 0
else if help or (argv._.length is 0)
  console.log S.helpMsg
  process.exit 0
else
  packagePath = libCmd.getPackageFilePath process.cwd(), (path) ->
    if path is null then errorOut S.noPackageFound
    else
      packageDir = path.dirname packagePath
      command = argv._[0]
      cmdFun = libCmd[command]
      errorOut S.commandNotFound command unless cmdFun
      cmdFun packageDir, argv._[1], argv._[2..],
        {noColor, server}, (err, output) ->
        if err then errorOut err
        else process.stdout.write output.join '\n'
