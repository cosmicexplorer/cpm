commands
========

Use `cpm -h` or `cpm --help` for a short list of all commands and options.

All examples showing command usage assume commands are being run from the directory containing the [package-cpm.json file](package-cpm.json-spec.md). All file/folder values respect wildcard expansion, as well as arrays. Strings representing folders can end in slashes, but files cannot.

# Package Naming and Versions

Any instance of `<package>` can be substituted with a package's name, or a name with a version. A package's bare name (`<package_name>`) always refers to the most recent version of the package. `<package_name>@<version>` refers to a specific version of the package (this is why package names cannot contain the `@` character).

# Options

- `-h|--help`

Displays help roughly corresponding to this documentation.

- `-v|--version`

Displays version of cpm.

- `-c <true|false>|--no-color=<true|false>`

Stops colorization of output, if the command would have produced colorized output.

## Non-Global Options

- `-a <true|false>|--all-keys=<true|false>`

Specifies that all keys of the target should (or should not) be acted upon for commands which act upon a package with targets.

package-cpm.json:
```json
"bin": {
  "output_a": "file.exe",
  "output_b": "file2.exe"
}
```

usage:
```
$ cpm bin some-project -a
./c_modules/some-project/file.exe ./c_modules/some-project/file2.exe
```

- `-s <creds>|--server=<creds>`

Specifies server basename to link to for commands which access a registry. See [server documentation](private-server.md) for details.

# Querying Installed Packages

## include
- `include <package> [key...]`

Returns appropriate include directory usage which can be directly used in a gcc command. `key` can be omitted if a project only exports a single header directory. Multiple keys can be specified.

package-cpm.json:
```json
"include": "src"
```
usage:
```shell
$ cpm include some-project
-I./c_modules/some-project/src/
```

Multiple include directories:

package-cpm.json:
```json
"include": {
  "net": ["src", "src/net"],
  "local": "src/loc-*"
}
```
usage:
```shell
$ cpm include some-project net
-I./c_modules/some-project/src/ -I./c_modules/some-project/src/net/
```

## link
- `link <package> [key...]`

Returns locations of static object files for the package. `key` can be omitted if a project only exports a single library archive.

package-cpm.json:
```json
"link": "bin/*.a"
```
usage:
```shell
$ cpm link some-project
./c_modules/some-project/bin/libsomeproject.a
```

Multiple keys can be specified as in the `include` command.

## dynamic
- `dynamic <package> [key...]`

Returns location of dynamic shared object files for the packages. `key` works as above.

package-cpm.json:
```json
"dynamic": "bin/*.so"
```
usage:
```shell
$ cpm dynamic some-project
./c_modules/some-project/bin/libsomeproject.so
```

## dynamic-link
- `dynamic-link <package> [key...]`

Returns location of folder containing dynamic library to link against. *Unlike other commands*, dynamic-link requires both a folder and a specific file, which is why it uses the same `dynamic` field of `package-cpm.json` as the `dynamic` command. However, the specification in `package-cpm.json` is the same as other commands; cpm will figure out and generate the correct folders to specify with `-L` and correct files to give as `-l` arguments to the compiler.

package-cpm.json:
```json
"dynamic": "bin/libsomeproject.so"
```
usage:
```shell
$ cpm dynamic-link some-project
-L./c_modules/some-project/bin/ -lsomeproject
```

## bin
- `bin <package> [key]`

Returns locations of executable binaries for the package.

package-cpm.json:
```json
"bin": "bin/some-project-executable"
```
usage:
```shell
$ cpm bin some-project
./c_modules/some-project/some-project-executable
```

## version
- `version <package>`

Returns the version of an installed package.

package-cpm.json:
```json
"version": "1.2.3"
```
usage:
```shell
$ cpm version some-project
1.2.3
```

# Searching, Downloading, and Installing Packages

All commands below will search either the public registry, or a specified registry if the `[-s <server>]` option is given.


## search
- `search <regex>`

Searches the registry for package names containing the specified regex, to a maximum of 50 items. Returns a list of package names, and descriptions, if provided. Colorizes output unless `--no-color` is given. If description is not provided, no information is given past the colon.

usage:
```shell
$ cpm search "web\\-.*"
web-crawler@1.2.3: A web crawler for C.
web-visualizer@0.1.2: A spiderweb generation library using mandelbrot fractals.
web-test@0.0.0
...
```

## info
- `info <package>`

Gives version and description for specified package. If no description is provided, no description line is given.

usage:
```shell
$ cpm info some-project
name: some-project
version: 2.3.4
description: A test project, for testing things.
```

# Creating and Managing a Project

## bootstrap
- `bootstrap`

Creates `package-cpm.json` with default `version` and `name` fields. `version` is set to `0.0.0`, while `name` is set to the name of the folder of the current directory. Fails if run in the root directory.

Run in `/home/me/my-project`:

usage:
```shell
$ cpm bootstrap
```

The file created (`package-cpm.json`) should read:
```json
{
  "name": "my-project",
  "version": "0.0.0"
}
```

## install
- `install [dep|dev <package> [<version_spec>]]`

If no arguments provided, installs all packages specified in `dependencies` and `devDependencies` fields in `package-cpm.json`. Fails if no `package-cpm.json` file exists or the package with a version matching the given `version_spec` already exists. For more info on `version_spec`, check out the [package-cpm.json spec](package-cpm.json-spec.md).

Installs a package to the `c_modules` subdirectory of the folder containing the `package-cpm.json` file, creating `c_modules` if it doesn't exist. If `dep` is specified as the first argument, adds package with given version spec to `dependencies` field of `package-cpm.json` with the given `version_spec`; if `dev` is specified, then the package is added to the `devDependencies` field of `package-cpm.json` with the given `version_spec`. If a `version_spec` field is not provided, downloads the latest version of the package and sets `version_spec` to the package's current version.

## remove
- `remove <package>`

Fails if no `package-cpm.json` file exists or the package named doesn't exist. Removes the package from the `c_modules/` folder and `package-cpm.json`.

## publish
- `publish`

Publishes package to registry using the `package-cpm.json` of the current project. Prompts for authentication, and fails if the package version hasn't been bumped since last time.

# Creating a User

## register
- `register`

Prompts for username and password. Errors out if username already taken. `publish` can be called called after using this.
