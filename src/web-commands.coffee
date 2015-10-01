fs = require 'fs'
http = require 'http'

async = require 'async'
prompt = require 'prompt'
{Parse} = require 'parse/node'
{app_id, js_key} = JSON.parse fs.readFileSync "#{__dirname}/../parse-info.json"

S = require './strings'
colorize = require './colorize'
libCmd = require './lib-commands'

SearchLimit = 50

Parse.initialize app_id, js_key

parseGetVals = (parseObj, keys) ->
  res = {}
  for k in keys
    res[k] = parseObj.get k
  res

parseSetVals = (parseObj, obj) ->
  for k, v of obj
    parseObj.set k, v
  parseObj

parseMakePointer = (Class, id) ->
  __type: 'Pointer'
  className: Class
  objectId: id

parseHandleError = (cb) -> (err) -> cb err.message

optionalOptionsMacro = (fun) -> (arg, opts, cb) ->
  if typeof opts is 'function' then fun arg, null, opts
  else fun arg, opts, cb

getPackDesc = (pack) ->
  name = pack.get 'name'
  recent = pack.get 'recent'
  description = recent.get 'description'
  version = recent.get 'version'
  {name, description, version}

search = optionalOptionsMacro (reg, {noColor = null} = {}, cb) ->
  query = new Parse.Query 'Package'
  query.limit SearchLimit
  query.descending 'name'
  query.include 'recent'
  query.matches 'name', reg
  query.find
    success: (packs) ->
      if packs.length > 0
        res = packs.map(getPackDesc).map ({name, version, description: desc}) ->
          "#{name}@#{version}" + (if desc then ": #{desc}" else '')
        res = colorize res unless noColor
        cb null, res.join '\n'
      else cb S.noSuchPackageRegex reg
    error: parseHandleError cb

formatInfo = (pack, {noColor = null} = {}) ->
  {name, version, description} = getPackDesc pack
  (colorize ["name: #{name}"
    "version: #{version}"
    "description: #{description}"]).join '\n'

getPackageByName = (name, cb) ->
  query = new Parse.Query 'Package'
  query.limit 1
  query.include 'recent'
  query.equalTo 'name', name
  query.find
    success: (packs) ->
      switch packs.length
        when 0 then cb S.noSuchPackage name
        when 1 then cb null, packs[0]
    error: parseHandleError cb

info = optionalOptionsMacro (name, opts, cb) ->
  getPackageByName name, (err, pack) ->
    return cb err if err
    cb null, formatInfo pack, opts

getFileFromPackage = (pack, cb) ->
  publish = pack.get 'recent'
  http.get(publish.get('archive').url(), (resp) ->
    cb null, publish.get('version'), resp).on 'error', cb

# TODO: make this respect versions
install = (name, cb) ->
  getPackageByName name, (err, pack) ->
    return cb err if err
    getFileFromPackage pack, cb

login = (cb) ->
  prompt.start()
  prompt.get ['username', 'password'], (err, res) ->
    Parse.User.logIn res.username, res.password,
      success: (user) -> cb null
      error: parseHandleError cb

makePackageCheckVersion = (pack, name, version, cb) ->
  if not pack.isNewPackage
    recent = pack.get 'recent'
    # if version is not greater than the most recent version
    recentVersion = recent.get 'version'
    if not libCmd.compareVersionStrings version, ('>=' + recentVersion)
      cb S.mustBumpVersion name, version, recentVersion
    else cb null, pack
  else
    pack = new Package
    parseSetVals pack, {
      name
      owner: Parse.User.current().getObjectId()}
    pack.save null,
      success: (savedPack) -> cb null, savedPack
      error: parseHandleError cb

postNewPublish = (pack, name, version, description, tarGZBuffer, cb) ->
  pub = new Publish
  archive = new Parse.File "#{name}.tar.gz", {base64: tarGZBuffer}
  parseSetVals pub, {
    version, description, archive
    package: parseMakePointer 'Package', pack.getObjectId()}
  pub.save null,
    success: (savedPub) ->
      parseSetVals pack,
        recent: parseMakePointer 'Publish', savedPub.getObjectId()
      pack.save null,
        success: (savedPack) -> cb null
        err: parseHandleError cb
    error: parseHandleError cb

Package = Parse.Object.extend 'Package'
Publish = Parse.Object.extend 'Publish'
publish = ({name, version, description}, tarGZBuffer, cb) ->
  async.waterfall [login
    # get prev package if exists
    (cb) -> getPackageByName name, (err, pack) ->
      cb null, (if err then {isNewPackage: yes} else pack)
    (pack, cb) -> makePackageCheckVersion pack, name, version, cb
    (pack, cb) ->
      postNewPublish pack, name, version, description, tarGZBuffer, cb],
    (err) ->
      if err then return cb err
      else cb null, S.packageSaved name, version

register = (cb) ->
  user = new Parse.User
  prompt.get ['username', 'password'], (err, res) ->
    parseSetVals user,
      username: res.username
      password: res.password
    user.signUp null,
      success: cb null, S.registerSuccessful res.username
      error: parseHandleError cb

module.exports = {
  search
  info
  install
  publish
  register
}
