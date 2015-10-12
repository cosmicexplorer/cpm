fs = require 'fs'
http = require 'http'

async = require 'async'
{Parse} = require 'parse/node'
{app_id, js_key} = JSON.parse fs.readFileSync "#{__dirname}/../parse-info.json"

prompt = require 'prompt'
prompt.message = ''
prompt.delimiter = ''

S = require './strings'
colorize = require './colorize'
utils = require './utils'

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
  res = ["name: #{name}"
    "version: #{version}"
    "description: #{description}"]
  (if noColor then res else colorize res).join '\n'

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

NUM_TO_TAKE_VERSIONS = 500
getSpecVersionOfPackage = (pack, version_spec, cb, skip = 0) ->
  query = new Parse.Query 'Publish'
  query.descending 'version'
  query.equalTo 'package', parseMakePointer 'Package', pack.id
  query.limit NUM_TO_TAKE_VERSIONS
  query.skip skip if skip
  query.find
    success: (pubs) ->
      switch pubs.length
        when 0 then cb S.noVersionMatchingSpec (pack.get 'name'), version_spec
        else
          res = pubs.filter (pub) ->
            utils.compareVersionStrings (pub.get 'version'), version_spec
          switch res.length
            when 0 then getSpecVersionOfPackage pack, version_spec, cb,
              skip + NUM_TO_TAKE_VERSIONS
            else cb null, res[0]
    error: parseHandleError cb

getFileFromPackage = (pack, cb) ->
  publish = pack.get 'recent'
  http.get(publish.get('archive').url(), (resp) ->
    cb null, publish.get('version'), resp).on 'error', cb

install = (name, version_spec, cb) ->
  getPackageByName name, (err, pack) ->
    return cb err if err
    getSpecVersionOfPackage pack, version_spec, (err, pub) ->
      return cb err if err
      http.get((pub.get 'archive').url(), (resp) ->
        cb null, (pub.get 'version'), resp).on 'error', cb

promptSchemaBase = (verifyPass = no) ->
  res = [{name: 'username'}
    {name: 'password', hidden: yes}]
  if not verifyPass then res
  else
    res.push
      name: 'password (verify)'
      hidden: yes
    res

promptSchema = ({verifyPass} = {}) ->
  for el in promptSchemaBase verifyPass
    el.required = yes
    el.message = el.name + ":"
    el

login = (cb) ->
  prompt.start()
  prompt.get promptSchema(), (err, res) ->
    if err then cb '\n' + S.cancelledInput
    else Parse.User.logIn res.username, res.password,
      success: (user) -> cb null, user
      error: parseHandleError cb

makePackageCheckVersion = (user, pack, name, version, cb) ->
  if not pack.isNewPackage
    recent = pack.get 'recent'
    # if version is not greater than the most recent version
    recentVersion = recent.get 'version'
    if not utils.compareVersionStrings version, ('>' + recentVersion)
      cb S.mustBumpVersion name, recentVersion, version
    else cb null, pack
  else
    pack = new Package
    parseSetVals pack, {name, Owner: parseMakePointer 'User', user.id}
    pack.save null,
      success: (savedPack) -> cb null, savedPack
      error: parseHandleError cb

postNewPublish = (pack, name, version, description, tarGZBuffer, cb) ->
  pub = new Publish
  archive = new Parse.File "#{name}.tar.gz", {base64: tarGZBuffer}
  parseSetVals pub, {
    version, description, archive
    package: parseMakePointer 'Package', pack.id}
  pub.save null,
    success: (savedPub) ->
      parseSetVals pack,
        recent: parseMakePointer 'Publish', savedPub.id
      pack.save null,
        success: (savedPack) -> cb null
        error: parseHandleError cb
    error: parseHandleError cb

Package = Parse.Object.extend 'Package'
Publish = Parse.Object.extend 'Publish'
publish = ({name, version, description}, tarGZBuffer, cb) ->
  user = null
  async.waterfall [login
    # get prev package if exists
    (userLoggedIn, cb) ->
      user = userLoggedIn
      getPackageByName name, (err, pack) ->
        cb null, (if err then {isNewPackage: yes} else pack)
    (pack, cb) -> makePackageCheckVersion user, pack, name, version, cb
    (pack, cb) ->
      postNewPublish pack, name, version, description, tarGZBuffer, cb],
    (err) ->
      if err then cb err
      else cb null, S.packageSaved name, version

register = (cb) ->
  user = new Parse.User
  prompt.start()
  prompt.get (promptSchema {verifyPass: yes}), (err, res) ->
    return cb err.message if err
    if res.password isnt res['password (verify)']
      cb S.passwordVerificationFailure
    else
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
