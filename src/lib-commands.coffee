lib = require './lib'

version = (basedir, packName, keys, opts, cb) ->
  lib.version basedir, packName, cb

bootstrap = (basedir, packName, keys, opts, cb) -> lib.bootstrap basedir, cb

search = (basedir, reg, keys, opts, cb) -> lib.commands.search reg, opts, cb

info = (basedir, name, keys, opts, cb) -> lib.commands.info name, opts, cb

install = (basedir, packName, [depDev, version_spec], opts, cb) ->
  lib.commands.install basedir, packName, depDev, version_spec, cb

remove = (basedir, packName, keys, opts, cb) ->
  lib.commands.remove basedir, packName, keys, cb

publish = (basedir, packName, keys, opts, cb) ->
  lib.commands.publish basedir, cb

register = (basedir, packName, keys, opts, cb) -> lib.commands.register cb

module.exports = {
  hyphenToCamel: lib.hyphenToCamel
  commands: {
    include: lib.commands.include
    link: lib.commands.link
    dynamic: lib.commands.dynamic
    dynamicLink: lib.commands.dynamicLink
    bin: lib.commands.bin
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
