cpm
===

A package manager for C in the style of npm.

# Why?

## Give Me Sandboxing or Give Me Death

cpm differentiates itself from distribution package managers (apt-get, pacman, homebrew) by installing packages locally, per project instead of globally. This makes versioning easier and also makes no assumptions about the file system layout, making porting a package to multiple environments simply a matter of changing the code. cpm also encourages static linking for C projects, which removes versioning issues entirely.

## More than a Glorified Copy/Paste

Unlike [clib](https://github.com/clibs/clib), cpm doesn't just transfer source from one place to another. Not all C source is meant to be used standing alone, and since C is so (comparatively) easy to generate, many large projects (see [linux](https://github.com/torvalds/linux), [emacs](https://github.com/emacs-mirror/emacs)) rely heavily on generated C source. The vast majority of projects do not expose a single header or source file which exposes their entire working API, and it would likely be considered poor style if they did. While there are possibly large optimization opportunities available when the source is available, it would be extremely difficult to force all participating projects to conform to exposing all their source in the form of a few downloadable files. While there are projects such as [uv](https://github.com/libuv/libuv) which are [exposed on clib](https://github.com/clibs/uv) as an entire project, they are usually out of date, likely because clib does not specify a "build" command, making large projects difficult to seamlessly integrate as a dependency. cpm attempts to fix this, as explained below.

In addition, clib requires checking dependencies into your repository. While this may ease the burden on contributors who don't have to install clib (which is good, since there's no clib package for most distributions), this introduces a dissonance between what code is your project's and what is external, which is confusing for licensing issues and also makes clones of a project with many dependencies take a ridiculously long time. cpm will instead download an archive directly from a registry, without the overhead of git history. clib was just meant as a replacement for error-prone copy-pasting, and while it does a good job at that, it's not really suited to performant, easy-to-use package management.

clib also requires projects to be based on github, which greatly reduces the body of projects which can be bundled as packages. cpm will provide a public registry, which allows all projects to be served as packages, regardless of where they're hosted.

## Easy Integration With Build Systems and Existing Projects

npm's `package.json` format allows specifying `bin` and `main` targets: these don't specify how the targets should be built, just that they should exist. This means a command line executable can simply parse the project's package.json to get the right library location, as below:

Assume `some-project` is laid out as below:
```
- src
  - some-project.h
  - some-project.c
- deps
- bin
  - libsomeproject.a
  - libsomeproject.so
  - some-project-executable
```

and your project depends upon `some-project`; when in your project's root directory:
```shell
$ cpm require some-project
-I./c_modules/some-project/src/
$ cpm link some-project
./c_modules/some-project/bin/libsomeproject.a
$ cpm dynamic some-project
./c_modules/some-project/bin/libsomeproject.so
```

This also makes using local binaries (which can be specified in `devDependencies`) simple:
```shell
$ cpm bin some-project
./c_modules/some-project/bin/some-project-executable
$ "$(cpm bin some-project)" --version
some-project v0.1
```

Finally, integrating (potentially massive) existing projects to cpm is a jiffy; while cpm *does* require projects to export a static library (if the project exports a library at all), this can be done relatively quickly with the judicious use of `ar` or other archive utility, the same way a shared library is produced. Then, the only required change is adding a `main` entry to `package.json`.

# Questions

## Dynamic Libraries?

cpm encourages static linking, as it allows for simple, repeatable builds. Exporting dynamic libraries will be allowed though, to make it easier for cpm to expose C libraries to non-C languages; most variants of lisp only support dynamic library interop, for example. I think if cpm avoids supporting "global" installations like npm, instead leaving it up to the package maintainer to define a proper "install" command, we can avoid having to write code that knows how to install packages across all different distributions and architectures. I would very much like to avoid that.

## C or C++?

cpm is intended to be used with typical C tools, for C source. However, since C++ uses a lot of the same types of tools, this will likely work for C++ libraries as well.

## GPL?

cpm will be covered by the GPL, version 3 or later. See [the license](GPL.md) for more information. This does not affect the licensing of projects using it to download dependencies or projects which create cpm packages; see the [GPL FAQ](https://www.gnu.org/licenses/gpl-faq.en.html#CanIUseGPLToolsForNF).

# TODO

- [x] write readme
- [ ] decide how hosting is gonna work
- [ ] make basic client
- [ ] add capability for separate registry servers, with authentication
- [ ] bask in fame and glory
