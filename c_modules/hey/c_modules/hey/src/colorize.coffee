colors = require 'colors'

colorize = (str) ->
  if str instanceof Array then colorize s for s in str
  else
    description = (str.match /:([^:]*)$/)[1]
    version = (str.match /@([^:]*):/)?[1]
    if version # if in search command
      projName = (str.match /^(.*)@/)[1]
      projName.green + '@'.magenta + version.cyan + ':'.red + description.yellow
    else
      field = (str.match /^(.*):/)[1]
      field.green + ':'.red + description.yellow

module.exports = colorize
