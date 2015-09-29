fs = require 'fs'
path = require 'path'

async = require 'async'
# _ = require 'lodash'
glob = require 'glob'

S = require "#{__dirname}/strings"
colorize = require "#{__dirname}/colorize"

getPackageFile = (basedir) -> path.join basedir, S.packageFilename

getPackageFilePath = (basedir, cb) ->
  curFilePath = getPackageFile basedir
  fs.stat curFilePath, (err, stat) ->
    if err
      parsed = path.parse path.resolve basedir
      if parsed.root is parsed.dir then cb null
      else getPackageFilePath (path.join basedir, '..'), cb
    else cb curFilePath

getPackageDirPath = (basedir, cb) -> getPackageFilePath basedir, (file) ->
  cb (if not file then null else path.dirname file)

isStringOrArray = (o) -> (typeof o is 'string') or (o instanceof Array)
isObject = (o) -> (not isStringOrArray o) and o instanceof Object

# expand wildcards and arrays
lo = require 'lodash'
expandFileSelector = (basedir, sel, cb) ->
  if sel instanceof Array
    async.map sel, ((selector, asyncCb) ->
      expandFileSelector basedir, selector, asyncCb),
      (err, files) -> if err then cb err else cb null, lo.uniq lo.flatten files
  else if typeof sel is 'string' then glob sel, {cwd: basedir}, (err, files) ->
    if err then cb err
    else cb null, files.map (f) -> path.join basedir, f
  else cb new Error "invalid file selector #{sel}"

statsAndFolder = (f, cb) -> fs.stat f, (err, res) ->
  if err then cb err
  else cb null, if res.isDirectory() then f else path.dirname f
getFoldersFromFiles = (files, cb) ->
  async.map files, statsAndFolder, (err, folders) ->
    if err then cb err else cb null, lo.uniq folders.filter (f) -> f?

getFilesFromField = (field, basedir, packageName, keys, opts, cb) ->
  if typeof opts is 'function'
    cb = opts
    opts = null
  getPackageDirPath basedir, (packDir) ->
    return cb S.noPackageFound unless packDir?
    folder = path.join packDir, S.modulesFolder, packageName
    packFile = path.join folder, S.packageFilename
    fs.readFile packFile, (err, contents) ->
      if err then cb S.packageNotFound basedir, packageName
      else
        try fieldObj = (JSON.parse contents)[field] catch err then return cb err
        try
          selectors = if isObject fieldObj
              throw S.noKeysForTarget field, packFile unless keys
              for key in keys
                if key of fieldObj then fieldObj[key]
                else throw S.keyNotFound field, packFile, key
            else if isStringOrArray fieldObj then fieldObj
            else throw S.invalidFieldType packFile, field
          async.map selectors, ((sel, asyncCb) ->
            expandFileSelector folder, sel, asyncCb),
            (err, sels) ->
              cmds = lo.flatten sels
              if err then cb err
              else if opts?.folders
                getFoldersFromFiles cmds, cb
              else cb err, lo.uniq cmds
        catch err then cb err

usesFoldersMacro = (fun) -> (args..., opts, cb) ->
  if typeof opts is 'function'
    cb = opts
    opts = {folders:yes}
  else
    opts.folders = yes
  fun args..., opts, cb

exposedAPIMacro = (title, fun) -> (args..., opts, cb) ->
  getFilesFromField title, args..., opts, (err, files) ->
    if err then cb err else cb null, fun files

include = usesFoldersMacro (args..., opts, cb) ->
  getFilesFromField 'include', args..., opts, (err, files) ->
    if err then cb err else cb null, (files.map (f) ->
      "-I#{path.relative process.cwd(), f}/").join ' '

link = exposedAPIMacro 'link', (files) -> files.join ' '

dynamic = (args..., opts, cb) ->
  getFilesFromField 'dynamic', args..., opts, (err, files) ->
    if err then cb err else cb null, files.join ' '

module.exports = {
  getPackageFilePath
  getPackageDirPath
  isStringOrArray
  isObject
  getPackageFile
  expandFileSelector
  getFoldersFromFiles
  getFilesFromField
  # exposed API
  include
  link
  dynamic
}
