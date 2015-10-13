questions
=========

# Hosting? Also, Curation?

A public registry containing archives of all projects on the registry naturally requires some reliable and scalable storage space. I haven't figured out hosting, but I'm probably gonna stick it on a digital ocean droplet or something. EDIT: I'm using Parse because it's (kinda) free. Depending upon the pricing scheme and activity, this may require a curation of libraries, to reduce the amount of space used and to ensure cpm isn't just used as a file storage service.

# Dynamic Libraries?

cpm encourages static linking, as it allows for simple, repeatable builds. Exporting dynamic libraries will be allowed though, to make it easier for cpm to expose C libraries to non-C languages; most variants of lisp only support dynamic library interop, for example. I think if cpm avoids supporting "global" installations like npm, instead leaving it up to the package maintainer to define a proper "install" command, we can avoid having to write code that knows how to install packages across all different distributions and architectures. I would very much like to avoid that.

# C or C++?

cpm is intended to be used with typical C tools, for C source. However, since C++ uses a lot of the same types of tools, this will likely work for C++ libraries as well.

# GPL?

cpm will be covered by the GPL, version 3 or later. See [the license](GPL.md) for more information. This does not affect the licensing of projects using it to download dependencies or projects which create cpm packages; see the [GPL FAQ](https://www.gnu.org/licenses/gpl-faq.en.html#CanIUseGPLToolsForNF).
