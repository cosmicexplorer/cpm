fs = require 'fs'
path = require 'path'
zlib = require 'zlib'

async = require 'async'
lo = require 'lodash'
glob = require 'glob'
tar = require 'tar-fs'
base64 = require 'base64-stream'
DumpStream = require 'dump-stream'
rimraf = require 'rimraf'

S = require "./strings"
webCommands = require './web-commands'

VERSION_STRING_LENGTH = 3


# auxiliary methods
getJsonPath = (basedir, cb) ->
  curFilePath = path.join basedir, S.packageFilename
  fs.stat curFilePath, (err, stat) ->
    if err
      parsed = path.parse path.resolve basedir
      if parsed.root is parsed.dir then cb null
      else getJsonPath (path.join basedir, '..'), cb
    else cb path.relative process.cwd(), curFilePath

getJsonDirPath = (basedir, cb) -> getJsonPath basedir, (file) ->
  cb (if not file then null else path.dirname file)

getCurrentPackageText = (basedir, cb) ->
  getJsonPath basedir, (packPath) ->
    return cb S.noPackageJsonFound unless packPath
    fs.readFile packPath, (err, res) -> cb err, res.toString()

getJsonTextOfPackage = (basedir, packName, cb) ->
  getJsonDirPath basedir, (dir) ->
    packPath = path.join dir, S.modulesFolder, packName, S.packageFilename
    if not path then cb S.noPackageJsonFound()
    else fs.readFile packPath, (err, content) ->
      if err then cb S.packageNotFound dir, packName
      else cb null, content.toString(), packPath

ident = (x) -> x
getPackJsonContents = (basedir, packName, field, cb, parse = ident) ->
  getJsonTextOfPackage basedir, packName, (err, contents, packPath) ->
    if err then cb err else cb null, (try
        parse (JSON.parse contents)[field], packPath
      catch err then err.message)

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

keysGiven = (keysObj) -> keysObj and keysObj.length > 0

getSelectors = (fieldObj, opts, keys, field, packFile) ->
  if isObject fieldObj
    if opts?.allTargets then (v for k, v of fieldObj)
    else if not keysGiven keys then throw S.noKeysForTarget field, packFile
    else for key in keys
      if key of fieldObj then fieldObj[key]
      else throw S.keyNotFound field, packFile, key
  else if isStringOrArray fieldObj
    if keysGiven keys then throw S.keyGivenForNoReason field, packFile, keys
    else [fieldObj]
  else throw S.invalidFieldType packFile, field

flattenSelections = (opts, cb) -> (err, files) ->
  cmds = (lo.flatten files).map (f) -> path.relative process.cwd(), f
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
  getPackJsonContents basedir, packageName, field, (err, contents, packPath) ->
      return cb err if err
      try
        selectors = getSelectors contents, opts, keys, field, packPath
        folder = path.dirname packPath
        async.map selectors, (getAllFilesFromSelection folder, opts),
          (flattenSelections opts, cb)
      catch err then cb err

usesFoldersMacro = (fun) -> (args..., opts = {folders: yes}, cb) ->
  if typeof opts is 'function'
    cb = opts
    opts = {folders:yes}
  else opts.folders = yes
  fun args..., opts, cb

getFilesFromPackageJsonMacro = (title, fun) -> (args..., opts, cb) ->
  getFilesFromField title, args..., opts, (err, files) ->
    if err then cb err else cb null, fun files

getPackageDir = (packageJsonDir, pack, cb) ->
  finalPathFolder = path.join packageJsonDir, S.modulesFolder, pack
  fs.stat finalPathFolder, (err) ->
    if err then cb S.packageNotFound packageJsonDir, pack
    else cb null, finalPathFolder

numRegexMatch = (num) -> num.match /^[0-9]+/g
doComparison = (num, specNum, comparison, version_spec) ->
  switch comparison
    when '<=' then specNum >= num
    when '>=' then specNum <= num
    when '<' then specNum > num
    when '>' then specNum < num
    else throw new Error "invalid version string #{version_spec}"

ensureModulesFolderBuilt = (basedir, cb) ->
  modulesFolder = path.join basedir, S.modulesFolder
  fs.stat modulesFolder, (err) ->
    if err then fs.mkdir modulesFolder, (err) -> cb err, modulesFolder
    else cb null, modulesFolder

extractTarToDir = (dir, packName, depField, parsed, packageJsonPath, packVer,
  tarGZStream, cb) ->
  async.waterfall [
    (cb) -> ensureModulesFolderBuilt dir, cb
    (modulesFolder, cb) ->
      outDir = path.join modulesFolder, packName
      fs.stat outDir, (err) ->
        return cb null, outDir, modulesFolder if err
        rimraf outDir, (err) -> cb err, outDir, modulesFolder
    (outDir, modulesFolder, cb) ->
      tarGZStream.pipe zlib.createGunzip()
        .pipe(tar.extract outDir, {strict: no})
        .on('finish', ->
          parsed[depField][packName] = packVer
          str = JSON.stringify parsed, null, 2
          fs.writeFile packageJsonPath, str, (err) -> cb err, outDir)
        .on 'error', cb],
    cb


### exposed API ###
# utility methods
hyphenToCamel = (str) -> str.replace /\-(.)/g, (total, g1) -> g1.toUpperCase()

compareVersionStrings = (version, version_spec) ->
  return yes unless version_spec
  return no unless version
  nums = version.split '.'
  specNums = version_spec.split '.'
  comparison = null
  try for i in [0..(VERSION_STRING_LENGTH - 1)]
    if comparison
      return no unless numRegexMatch specNums[i]
    else if not numRegexMatch specNums[i]
      nonNumeric = specNums[i].replace /[0-9]/g, ""
      numeric = specNums[i].replace /[^0-9]/g, ""
      if not doComparison nums[i], numeric, nonNumeric, version_spec
        return no
      comparison = nonNumeric
    else return no if nums[i] isnt specNums[i]
  catch then return no
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
  getPackJsonContents basedir, packName, 'version', cb


# wrappers for web commands
search = (basedir, reg, keys, opts, cb) ->
  webCommands.search (new RegExp reg, "gi"), opts, cb

info = (basedir, name, keys, opts, cb) ->
  webCommands.info name, opts, cb


# project management commands
bootstrap = (basedir, packName, keys, opts, cb) ->
  newProjectName = (path.resolve basedir).replace /.*\//g, ""
  getJsonDirPath basedir, (dir) ->
    if dir and (path.resolve dir) is (path.resolve basedir)
      cb S.packageJsonAlreadyExists path.resolve dir
    else
      fs.writeFile S.packageFilename,
        (S.bootstrapPackage newProjectName), (err) ->
          if err then cb err.message
          else cb null, S.successfulBootstrap newProjectName

# TODO: assume latest if version_spec not given
# TODO: install all from package.json if no depDev, packName given
install = (basedir, depDev, [packName, version_spec], opts, cb) ->
  dir = null
  packageJsonPath = null
  parsed = null
  depField = null
  if not S.validDepDevs[depDev] then cb S.invalidDepDev depDev
  else async.waterfall [
    # get json dir
    (cb) -> getJsonDirPath basedir, (dirFound) ->
      if not dirFound then cb S.noPackageJsonFound
      else
        dir = dirFound
        packageJsonPath = path.join dir, S.packageFilename
        cb null
    # read package file
    (cb) ->
      packageConfigFilePath = path.join dir, S.modulesFolder, packName,
        S.packageFilename
      fs.readFile packageConfigFilePath, (err, contents) ->
        # pretend file is 0.0.0 if doesn't exist
        parsed = if err then null else JSON.parse contents
        cb null
    # get old version
    (cb) ->
      depField = S.validDepDevs[depDev]
      if not parsed?
        parsed = {}
        return cb null
      return cb S.invalidDepDev depDev unless depField
      parsed[depField] = {} unless parsed[depField]
      prevVersion = parsed[depField][packName]
      if compareVersionStrings prevVersion, version_spec
        cb S.dependencyError packName, prevVersion, version_spec
      else cb null
    (cb) -> webCommands.install packName, cb
    (args...) -> extractTarToDir dir, packName, depField, parsed,
      packageJsonPath, args...],
    (err, outDir) -> cb err, S.successfulInstall outDir, packName

remove = (basedir, packName, keys, opts, cb) ->
  async.waterfall [
    (cb) -> getJsonDirPath basedir, (dir) ->
      if dir then cb null, dir else cb S.noPackageJsonFound
    (dir, cb) -> getPackageDir dir, packName, cb
    (folder, cb) -> fs.rmdir folder, (err) -> if err
        cb S.packageCouldNotBeRemoved packName
      else cb null
    ], (err) -> cb err, S.removeSuccessful packName

publish = (basedir, packName, keys, opts, cb) ->
  async.waterfall [
    # get package dir
    (cb) -> getJsonDirPath basedir, (dir) ->
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