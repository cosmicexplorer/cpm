package-cpm.json spec
=====================

# version_spec

All `version_spec` identifiers must be strings with three positive integers delimited by periods as detailed in [SemVer](https://semver.org). Unlike SemVer, cpm does *not* allow any information after the final version number. Before any number may be specified `<=`, `<`, `>`, or `>=`, indicating that all versions after the specified number must be less than or equal to, or greater than or equal to, or so on, than the given number. *Only one* such `<=|<|>|>=` relation may be given in a `version_spec`. Examples of `version_spec` are given below.

- `1.2.3`: matches *only* version `1.2.3`
- `>=1.2.3`: matches all of `1.2.3, 1.2.4, 1.3.1, 1.3.5, 2.4.5`, etc
- `1.>=2.3`: matches `1.2.3, 1.2.4, 1.3.1, 1.3.5`, etc
- `1.2.>=3`: matches `1.2.3, 1.2.4` only

The `<`, `>`, and `>=` operators do as you would expect.

# Allowed Fields

## Required Fields

These fields must be strings.

- `name`
Name of the package. Must be unique for the registry you publish the package to. Package names cannot contain the `@` character, nor can they start with the `-` character.
- `version`
Version of the package. Strictly increasing. Please follow [semantic versioning](https://semver.org) as much as possible. As mentioned above, however, cpm does *not* allow any information after the final version number.

## Additional Fields

### Packaging Fields

These fields correspond with the commands of the same name in cpm's [shell commands](commands.md). These fields may be strings or arrays of strings, in which case the shell command does not require a key to access them. They may also be one-level-deep objects with values of type string, or array of strings, in which case a key is required as specified in the [shell command documentation](commands.md#querying-installed-packages).

- `include`
- `link`
- `dynamic`
- `bin`

### Information Fields

- `description`
Provides a description to be used in `search` and `info` commands, as specified in the [shell command documentation](commands.md#searching-downloading-and-installing-packages).
