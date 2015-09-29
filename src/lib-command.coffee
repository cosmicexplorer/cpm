fs = require 'fs'
path = require 'path'

colors = require 'colors'

module.exports =
  include: (basedir, packageName, keys, opts) ->
    cmds = (getIncludeCommand basedir, packageName for key in keys).join '\n'
    if opts.noColor then cmds else colorizeCommand cmds
