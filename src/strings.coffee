packageFilename = 'package-cpm.json'

module.exports =
  shortLongOptionMap:
    h: 'help'
    v: 'version'
    c: 'no-color'
    s: 'server'

  packageFilename: packageFilename

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
  "More in-depth documentation of all these options can be found at"
  "https://github.com/cosmicexplorer/cpm/blob/master/docs/commands.md."]
  .join '\n'

  noPackageFound: "No #{packageFilename} found in current directory or any
  parent."

  commandNotFound: (cmd) -> ["Command #{cmd} not found. Run cpm -h for"
  "available commands."].join '\n'
