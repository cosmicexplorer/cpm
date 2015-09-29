fs = require 'fs'
path = require 'path'

_ = require 'lodash'
promise = require 'promise'
glob = require 'glob'

S = require './strings'
colorize = require './colorize'

getPackageFile = (basedir) -> path.join basedir, S.packageFileName

getPackageFilePath = (basedir, cb) ->
    curFilePath = getPackageFile basedir
    fs.stat curFilePath, (err, stat) ->
      if err
        parsed = path.parse basedir
        if parsed.root is parsed.dir then cb null
        else getPackageFilePath (path.join basedir, '..'), cb
      else cb curFilePath

isStringOrArray = (o) -> (typeof o is 'string') or (o instanceof Array)
isObject = (o) -> (not isStringOrArray o) and o instanceof Object

# expand wildcards and arrays
globPromise = promise.denodeify glob
expandFileSelector = (basedir, sel, cb) ->
  if sel instanceof Array
    (promise.all (expandFilePromise basedir, f for f in sel)).then (files) ->
      cb _.uniq files
  else if typeof sel is 'string' then glob sel, {cwd: basedir}, cb
  else throw new Error "invalid file selector #{sel}"
expandFilePromise = promise.denodeify expandFileSelector

statsAndFile = (f, cb) -> fs.stat f, (err, res) ->
  if err then null else if res.isDirectory() then res else path.dirname res
statPromise = promise.denodeify statsAndFile
getFoldersFromFiles = (files, cb) ->
  (promise.all (statPromise f for f in files)).then (folders) ->
    cb _.uniq folders.filter (f) -> f?

getFilesFromField = (field, folderSpec, basedir, packageName, keys, opts, cb) ->
  if typeof opts is 'function'
    cb = opts
    opts = null
  folder = path.join basedir, S.modulesFolder, packageName
  packFile = path.join folder, S.packageFilename
  fs.readFile packFile, (err, contents) ->
    try fieldObj = (JSON.parse contents)[field] catch err then cb err
    if err then cb S.packageNotFound basedir, packageName
    else
      try
        res = if isObject fieldObj
            if keys then throw S.noKeysForTarget field, packFile
            for key in keys
              if key in fieldObj
                expandFileSelector folder, fieldObj[key]
              else throw S.keyNotFound field, packFile, key
          else if isStringOrArray fieldObj
            [expandFileSelector folder, fieldObj]
          else throw S.invalidFieldType packFile, field
        cmds = _.flatten res
        if folderSpec?.folders then getFoldersFromFiles cmds, (folders) ->
          cb null, folders
        else cb null, _.uniq cmds
      catch err then cb err

include = (args..., cb) ->
  getFilesFromField 'include', {folders: yes}, args..., (err, files) ->
    if err then cb err else cb null, (files.map (f) -> "-I.#{f}").join ' '

module.exports = {
  getPackageFilePath
  isStringOrArray
  isObject
  getPackageFile
  expandFileSelector
  getFoldersFromFiles
  getFilesFromField
  include
}
