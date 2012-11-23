ICU.jl: International Components for Unicode (ICU) wrapper for Julia
====================================================================

Usage
-----

The ICU modules extends Julia's builtin `uppercase` and `lowercase` functions,
and adds `titlecase` and `foldcase`.

    julia> uppercase("testingß")
    "TESTINGß"

    julia> require("ICU")

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

Basic calendar support is also wrapped.
This example prints the current local time in Los Angeles:

    julia> cal = ICUCalendar("America/Los_Angeles")
    ICUCalendar(Ptr{Void} @0x00000000038536e0)

    julia> setMillis(cal, getNow())

    julia> fields = [UCAL_YEAR, UCAL_MONTH, UCAL_DATE,
                     UCAL_HOUR_OF_DAY, UCAL_MINUTE, UCAL_SECOND];

    julia> get(cal, fields)
    6-element Int32 Array:
     2012
       10
       22
       17
       45
       49

Installation
------------

    julia> load("pkg.jl")

    julia> Pkg.init()
    ...

    julia> Pkg.add("ICU")

