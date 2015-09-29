fs = require 'fs'
path = require 'path'

async = require 'async'
_ = require 'lodash'
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
    else cb path.relative process.cwd(), curFilePath

getPackageDirPath = (basedir, cb) -> getPackageFilePath basedir, (file) ->
  cb (if not file then null else path.dirname file)

ident = (x) -> x
getPackageContents = (basedir, packName, field, cb = ident, parse = ident) ->
  getPackageDirPath basedir, (dir) ->
    packPath = path.join dir, S.modulesFolder, packName, S.packageFilename
    if not path then cb S.noPackageJsonFound()
    else fs.readFile packPath, (err, content) ->
      if err then cb S.packageNotFound dir, packName
      else cb null, (try parse (JSON.parse content)[field], packPath catch err
        err.message)

isStringOrArray = (o) -> (typeof o is 'string') or (o instanceof Array)
isObject = (o) -> (not isStringOrArray o) and o instanceof Object

# expand wildcards and arrays
expandFileSelector = (basedir, sel, cb) ->
  if sel instanceof Array
    async.map sel, ((selector, f) -> expandFileSelector basedir, selector, f),
      (err, files) -> if err then cb err else cb null, _.uniq _.flatten files
  else if typeof sel is 'string' then glob sel, {cwd: basedir}, (err, files) ->
    if err then cb err else cb null, files.map (f) -> path.join basedir, f
  else cb new Error "invalid file selector #{sel}"

statsAndFolder = (f, cb) -> fs.stat f, (err, res) ->
  if err then cb err
  else cb null, if res.isDirectory() then f else path.dirname f
getFoldersFromFiles = (files, cb) ->
  async.map files, statsAndFolder, (err, folders) ->
    if err then cb err else cb null, _.uniq folders.filter (f) -> f?

keysGiven = (keysObj) -> keysObj and keysObj.length > 0

getSelectors = (fieldObj, opts, keys, field, packFile) ->
  if isObject fieldObj
    if opts.allTargets then (v for k, v of fieldObj)
    else if not keysGiven keys then throw S.noKeysForTarget field, packFile
    else for key in keys
      if key of fieldObj then fieldObj[key]
      else throw S.keyNotFound field, packFile, key
  else if isStringOrArray fieldObj
    if keysGiven keys then throw S.keyGivenForNoReason field, packFile, keys
    else [fieldObj]
  else throw S.invalidFieldType packFile, field

flattenSelections = (opts, cb) -> (err, sels) ->
  cmds = (_.flatten sels).map (f) -> path.relative process.cwd(), f
  if err then cb err
  else if opts?.folders then getFoldersFromFiles cmds, cb
  else cb err, _.uniq cmds

getAllFilesFromSelection = (folder, opts) -> (sel, cb) ->
  expandFileSelector folder, sel, cb

# generic file-expanding function all the exposed functions which read file
# wildcards depend on
getFilesFromField = (field, basedir, packageName, keys, opts, cb) ->
  if typeof opts is 'function'
    cb = opts
    opts = null
  getPackageContents basedir, packageName, field, null, (contents, packPath) ->
    try
      selectors = getSelectors contents, opts, keys, field, packPath
      folder = path.dirname packPath
      async.map selectors, (getAllFilesFromSelection folder, opts),
        (flattenSelections opts, cb)
    catch err then cb err

usesFoldersMacro = (fun) -> (args..., opts, cb) ->
  if typeof opts is 'function'
    cb = opts
    opts = {folders:yes}
  else
    opts.folders = yes
  fun args..., opts, cb

getFilesFromPackageJsonMacro = (title, fun) -> (args..., opts, cb) ->
  getFilesFromField title, args..., opts, (err, files) ->
    if err then cb err else cb null, fun files

# exposed API
hyphenToCamel = (str) -> str.replace /\-(.)/, (total, g1) -> g1.toUpperCase()

include = usesFoldersMacro getFilesFromPackageJsonMacro 'include', (files) ->
  (files.map (f) -> "-I#{f}/").join ' '

link = getFilesFromPackageJsonMacro 'link', (files) -> files.join ' '

dynamic = getFilesFromPackageJsonMacro 'dynamic', (files) -> files.join ' '

dynamicLink = getFilesFromPackageJsonMacro 'dynamic', (files) ->
  folders = _.uniq (files.map (f) ->
    "-L#{path.dirname f}/")
  filesCleaned = _.uniq (files.map (f) ->
    '-l' + ((path.basename f).replace /^lib|\.so$/gi, ""))
  (folders.concat filesCleaned).join ' '

bin = getFilesFromPackageJsonMacro 'bin', (files) -> files.join ' '

version = (basedir, packName, keys, opts, cb) ->
  field = 'version'
  cb S.keyGivenNotSupported field, keys if keysGiven keys
  getPackageContents basedir, packName, field, cb

module.exports = {
  getPackageFile
  getPackageFilePath
  getPackageDirPath
  getPackageContents
  isStringOrArray
  isObject
  expandFileSelector
  getFoldersFromFiles
  getFilesFromField
  # exposed API
  hyphenToCamel
  commands: {
    include
    link
    dynamic
    dynamicLink
    bin
    version
  }
}
