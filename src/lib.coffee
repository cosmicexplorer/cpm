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
ignore = require 'dot-star-ignore'

S = require "./strings"
webCommands = require './web-commands'
utils = require './utils'

# files that we shall use to exclude others
excludeFiles = ['.gitignore', '.cpmignore']
# regexen that we shall use (on the file's ABSOLUTE path) to exclude files
excludeRegexen = [
  /(^|\/)\.git(\/|$)/g               # exclude the git folder
  ]
allowedPackageNamesRegex = /^[a-zA-Z_\-0-9]+$/g


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

getPathOfPackageConfigFile = (basedir, packName, cb) ->
  getJsonDirPath basedir, (dir) ->
    return cb S.noPackageJsonFound unless dir
    packPath = path.join dir, S.modulesFolder, packName, S.packageFilename
    cb null, packPath

getJsonTextOfPackage = (basedir, packName, cb) ->
  getPathOfPackageConfigFile basedir, packName, (err, packPath) ->
    return cb err if err
    fs.readFile packPath, (err, content) ->
      if err then cb S.packageNotFound basedir, packName
      else cb null, content.toString(), packPath

getPackJsonContents = (basedir, packName, field, cb) ->
  getJsonTextOfPackage basedir, packName, (err, contents, packPath) ->
    if err then cb err
    else
      try cb null, (JSON.parse contents)[field], packPath
      catch err then cb err.message

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
  cmds = (lo.flatten files).map (f) ->
    res = path.relative process.cwd(), f
    if res is '' then '.' else res
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

ensureModulesFolderBuilt = (basedir, cb) ->
  modulesFolder = path.join basedir, S.modulesFolder
  fs.stat modulesFolder, (err) ->
    if err then fs.mkdir modulesFolder, (err) -> cb err, modulesFolder
    else cb null, modulesFolder

extractTarToDir = (dir, packName, depField, packVer, tarGZStream, cb) ->
  outDir = null
  async.waterfall [
    (cb) -> ensureModulesFolderBuilt dir, cb
    (modulesFolder, cb) ->
      outDir = path.join modulesFolder, packName
      fs.stat outDir, (err) ->
        return cb null, modulesFolder if err
        rimraf outDir, (err) -> cb err, modulesFolder
    (modulesFolder, cb) ->
      tarGZStream.pipe zlib.createGunzip()
        .pipe(tar.extract outDir, {strict: no})
        .on('finish', -> cb null)
        .on 'error', cb
    (cb) ->
      jsonPath = path.join dir, S.packageFilename
      fs.readFile jsonPath, (err, contents) -> cb err, jsonPath, contents
    (jsonPath, contents) ->
      parsed = JSON.parse contents
      if not parsed[depField]?
        parsed[depField] = {}
      parsed[depField][packName] = packVer
      str = JSON.stringify parsed, null, 2
      fs.writeFile jsonPath, str, (err) -> cb err, outDir, packVer],
    cb

specificallyExcluded = (dir, file) ->
  abs = path.resolve dir, file
  (file.match reg for reg in excludeRegexen).reduce ((a, b) -> a or b), null
getAllFilesInRepo = (dir, cb) ->
  newIgnoreFile = new ignore.IgnoreFile '.cpmignore', 1
  ignoreFiles = ignore.defaultIgnoreFiles.concat newIgnoreFile
  ignore.getTracked dir, {ignoreFileObjs: ignoreFiles}, (err, res) ->
    if err then cb err
    else cb null, res.files.concat res.dirs.map (d) -> d + '/'

libSoRegex = /^lib|\.so$/gi
correctVersionRegex = /([0-9]+\.){2}[0-9]+/g


### exposed API ###
# utility methods
hyphenToCamel = (str) -> str.replace /\-(.)/g, (total, g1) -> g1.toUpperCase()


# build system commands
include = usesFoldersMacro getFilesFromPackageJsonMacro 'include', (files) ->
  (files.map (f) -> "-I#{f}/").join ' '

link = getFilesFromPackageJsonMacro 'link', (files) -> files.join ' '

dynamic = getFilesFromPackageJsonMacro 'dynamic', (files) -> files.join ' '

dynamicLink = getFilesFromPackageJsonMacro 'dynamic', (files) ->
  folders = lo.uniq (files.map (f) ->
    "-L#{path.dirname f}/")
  filesCleaned = lo.uniq (files.map (f) ->
    '-l' + ((path.basename f).replace libSoRegex, ""))
  (folders.concat filesCleaned).join ' '

bin = getFilesFromPackageJsonMacro 'bin', (files) -> files.join ' '

version = (basedir, packName, cb) ->
  getPackJsonContents basedir, packName, 'version', cb


# wrappers for web commands
search = (reg, opts, cb) -> webCommands.search (new RegExp reg, "gi"), opts, cb

info = (name, opts, cb) -> webCommands.info name, opts, cb


# project management commands
bootstrap = (basedir, cb) ->
  newProjectName = (path.resolve basedir).replace /.*\//g, ""
  getJsonDirPath basedir, (dir) ->
    if dir and (path.resolve dir) is (path.resolve basedir)
      cb S.packageJsonAlreadyExists path.resolve dir
    else
      fs.writeFile S.packageFilename,
        (S.bootstrapPackage newProjectName), (err) ->
          if err then cb err.message
          else cb null, S.successfulBootstrap newProjectName

# TODO: install all from package.json if no depDev, packName given
# TODO: add prepublish, make-on-install scripts
install = (basedir, packName, depDev, version_spec, cb) ->
  dir = null
  # return installFromPackageJson basedir, version_spec, cb if not packName
  depField = S.validDepDevs[depDev]
  return cb S.invalidDepDev depDev unless depField
  if not S.validDepDevs[depDev] then cb S.invalidDepDev depDev
  else async.waterfall [
    # get json dir
    (cb) -> getJsonDirPath basedir, (dirFound) ->
      if not dirFound then cb S.noPackageJsonFound
      else
        dir = dirFound
        cb null
    # read package file
    (cb) ->
      pkgConfigPath = path.join dir, S.packageFilename
      fs.readFile pkgConfigPath, (err, contents) ->
        if err then cb err else cb null, pkgConfigPath, JSON.parse contents
    # get old version
    (pkgConfigPath, parsed, cb) ->
      prevVersion = parsed[depField]?[packName]
      if prevVersion and not prevVersion.match correctVersionRegex
        cb S.invalidVersion pkgConfigPath, prevVersion
      else if version_spec and
              utils.compareVersionStrings prevVersion, version_spec
        cb S.dependencyError packName, prevVersion, version_spec
      else cb null
    (cb) -> webCommands.install packName, version_spec, cb
    (args...) -> extractTarToDir dir, packName, depField, args...],
    (err, outDir, ver) -> cb err, S.successfulInstall outDir, packName, ver

remove = (basedir, packName, keys, cb) ->
  return cb S.keyMakesNoSense 'remove' if keys?.length
  async.waterfall [
    # get project root
    (cb) -> getJsonDirPath basedir, (dir) ->
      if dir then cb null, dir else cb S.noPackageJsonFound
    # get location of package's folder
    (dir, cb) -> getPackageDir dir, packName, utils.curryAsync dir, cb
    # remove package's folder
    (dir, folder, cb) ->
      rimraf folder, (err) -> if err
        cb S.packageCouldNotBeRemoved packName
      else cb null, dir
    # get project json
    (dir, cb) ->
      packJsonPath = path.join dir, S.packageFilename
      fs.readFile packJsonPath, utils.curryAsync packJsonPath, cb
    # read content and update (devD|d)ependencies
    (packJsonPath, contents, cb) ->
      parsed = JSON.parse contents
      for k, v of S.validDepDevs
        if parsed[v]?
          delete parsed[v][packName]
          delete parsed[v] if Object.keys(parsed[v]).length is 0
      fs.writeFile packJsonPath, (JSON.stringify parsed, null, 2), cb],
    (err) -> cb err, S.removeSuccessful packName

publish = (basedir, cb) ->
  dir = null
  pkgJson = null
  async.waterfall [
    # get package dir
    (cb) -> getJsonDirPath basedir, (directory) ->
      if directory
        dir = directory
        cb null
      else cb S.noPackageJsonFound
    # get package-cpm.json contents
    (cb) -> fs.readFile (path.join dir, S.packageFilename), cb
    (res, cb) ->
      pkgJson = JSON.parse res
      if pkgJson?.name.match allowedPackageNamesRegex then cb null
      else
        p = path.join dir, S.packageFilename
        if not pkgJson.name then cb S.needsRequiredFields p
        else cb S.invalidPackageName pkgJson.name, p
    # make tar.gz of current package's contents
    (cb) -> getAllFilesInRepo dir, cb
    (files, cb) ->
      files = files.map (f) -> path.relative dir, f
      tarGZStream = (tar.pack dir, {entries: files}).on('error', cb)
        .pipe(zlib.createGzip())
        .pipe(base64.encode())
      s = new DumpStream
      tarGZStream.pipe(s).on 'finish', -> cb null, pkgJson, s.dump()
    # upload
    webCommands.publish],
    cb

register = (cb) -> webCommands.register cb

module.exports = {
  hyphenToCamel
  compareVersionStrings: utils.compareVersionStrings
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
