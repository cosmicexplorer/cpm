fs = require 'fs'
path = require 'path'

colorize = require './colorize'

module.exports =
  include: (basedir, packageName, keys, opts) ->
    cmds = (getIncludeCommand basedir, packageName for key in keys)
    if opts.noColor then cmds else cmds.map colorize
