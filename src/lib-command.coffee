fs = require 'fs'
path = require 'path'

async = require 'async'
lo = require 'lodash'
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

isStringOrArray = (o) -> (typeof o is 'string') or (o instanceof Array)
isObject = (o) -> (not isStringOrArray o) and o instanceof Object

# expand wildcards and arrays
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

getSelectors = (fieldObj, opts, keys, field, packFile) ->
  switch
    when isObject fieldObj
      if opts.allTargets then (v for k, v of fieldObj)
      else if not (keys and keys.length > 0)
        throw S.noKeysForTarget field, packFile
      else
        for key in keys
          if key of fieldObj then fieldObj[key]
          else throw S.keyNotFound field, packFile, key
    when isStringOrArray fieldObj
      if (keys and keys.length > 0)
        throw S.keyGivenForNoReason field, packFile, keys
      else [fieldObj]
    else throw S.invalidFieldType packFile, field

flattenSelections = (opts, cb) -> (err, sels) ->
  cmds = (lo.flatten sels).map (f) -> path.relative process.cwd(), f
  if err then cb err
  else if opts?.folders
    getFoldersFromFiles cmds, cb
  else cb err, lo.uniq cmds

getAllFilesFromSelection = (folder, opts) -> (sel, asyncCb) ->
  expandFileSelector folder, sel, asyncCb

readPackfile = (packFile, field, opts, packName, keys, folder, cb) ->
  fs.readFile packFile, (err, contents) ->
    if err then cb S.packageNotFound basedir, packName
    else
      try fieldObj = (JSON.parse contents)[field] catch err then return cb err
      try
        selectors = getSelectors fieldObj, opts, keys, field, packFile
        async.map selectors, (getAllFilesFromSelection folder, opts),
          (flattenSelections opts, cb)
      catch err then cb err

getFilesFromField = (field, basedir, packageName, keys, opts, cb) ->
  if typeof opts is 'function'
    cb = opts
    opts = null
  getPackageDirPath basedir, (packDir) ->
    return cb S.noPackageFound unless packDir?
    folder = path.join packDir, S.modulesFolder, packageName
    packFile = path.join folder, S.packageFilename
    readPackfile packFile, field, opts, packageName, keys, folder, cb

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

# exposed API
hyphenToCamel = (str) -> str.replace /\-(.)/, (total, g1) -> g1.toUpperCase()

include = usesFoldersMacro exposedAPIMacro 'include', (files) ->
  (files.map (f) -> "-I#{f}/").join ' '

link = exposedAPIMacro 'link', (files) -> files.join ' '

dynamic = exposedAPIMacro 'dynamic', (files) -> files.join ' '

dynamicLink = exposedAPIMacro 'dynamic', (files) ->
  folders = lo.uniq (files.map (f) ->
    "-L#{path.dirname f}/")
  filesCleaned = lo.uniq (files.map (f) ->
    '-l' + ((path.basename f).replace /^lib|\.so$/, ""))
  (folders.concat filesCleaned).join ' '

bin = exposedAPIMacro 'bin', (files) -> files.join ' '

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
  hyphenToCamel
  commands: {
    include
    link
    dynamic
    dynamicLink
    bin
  }
}
