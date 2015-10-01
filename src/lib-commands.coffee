fs = require 'fs'
path = require 'path'
zlib = require 'zlib'

async = require 'async'
lo = require 'lodash'
glob = require 'glob'
tar = require 'tar-fs'
base64 = require 'base64-stream'
DumpStream = require 'dump-stream'

S = require "./strings"
webCommands = require './web-commands'

VERSION_STRING_LENGTH = 3


# auxiliary methods
getPackageFilePath = (basedir, cb) ->
  curFilePath = _getPackageFile basedir
  fs.stat curFilePath, (err, stat) ->
    if err
      parsed = path.parse path.resolve basedir
      if parsed.root is parsed.dir then cb null
      else getPackageFilePath (path.join basedir, '..'), cb
    else cb path.relative process.cwd(), curFilePath

getPackageDirPath = (basedir, cb) -> getPackageFilePath basedir, (file) ->
  cb (if not file then null else path.dirname file)

getCurrentPackageText = (basedir, cb) ->
  getPackageFilePath (packPath) ->
    return cb S.noPackageJsonFound unless packPath
    fs.readFile path, (err, res) -> cb err, res.toString()

getJsonTextOfPackage = (basedir, packName, cb) ->
  getPackageDirPath basedir, (dir) ->
    packPath = path.join dir, S.modulesFolder, packName, S.packageFilename
    if not path then cb S.noPackageJsonFound()
    else fs.readFile packPath, (err, content) ->
      if err then cb S.packageNotFound dir, packName
      else cb null, content.toString(), packPath

ident = (x) -> x
getPackageContents = (basedir, packName, field, cb = ident, parse = ident) ->
  getJsonTextOfPackage basedir, packName, (err, contents, packPath) ->
    if err then cb err else cb null, (try
        parse (JSON.parse contents)[field], packPath

isStringOrArray = (o) -> (typeof o is 'string') or (o instanceof Array)
isObject = (o) -> (not isStringOrArray o) and o instanceof Object

# expand wildcards and arrays
expandFileSelector = (basedir, sel, cb) ->
  if sel instanceof Array
    async.map sel, ((selector, f) -> expandFileSelector basedir, selector, f),
      (err, files) -> if err then cb err else cb null, lo.uniq lo.flatten files
  else if typeof sel is 'string' then glob sel, {cwd: basedir}, (err, files) ->
    if err then cb err else cb null, files.map (f) -> path.join basedir, f
  else cb new Error "invalid file selector #{sel}"

statsAndFolder = (f, cb) -> fs.stat f, (err, res) ->
  if err then cb err
  else cb null, if res.isDirectory() then f else path.dirname f
getFoldersFromFiles = (files, cb) ->
  async.map files, statsAndFolder, (err, folders) ->
    if err then cb err else cb null, lo.uniq folders.filter (f) -> f?


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
  cmds = (lo.flatten sels).map (f) -> path.relative process.cwd(), f
  if err then cb err
  else if opts?.folders then getFoldersFromFiles cmds, cb
  else cb err, lo.uniq cmds

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

ifNotExistThrow = (basedir, pack, cb) ->
  finalPathFolder = path.join basedir, S.modulesFolder, pack
  fs.stat finalPathFolder, (err) ->
    if err then cb S.packageNotFound basedir, pack
    else cb finalPathFolder

numRegexMatch = (num) -> num.match /^[0-9]+/g
doComparison = (num, specNum, comparison, version_spec) ->
  switch comparison
    when '<=' then specNum >= num
    when '>=' then specNum <= num
    when '<' then specNum > num
    when '>' then specNum < num
    else throw new Error "invalid version string #{version_spec}"


### exposed API ###
# utility methods
hyphenToCamel = (str) -> str.replace /\-(.)/, (total, g1) -> g1.toUpperCase()

compareVersionStrings = (version, version_spec) ->
  return yes unless version_spec
  nums = version.split '.'
  specNums = version_spec.split '.'
  comparison = null
  for i in [0..(VERSION_STRING_LENGTH - 1)]
    if comparison
      return no unless numRegexMatch specNums[i]
    else if not numRegexMatch specNums[i]
      nonNumeric = specNums[i].replace /[0-9]/g, ""
      numeric = specNums[i].replace /[^0-9]/g, ""
      if not doComparison nums[i], numeric, nonNumeric, version_spec
        return no
      comparison = nonNumeric
    else return no if nums[i] isnt specNums[i]
  yes


# build system commands
include = usesFoldersMacro getFilesFromPackageJsonMacro 'include', (files) ->
  (files.map (f) -> "-I#{f}/").join ' '

link = getFilesFromPackageJsonMacro 'link', (files) -> files.join ' '

dynamic = getFilesFromPackageJsonMacro 'dynamic', (files) -> files.join ' '

dynamicLink = getFilesFromPackageJsonMacro 'dynamic', (files) ->
  folders = lo.uniq (files.map (f) ->
    "-L#{path.dirname f}/")
  filesCleaned = lo.uniq (files.map (f) ->
    '-l' + ((path.basename f).replace /^lib|\.so$/gi, ""))
  (folders.concat filesCleaned).join ' '

bin = getFilesFromPackageJsonMacro 'bin', (files) -> files.join ' '

version = (basedir, packName, keys, opts, cb) ->
  field = 'version'
  cb S.keyGivenNotSupported field, keys if keysGiven keys
  getPackageContents basedir, packName, field, cb


# wrappers for web commands
search = (basedir, reg, posArgs, opts, cb) ->
  webCommands.search (new RegExp reg, "gi"), opts, cb

info = (basedir, name, posArgs, opts, cb) ->
  webCommands.info name, opts, cb


# project management commands
bootstrap = (basedir, packName, keys, opts, cb) ->
  newProjectName = (path.resolve basedir).replace /.*\//g, ""
  getPackageDirPath basedir, (dir) ->
    if dir
      console.log arguments
      cb S.packageJsonAlreadyExists path.resolve dir
    else
      fs.writeFile S.packageFilename,
        (S.bootstrapPackage newProjectName), (err) ->
          if err then cb err.message
          else cb null, S.successfulBootstrap newProjectName

# TODO: assume latest if version_spec not given
install = (basedir, depDev, [packName, version_spec], opts, cb) ->
  if S.validDepDevs[depDev] then cb S.invalidDepDev depDev
  else getPackageDirPath basedir, (dir) ->
    return cb S.noPackageJsonFound unless dir
    myPackageJson = path.join dir, S.packageFilename
    fs.readFile myPackageJson, (err, contents) ->
      return cb err if err
      parsed = JSON.parse contents
      depField = S.validDepDevs[depDev]
      parsed[depField] = {} unless parsed[depField]
      version = parsed[depField][packName]
      if not compareVersionStrings version, version_spec
        cb S.dependencyError packName, version
      else
        webCommands.install packName, (err, packVer, tarGZStream) ->
          return cb err if err
          outDir = path.join dir, S.modulesFolder, packName
          tarGZStream.pipe(zlib.createGunzip())
            # n.b.: the archive must not have a folder at top level! should
            # extract the root of the repo directly wherever it's extracted to
            .pipe(tar.extract outDir, {strict: no}).on 'finish', ->
              parsed[depField][packName] = packVer
              str = JSON.stringify parsed, null, 2
              fs.writeFile myPackageJson, str, (err) ->
                if err then cb err.message
                else cb null, S.successfulInstall outDir, packName

remove = (basedir, packName, keys, opts, cb) ->
  getPackageDirPath basedir, (dir) ->
    return cb S.noPackageJsonFound unless dir
    ifNotExistThrow dir, packName, (folder) ->
      fs.rmdir folder, (err) -> cb S.packageCouldNotBeRemoved packName

publish = (basedir, packName, keys, opts, cb) ->
  async.waterfall [
    # get package dir
    (cb) -> getPackageDirPath basedir, (dir) ->
      if dir then cb null, dir else cb S.noPackageJsonFound
    # get package-cpm.json contents
    (dir, cb) -> fs.readFile (path.join dir, S.packageFilename), (err, res) ->
      cb err, dir, JSON.parse res
    # make tar.gz of current package's contents
    (dir, pkgJson, cb) ->
      tarGZStream = (tar.pack dir).pipe(zlib.createGzip()).pipe(base64.encode())
      s = new DumpStream
      tarGZStream.pipe(s).on 'finish', -> cb null, pkgJson, s.dump()
    # upload
    webCommands.publish],
    cb

register = (basedir, packName, keys, opts, cb) -> webCommands.register cb

module.exports = {
  compareVersionStrings
  hyphenToCamel
  commands: {
    include
    link
    dynamic
    dynamicLink
    bin
    version
    bootstrap
    search
    info
    install
    remove
    publish
    register
  }
}
