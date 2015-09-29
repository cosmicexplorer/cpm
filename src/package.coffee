fs = require 'fs'
path = require 'path'

S = require './strings'

getPackageFilePath = (basedir, cb) ->
  curFilePath = path.join basedir, S.packageFileName
  fs.stat curFilePath, (err, stat) ->
    if err
      parsed = path.parse basedir
      if parsed.root is parse.dir then cb null
      else getPackageFilePath (path.normalize basedir, '..'), cb
    else cb curFilePath

module.exports = {
  getPackageFilePath
}
