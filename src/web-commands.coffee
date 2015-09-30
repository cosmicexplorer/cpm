fs = require 'fs'
http = require 'http'

{Parse} = require 'parse/node'
{app_id, js_key} = JSON.parse fs.readFileSync "#{__dirname}/../parse-info.json"

S = require './strings'
colorize = require './colorize'

SearchLimit = 50

Parse.initialize app_id, js_key

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
    error: (err) -> cb err.message

formatInfo = (pack, {noColor = null} = {}) ->
  {name, version, description} = getPackDesc pack
  (colorize ["name: #{name}"
    "version: #{version}"
    "description: #{description}"]).join '\n'

info = optionalOptionsMacro (name, opts, cb) ->
  query = new Parse.Query 'Package'
  query.limit 1
  query.include 'recent'
  query.equalTo 'name', name
  query.find
    success: (packs) ->
      switch packs.length
        when 0 then cb S.noSuchPackage name
        when 1 then cb null, formatInfo packs[0], opts
    error: (err) ->
      cb err.message

getFileFromPackage = (pack, cb) ->
  publish = pack.get 'recent'
  http.get(publish.get('archive').url(), (resp) ->
    cb null, publish.get('version'), resp).on 'error', cb

install = (packname, cb) ->
  query = new Parse.Query 'Package'
  query.limit 1
  query.include 'recent'
  query.equalTo 'name', packname
  query.find
    success: (packs) ->
      switch packs.length
        when 0 then cb S.noSuchPackage packname
        when 1 then getFileFromPackage packs[0], cb

module.exports = {
  search
  info
  install
}
