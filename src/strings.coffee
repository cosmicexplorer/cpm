path = require 'path'

packageFilename = 'package-cpm.json'
modulesFolder = 'c_modules'

module.exports =
  shortLongOptionMap:
    h: 'help'
    v: 'version'
    c: 'no-color'
    s: 'server'
    a: 'all-keys'

  packageFilename: packageFilename
  modulesFolder: modulesFolder

  helpMsg: ["Usage: cpm [-h|-v|-c|-s <server>] command [arg..]"
  "Download, install, and manage C/C++ packages on public or private
  registries."
  ""
  "Optional Arguments"
  "  -h, --help           Display this help message."
  "  -v, --version        Display version number."
  "  -c, --no-color       Don't colorize output, if output would have been"
  "                       colorized."
  "  -s, --server=SERVER  Pull from given server instead of default server for"
  "                       operations which access a package registry."
  "  -a BOOL, --all-keys=BOOL"
  "                       Pull all keys from a target which is designated by an"
  "                       associative array."
  ""
  "Commands"
  "Querying Installed Packages:"
  "  include <package> [key...]       Display include directories for package."
  "  link <package> [key...]          Display static object files for package."
  "  dynamic <package> [key...]       Display location of shared object files"
  "                                   for package."
  "  dynamic-link <package> [key...]  Display dynamic object linking for"
  "                                   package."
  "  bin <package> [key]              Display location of executable file for"
  "                                   package."
  "  version <package>                Display version of an installed package."
  ""
  "Searching, Downloading, and Installing Packages:"
  "  search <regex>  Search registry for packages matching regex."
  "  info <package>  Give version and description for specified package."
  ""
  "Creating and Managing a Project"
  "  bootstrap  Create introductory #{packageFilename} with required values."
  "  install [dep|dev <package> [<version_spec>]]"
  "             Install package according to version_spec into c_modules/ and"
  "             dependencies or devDependencies of #{packageFilename}, as"
  "             specified by the first argument."
  "  remove     Remove package from c_modules and #{packageFilename}."
  ""
  "More in-depth documentation of all these options can be found at:"
  "https://github.com/cosmicexplorer/cpm/blob/master/docs/commands.md."]
  .join '\n'

  # use if no package.json found for current project
  noPackageJsonFound: "No #{packageFilename} found in current directory or any
  parent."

  # use if package.json found for current project, but not for a dependency
  packageNotFound: (jsonDir, pack) -> "Package '#{pack}' was not found in
  #{path.join jsonDir, S.modulesFolder, pack}/"

  invalidFieldType: (jsonPath, field) -> "Field '#{field}' of #{jsonPath} is not
  an object, array of strings, or string."

  commandNotFound: (cmd) -> "Command '#{cmd}' not found. Run cpm -h for
  available commands."

  noKeysForTarget: (target, jsonPath) -> "Field '#{target}' of #{jsonPath} is
  an associative array, but no keys were specified."

  keyGivenForNoReason: (target, jsonPath, keys) -> "Field '#{target}' of
  #{jsonPath} is not an associative array, but keys '#{keys.join "', '"}' were
  specified."

  keyGivenNotSupported: (target, keys) -> "Field '#{target}' does not
  support keyed values, but '#{keys.join "', '"}' were provided."

  keyNotFound: (target, jsonPath, key) -> "Key '#{key}' is not in field
  '#{target}' of #{jsonPath}."

  packageJsonAlreadyExists: (folder) -> "#{packageFilename} already exists in
  #{folder}."

  bootstrapPackage: (projName) ->
    ["{"
    "  \"name\": \"#{projName}\","
    "  \"version\": \"0.0.0\""
    "}"].join '\n'

  successfulBootstrap: (folder) -> "Successfully bootstrapped #{folder} in the
  current directory."

  noSuchPackageRegex: (reg) -> "No packages found matching regex '#{reg}.'"
  noSuchPackage: (str) -> "No packages found with name '#{str}.'"
  internalError: (err) -> "Internal error: #{err}."

  packageCouldNotBeRemoved: (packName) -> "Package #{packName} could not be
  removed (access error?)."
