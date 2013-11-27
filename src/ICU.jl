#
# ICU - International Components for Unicode
# 
# Example:
#
#   using ICU
#   uppercase("testingß")  # "TESTINGSS"
#   set_locale("tr")       # set locale to Turkish
#   uppercase("testingß")  # "TESTİNGSS"
#
# Note that "ß" gets converted to "SS" in the first call to uppercase,
# and "i" gets converted to "İ" (dotted capital I) in the second call
# after the locale is set to Turkish.
#

module ICU

import Base: lowercase,
             uppercase

export foldcase,
       set_locale,
       titlecase

versions = 52:-1:40

if OS_NAME == :Windows
    found = false
    for v in versions
        icuuc = dlopen_e("icuuc$v")
        if icuuc != C_NULL
            global const iculib = icuuc
            global const iculibi18n = dlopen("icuin$v")
            found = true
            break
        end
    end
    if !found
        error("can't find ICU libraries")
    end
elseif OS_NAME == :Darwin
    global const iculib = dlopen("libicucore")
    global const iculibi18n = iculib
else
    global const iculib = dlopen("libicuuc")
    global const iculibi18n = dlopen("libicui18n")
end

for suffix in ["", ["_$i" for i in versions], ["_$(string(i)[1])_$(string(i)[2])" for i in versions]]
    if dlsym_e(iculib, "u_strToUpper"*suffix) != C_NULL
        for f in (:u_strFoldCase,
                  :u_strToLower,
                  :u_strToTitle,
                  :u_strToUpper,
                  :ucal_add,
                  :ucal_clear,
                  :ucal_close,
                  :ucal_get,
                  :ucal_getDefaultTimeZone,
                  :ucal_getTimeZoneDisplayName,
                  :ucal_getMillis,
                  :ucal_getNow,
                  :ucal_open,
                  :ucal_set,
                  :ucal_setDate,
                  :ucal_setDateTime,
                  :ucal_setMillis,
                  :ucasemap_open,
                  :ucasemap_close,
                  :ucasemap_getBreakIterator,
                  :ucasemap_utf8FoldCase,
                  :ucasemap_utf8ToLower,
                  :ucasemap_utf8ToTitle,
                  :ucasemap_utf8ToUpper,
                  :udat_close,
                  :udat_format,
                  :udat_open,
                  :udat_parse)
            @eval const $f = $(string(f) * suffix)
        end
        break
    end
end

typealias UErrorCode Int32
typealias UChar Uint16

locale = C_NULL
casemap = C_NULL

function set_locale(s::Union(ByteString,Ptr{None}))
    global casemap
    if casemap != C_NULL
        ccall(dlsym(iculib,ucasemap_close), Void, (Ptr{Void},), casemap)
    end
    err = UErrorCode[0]
    casemap = ccall(dlsym(iculib,ucasemap_open), Ptr{Void},
        (Ptr{Uint8},Int32,Ptr{UErrorCode}), s, 0, err)
    if casemap != C_NULL
        global locale = s
    end
end
set_locale(locale)

for (a,b) in [(:lowercase,:u_strToLower),
              (:uppercase,:u_strToUpper)]
    @eval begin
        function ($a)(s::UTF16String)
            src = s.data
            destsiz = int32(2*length(src))
            dest = zeros(Uint16, destsiz)
            err = UErrorCode[0]
            n = ccall(dlsym(iculib,$b), Int32,
                (Ptr{Uint16},Int32,Ptr{Uint16},Int32,Ptr{Uint8},Ptr{UErrorCode}),
                dest, destsiz, src, length(src), locale, err)
            return UTF16String(dest[1:n])
        end
    end
end

function foldcase(s::UTF16String)
    src = s.data
    destsiz = int32(2*length(src))
    dest = zeros(Uint16, destsiz)
    err = UErrorCode[0]
    n = ccall(dlsym(iculib,u_strFoldCase), Int32,
        (Ptr{Uint16},Int32,Ptr{Uint16},Int32,Uint32,Ptr{UErrorCode}),
        dest, destsiz, src, length(src), 0, err)
    return UTF16String(dest[1:n])
end

function titlecase(s::UTF16String)
    src = s.data
    destsiz = int32(2*length(src))
    dest = zeros(Uint16, destsiz)
    err = UErrorCode[0]
    breakiter = ccall(dlsym(iculib,ucasemap_getBreakIterator),
        Ptr{Void}, (Ptr{Void},), casemap)
    n = ccall(dlsym(iculib,u_strToTitle), Int32,
        (Ptr{Uint16},Int32,Ptr{Uint16},Int32,Ptr{Void},Ptr{Uint8},Ptr{UErrorCode}),
        dest, destsiz, src, length(src), breakiter, locale, err)
    return UTF16String(dest[1:n])
end

for (a,b) in [(:foldcase,:ucasemap_utf8FoldCase),
              (:lowercase,:ucasemap_utf8ToLower),
              (:titlecase,:ucasemap_utf8ToTitle),
              (:uppercase,:ucasemap_utf8ToUpper)]
    @eval begin
        function ($a)(src::UTF8String)
            destsiz = int32(2*length(src))
            dest = zeros(Uint8, destsiz)
            err = UErrorCode[0]
            n = ccall(dlsym(iculib,$b), Int32,
                (Ptr{Void},Ptr{Uint8},Int32,Ptr{Uint8},Int32,Ptr{UErrorCode}),
                casemap, dest, destsiz, src, -1, err)
            return utf8(dest[1:n])
        end
    end
end

foldcase(s::ASCIIString) = foldcase(utf8(s))
titlecase(s::ASCIIString) = titlecase(utf8(s))

function test_icustring()
    @assert uppercase("testingß") == "TESTINGSS"
    set_locale("tr")       # set locale to Turkish
    @assert uppercase("testingß") == "TESTİNGSS"
end

## calendar ##

export ICUCalendar,
       add,
       clear,
       get,
       getDefaultTimeZone,
       getMillis,
       getNow,
       getTimeZoneDisplayName,
       set,
       setDate,
       setDateTime,
       setMillis

export UCAL_ERA,
       UCAL_YEAR,
       UCAL_MONTH,
       UCAL_WEEK_OF_YEAR,
       UCAL_WEEK_OF_MONTH,
       UCAL_DATE,
       UCAL_DAY_OF_YEAR,
       UCAL_DAY_OF_WEEK,
       UCAL_DAY_OF_WEEK_IN_MONTH,
       UCAL_AM_PM,
       UCAL_HOUR,
       UCAL_HOUR_OF_DAY,
       UCAL_MINUTE,
       UCAL_SECOND,
       UCAL_MILLISECOND,
       UCAL_ZONE_OFFSET,
       UCAL_DST_OFFSET,
       UCAL_YEAR_WOY,
       UCAL_DOW_LOCAL,
       UCAL_EXTENDED_YEAR,
       UCAL_JULIAN_DAY,
       UCAL_MILLISECONDS_IN_DAY,
       UCAL_IS_LEAP_MONTH

for (i,a) in enumerate([
        :UCAL_ERA,
        :UCAL_YEAR,
        :UCAL_MONTH,
        :UCAL_WEEK_OF_YEAR,
        :UCAL_WEEK_OF_MONTH,
        :UCAL_DATE,
        :UCAL_DAY_OF_YEAR,
        :UCAL_DAY_OF_WEEK,
        :UCAL_DAY_OF_WEEK_IN_MONTH,
        :UCAL_AM_PM,
        :UCAL_HOUR,
        :UCAL_HOUR_OF_DAY,
        :UCAL_MINUTE,
        :UCAL_SECOND,
        :UCAL_MILLISECOND,
        :UCAL_ZONE_OFFSET,
        :UCAL_DST_OFFSET,
        :UCAL_YEAR_WOY,
        :UCAL_DOW_LOCAL,
        :UCAL_EXTENDED_YEAR,
        :UCAL_JULIAN_DAY,
        :UCAL_MILLISECONDS_IN_DAY,
        :UCAL_IS_LEAP_MONTH
    ])
    @eval const $a = int32($i - 1)
end

typealias UDate Float64

type ICUCalendar
    ptr::Ptr{Void}
    ICUCalendar(p::Ptr) = (self = new(p); finalizer(self, close); self)
end

function ICUCalendar(timezone::String)
    tz_u16 = utf16(timezone)
    err = UErrorCode[0]
    p = ccall(dlsym(iculibi18n,ucal_open), Ptr{Void},
        (Ptr{Uint16},Int32,Ptr{Uint8},Int32,Ptr{UErrorCode}),
        tz_u16.data, length(tz_u16.data), locale, 0, err)
    ICUCalendar(p)
end
function ICUCalendar()
    err = UErrorCode[0]
    p = ccall(dlsym(iculibi18n,ucal_open), Ptr{Void},
        (Ptr{Uint16},Int32,Ptr{Uint8},Int32,Ptr{UErrorCode}),
        C_NULL, -1, locale, 0, err)
    ICUCalendar(p)
end

close(cal::ICUCalendar) =
    ccall(dlsym(iculibi18n,ucal_close), Void, (Ptr{Void},), cal.ptr)

getNow() = ccall(dlsym(iculibi18n,ucal_getNow), UDate, ())

function getMillis(cal::ICUCalendar)
    err = UErrorCode[0]
    ccall(dlsym(iculibi18n,ucal_getMillis), UDate, (Ptr{Void},Ptr{UErrorCode}),
        cal.ptr, err)
end

function setMillis(cal::ICUCalendar, millis::UDate)
    err = UErrorCode[0]
    ccall(dlsym(iculibi18n,ucal_setMillis), Void, (Ptr{Void},UDate,Ptr{UErrorCode}),
        cal.ptr, millis, err)
end

function setDate(cal::ICUCalendar, y::Integer, m::Integer, d::Integer)
    err = UErrorCode[0]
    ccall(dlsym(iculibi18n,ucal_setDate), Void,
        (Ptr{Void},Int32,Int32,Int32,Ptr{UErrorCode}),
        cal.ptr, y, m-1, d, err)
end

function setDateTime(cal::ICUCalendar, y::Integer, mo::Integer, d::Integer, h::Integer, mi::Integer, s::Integer)
    err = UErrorCode[0]
    ccall(dlsym(iculibi18n,ucal_setDateTime), Void,
        (Ptr{Void},Int32,Int32,Int32,Int32,Int32,Int32,Ptr{UErrorCode}),
        cal.ptr, y, mo-1, d, h, mi, s, err)
end

function clear(cal::ICUCalendar)
    err = UErrorCode[0]
    ccall(dlsym(iculibi18n,ucal_clear), Void, (Ptr{Void},Ptr{UErrorCode}), cal.ptr, err)
end

function get(cal::ICUCalendar, field::Int32)
    err = UErrorCode[0]
    ccall(dlsym(iculibi18n,ucal_get), Int32,
        (Ptr{Void},Int32,Ptr{UErrorCode}),
        cal.ptr, field, err)
end
get(cal::ICUCalendar, fields::Array{Int32,1}) = [get(cal,f) for f in fields]

function add(cal::ICUCalendar, field::Int32, amount::Integer)
    err = UErrorCode[0]
    ccall(dlsym(iculibi18n,ucal_add), Int32,
        (Ptr{Void},Int32,Int32,Ptr{UErrorCode}),
        cal.ptr, field, amount, err)
end

function set(cal::ICUCalendar, field::Int32, val::Integer)
    ccall(dlsym(iculibi18n,ucal_set), Void,
        (Ptr{Void},Int32,Int32), cal.ptr, field, val)
end

function getTimeZoneDisplayName(cal::ICUCalendar)
    bufsz = 64
    buf = Array(Uint16, bufsz)
    err = UErrorCode[0]
    len = ccall(dlsym(iculibi18n,ucal_getTimeZoneDisplayName), Int32,
                (Ptr{Void},Int32,Ptr{Uint8},Ptr{UChar},Int32,Ptr{UErrorCode}),
                cal.ptr, 1, locale, buf, bufsz, err)
    UTF16String(buf[1:len])
end

function getDefaultTimeZone()
    bufsz = 64
    buf = Array(Uint16, bufsz)
    err = UErrorCode[0]
    len = ccall(dlsym(iculibi18n,ucal_getDefaultTimeZone), Int32,
                (Ptr{UChar},Int32,Ptr{UErrorCode}), buf, bufsz, err)
    UTF16String(buf[1:len])
end

export ICUDateFormat,
       format,
       parse

export UDAT_NONE,
       UDAT_FULL,
       UDAT_LONG,
       UDAT_MEDIUM,
       UDAT_SHORT,
       UDAT_RELATIVE

const UDAT_NONE     = int32(-1)
const UDAT_FULL     = int32(0)
const UDAT_LONG     = int32(1)
const UDAT_MEDIUM   = int32(2)
const UDAT_SHORT    = int32(3)
const UDAT_RELATIVE = int32(1<<7)

type ICUDateFormat
    ptr::Ptr{Void}
    ICUDateFormat(p::Ptr) = (self = new(p); finalizer(self, close); self)
end

function ICUDateFormat(pattern::String, tz::String)
    pattern_u16 = utf16(pattern)
    tz_u16 = utf16(tz)
    err = UErrorCode[0]
    p = ccall(dlsym(iculibi18n,udat_open), Ptr{Void},
          (Int32, Int32, Ptr{Uint8}, Ptr{UChar}, Int32, Ptr{UChar}, Int32, Ptr{UErrorCode}),
          -2, -2, locale, tz_u16.data, length(tz_u16.data),
          pattern_u16.data, length(pattern_u16.data), err)
    ICUDateFormat(p)
end
function ICUDateFormat(tstyle::Integer, dstyle::Integer, tz::String)
    tz_u16 = utf16(tz)
    err = UErrorCode[0]
    p = ccall(dlsym(iculibi18n,udat_open), Ptr{Void},
          (Int32, Int32, Ptr{Uint8}, Ptr{UChar}, Int32, Ptr{UChar}, Int32, Ptr{UErrorCode}),
          tstyle, dstyle, locale, tz_u16.data, length(tz_u16.data), C_NULL, -1, err)
    ICUDateFormat(p)
end

close(df::ICUDateFormat) =
    ccall(dlsym(iculibi18n,udat_close), Void, (Ptr{Void},), df.ptr)

function format(df::ICUDateFormat, millis::Float64)
    err = UErrorCode[0]
    buflen = 64
    buf = zeros(UChar, buflen)
    len = ccall(dlsym(iculibi18n,udat_format), Int32,
          (Ptr{Void}, Float64, Ptr{UChar}, Int32, Ptr{Void}, Ptr{UErrorCode}),
          df.ptr, millis, buf, buflen, C_NULL, err)
    UTF16String(buf[1:len])
end

function parse(df::ICUDateFormat, s::String)
    s16 = utf16(s)
    err = UErrorCode[0]
    ret = ccall(dlsym(iculibi18n,udat_parse), Float64,
                (Ptr{Void}, Ptr{UChar}, Int32, Ptr{Int32}, Ptr{UErrorCode}),
                df.ptr, s16.data, length(s16.data), C_NULL, err)
    @assert err[1] == 0
    ret
end

function test_icucalendar()
    cal = ICUCalendar("America/Los_Angeles")
    setMillis(cal, getNow())
    fields = [UCAL_YEAR, UCAL_MONTH, UCAL_DATE,
              UCAL_HOUR_OF_DAY, UCAL_MINUTE, UCAL_SECOND]
    println(get(cal,fields))
    clear(cal)
    df = ICUDateFormat()
    s = format(df, getNow())
    show(s)
end

end # module
