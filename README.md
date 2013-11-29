ICU.jl: International Components for Unicode (ICU) wrapper for Julia
====================================================================

Installation
------------

    julia> Pkg.add("ICU")

ICU.jl requires the [International Components for Unicode (ICU) libraries](http://site.icu-project.org/)
be installed on your system. They come preinstalled on OS X and most Linux
desktop distributions, but if not:

* Arch: `pacman -S icu`
* Fedora: `yum install icu`
* Ubuntu: `aptitude install libicu48`
* Windows: binaries are available [here](http://site.icu-project.org/download).

Usage
-----

The ICU module extends Julia's builtin `uppercase` and `lowercase` functions,
and adds `titlecase` and `foldcase`.

    julia> uppercase("testingß")
    "TESTINGß"

    julia> using ICU

    julia> uppercase("testingß")
    "TESTINGSS"

    julia> set_locale("tr")  # set locale to Turkish
    "tr"

    julia> uppercase("testingß")
    "TESTİNGSS"

Note that "ß" gets converted to "SS" after ICU is loaded,
and "i" gets converted to "İ" (dotted capital I)
after the locale is set to Turkish.

Also included is the `UnicodeText` type.

```jlcon
julia> noel1 = UnicodeText("noe\u0308l")
"noël"

julia> noel2 = UnicodeText("noël")
"noël"

julia> noel1.data
5-element Array{Uint16,1}:
 0x006e
 0x006f
 0x0065
 0x0308
 0x006c

julia> noel2.data
4-element Array{Uint16,1}:
 0x006e
 0x006f
 0x00eb
 0x006c

julia> noel1 == noel2
true

julia> length(noel1) == 4 == length(noel2)
true

julia> noel1[1:3]
"noë"
```

