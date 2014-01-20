#
# ICU - International Components for Unicode
# 

module ICU

export set_locale

export U_FAILURE,
       U_SUCCESS,

       # ubrk
       UBRK_CHARACTER,
       UBRK_LINE,
       UBRK_SENTENCE,
       UBRK_TITLE,
       UBRK_WORD,
       UBreakIterator,
       ubrk_close,
       ubrk_next,
       ubrk_open,

       # ucasemap
       ucasemap_utf8FoldCase,
       ucasemap_utf8ToLower,
       ucasemap_utf8ToTitle,
       ucasemap_utf8ToUpper,

       # ucol
       UCollator,
       ucol_close,
       ucol_open,
       ucol_strcoll,

       # ustring
       u_strFoldCase,
       u_strToLower,
       u_strToUpper,
       u_strToTitle

include("../deps/deps.jl")
include("../deps/versions.jl")

@windows_only begin
    # make sure versions match
    v1 = int(iculib[end-1:end])
    v2 = int(icui18nlib[end-1:end])
    v = max(v1, v2)
    if v1 < v2
        global const iculib = string(iculib[end-1:end], v)
    elseif v1 > v2
        global const icui18nlib = string(icui18nlib[end-1:end], v)
    end
end

dliculib = dlopen(iculib)
for (suffix,version) in [("",0);
                         [("_$i",i) for i in versions];
                         [("_$(string(i)[1])_$(string(i)[2])",i) for i in versions]]
    if dlsym_e(dliculib, "u_strToUpper"*suffix) != C_NULL
        @eval const version = $version
        for f in (:u_strFoldCase,
                  :u_strToLower,
                  :u_strToTitle,
                  :u_strToUpper,
                  :ubrk_close,
                  :ubrk_next,
                  :ubrk_open,
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
                  :ucol_close,
                  :ucol_open,
                  :ucol_strcoll,
                  :ucol_strcollUTF8,
                  :udat_close,
                  :udat_format,
                  :udat_open,
                  :udat_parse)
            @eval const $(symbol(string('_',f))) = $(string(f,suffix))
        end
        break
    end
end

typealias UErrorCode Int32
typealias UChar Uint16

U_FAILURE(x::Int32) = x > 0
U_SUCCESS(x::Int32) = x <= 0

locale = C_NULL
casemap = C_NULL
collator = C_NULL

typealias LocaleString Union(ASCIIString,Ptr{None})

function set_locale(s::LocaleString)
    global casemap, collator
    if casemap != C_NULL
        ccall((_ucasemap_close,iculib), Void, (Ptr{Void},), casemap)
    end
    if collator != C_NULL
        ucol_close(collator)
    end
    err = UErrorCode[0]
    casemap = ccall((_ucasemap_open,iculib), Ptr{Void},
        (Ptr{Uint8},Int32,Ptr{UErrorCode}), s, 0, err)
    U_FAILURE(err[1]) && error("could not set casemap")
    collator = ucol_open(s)
    global locale = s
end

## ustring ##

for f in [:u_strToLower, :u_strToUpper]
    @eval begin
        function ($f)(s::UTF16String)
            src = s.data
            destsiz = int32(2*length(src))
            dest = zeros(Uint16, destsiz)
            err = UErrorCode[0]
            n = ccall(($(symbol(string('_',f))),iculib), Int32,
                (Ptr{Uint16},Int32,Ptr{Uint16},Int32,Ptr{Uint8},Ptr{UErrorCode}),
                dest, destsiz, src, length(src), locale, err)
            U_FAILURE(err[1]) && error("failed to map case")
            return UTF16String(dest[1:n])
        end
    end
end

function u_strFoldCase(s::UTF16String)
    src = s.data
    destsiz = int32(2*length(src))
    dest = zeros(Uint16, destsiz)
    err = UErrorCode[0]
    n = ccall((_u_strFoldCase,iculib), Int32,
        (Ptr{Uint16},Int32,Ptr{Uint16},Int32,Uint32,Ptr{UErrorCode}),
        dest, destsiz, src, length(src), 0, err)
    U_FAILURE(err[1]) && error("failed to map case")
    return UTF16String(dest[1:n])
end

function u_strToTitle(s::UTF16String)
    src = s.data
    destsiz = int32(2*length(src))
    dest = zeros(Uint16, destsiz)
    err = UErrorCode[0]
    breakiter = ccall((_ucasemap_getBreakIterator,iculib),
        Ptr{Void}, (Ptr{Void},), casemap)
    n = ccall((_u_strToTitle,iculib), Int32,
        (Ptr{Uint16},Int32,Ptr{Uint16},Int32,Ptr{Void},Ptr{Uint8},Ptr{UErrorCode}),
        dest, destsiz, src, length(src), breakiter, locale, err)
    U_FAILURE(err[1]) && error("failed to map case")
    return UTF16String(dest[1:n])
end

## ucasemap ##

for f in [:ucasemap_utf8FoldCase,
          :ucasemap_utf8ToLower,
          :ucasemap_utf8ToTitle,
          :ucasemap_utf8ToUpper]
    @eval begin
        function ($f)(src::UTF8String)
            destsiz = int32(2*length(src))
            dest = zeros(Uint8, destsiz)
            err = UErrorCode[0]
            n = ccall(($(symbol(string('_',f))),iculib), Int32,
                (Ptr{Void},Ptr{Uint8},Int32,Ptr{Uint8},Int32,Ptr{UErrorCode}),
                casemap, dest, destsiz, src, -1, err)
            U_FAILURE(err[1]) && error("failed to map case")
            return utf8(dest[1:n])
        end
    end
end

## ubrk ##

const UBRK_CHARACTER = int32(0)
const UBRK_WORD = int32(1)
const UBRK_LINE = int32(2)
const UBRK_SENTENCE = int32(3)
const UBRK_TITLE = int32(4)

immutable UBreakIterator
    p::Ptr{Void}
end

function ubrk_open(kind::Integer, loc::LocaleString, s::Array{Uint16,1})
    err = UErrorCode[0]
    p = ccall((_ubrk_open,iculib), Ptr{Void},
            (Int32,Ptr{Uint8},Ptr{Uint16},Int32,Ptr{UErrorCode}),
            kind, loc, s, length(s), err)
    @assert U_SUCCESS(err[1])
    UBreakIterator(p)
end

ubrk_close(bi::UBreakIterator) =
    ccall((_ubrk_close,iculib), Void, (Ptr{Void},), bi.p)

ubrk_next(bi::UBreakIterator) =
    ccall((_ubrk_next,iculib), Int32, (Ptr{Void},), bi.p)

## ucol ##

immutable UCollator
    p::Ptr{Void}
end

ucol_close(c::UCollator) =
    ccall((_ucol_close,iculibi18n), Void, (Ptr{Void},), c.p)

function ucol_open(loc::LocaleString)
    err = UErrorCode[0]
    p = ccall((_ucol_open,iculibi18n), Ptr{Void},
        (Ptr{Uint8},Ptr{UErrorCode}), loc, err)
    U_SUCCESS(err[1]) || error("ICU: could not open collator for locale ", locale)
    UCollator(p)
end

function ucol_strcoll(c::UCollator, a::Array{Uint16,1}, b::Array{Uint16,1})
    err = UErrorCode[0]
    o = ccall((_ucol_strcoll,iculibi18n), Int32,
            (Ptr{Void},Ptr{Uint16},Int32,Ptr{Uint16},Int32,Ptr{UErrorCode}),
            c.p, a, length(a), b, length(b), err)
    @assert U_SUCCESS(err[1])
    o
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
    p = ccall((_ucal_open,iculibi18n), Ptr{Void},
        (Ptr{Uint16},Int32,Ptr{Uint8},Int32,Ptr{UErrorCode}),
        tz_u16.data, length(tz_u16.data), locale, 0, err)
    ICUCalendar(p)
end
function ICUCalendar()
    err = UErrorCode[0]
    p = ccall((_ucal_open,iculibi18n), Ptr{Void},
        (Ptr{Uint16},Int32,Ptr{Uint8},Int32,Ptr{UErrorCode}),
        C_NULL, -1, locale, 0, err)
    ICUCalendar(p)
end

close(cal::ICUCalendar) =
    ccall((_ucal_close,iculibi18n), Void, (Ptr{Void},), cal.ptr)

getNow() = ccall((_ucal_getNow,iculibi18n), UDate, ())

function getMillis(cal::ICUCalendar)
    err = UErrorCode[0]
    ccall((_ucal_getMillis,iculibi18n), UDate, (Ptr{Void},Ptr{UErrorCode}),
        cal.ptr, err)
end

function setMillis(cal::ICUCalendar, millis::UDate)
    err = UErrorCode[0]
    ccall((_ucal_setMillis,iculibi18n), Void, (Ptr{Void},UDate,Ptr{UErrorCode}),
        cal.ptr, millis, err)
end

function setDate(cal::ICUCalendar, y::Integer, m::Integer, d::Integer)
    err = UErrorCode[0]
    ccall((_ucal_setDate,iculibi18n), Void,
        (Ptr{Void},Int32,Int32,Int32,Ptr{UErrorCode}),
        cal.ptr, y, m-1, d, err)
end

function setDateTime(cal::ICUCalendar, y::Integer, mo::Integer, d::Integer, h::Integer, mi::Integer, s::Integer)
    err = UErrorCode[0]
    ccall((_ucal_setDateTime,iculibi18n), Void,
        (Ptr{Void},Int32,Int32,Int32,Int32,Int32,Int32,Ptr{UErrorCode}),
        cal.ptr, y, mo-1, d, h, mi, s, err)
end

function clear(cal::ICUCalendar)
    err = UErrorCode[0]
    ccall((_ucal_clear,iculibi18n), Void, (Ptr{Void},Ptr{UErrorCode}), cal.ptr, err)
end

function get(cal::ICUCalendar, field::Int32)
    err = UErrorCode[0]
    ccall((_ucal_get,iculibi18n), Int32,
        (Ptr{Void},Int32,Ptr{UErrorCode}),
        cal.ptr, field, err)
end
get(cal::ICUCalendar, fields::Array{Int32,1}) = [get(cal,f) for f in fields]

function add(cal::ICUCalendar, field::Int32, amount::Integer)
    err = UErrorCode[0]
    ccall((_ucal_add,iculibi18n), Int32,
        (Ptr{Void},Int32,Int32,Ptr{UErrorCode}),
        cal.ptr, field, amount, err)
end

function set(cal::ICUCalendar, field::Int32, val::Integer)
    ccall((_ucal_set,iculibi18n), Void,
        (Ptr{Void},Int32,Int32), cal.ptr, field, val)
end

function getTimeZoneDisplayName(cal::ICUCalendar)
    bufsz = 64
    buf = Array(Uint16, bufsz)
    err = UErrorCode[0]
    len = ccall((_ucal_getTimeZoneDisplayName,iculibi18n), Int32,
                (Ptr{Void},Int32,Ptr{Uint8},Ptr{UChar},Int32,Ptr{UErrorCode}),
                cal.ptr, 1, locale, buf, bufsz, err)
    UTF16String(buf[1:len])
end

function getDefaultTimeZone()
    bufsz = 64
    buf = Array(Uint16, bufsz)
    err = UErrorCode[0]
    len = ccall((_ucal_getDefaultTimeZone,iculibi18n), Int32,
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
    p = ccall((_udat_open,iculibi18n), Ptr{Void},
          (Int32, Int32, Ptr{Uint8}, Ptr{UChar}, Int32, Ptr{UChar}, Int32, Ptr{UErrorCode}),
          -2, -2, locale, tz_u16.data, length(tz_u16.data),
          pattern_u16.data, length(pattern_u16.data), err)
    U_FAILURE(err[1]) && error("bad date format")
    ICUDateFormat(p)
end
function ICUDateFormat(tstyle::Integer, dstyle::Integer, tz::String)
    tz_u16 = utf16(tz)
    err = UErrorCode[0]
    p = ccall((_udat_open,iculibi18n), Ptr{Void},
          (Int32, Int32, Ptr{Uint8}, Ptr{UChar}, Int32, Ptr{UChar}, Int32, Ptr{UErrorCode}),
          tstyle, dstyle, locale, tz_u16.data, length(tz_u16.data), C_NULL, -1, err)
    U_FAILURE(err[1]) && error("bad date format")
    ICUDateFormat(p)
end

close(df::ICUDateFormat) =
    ccall((_udat_close,iculibi18n), Void, (Ptr{Void},), df.ptr)

function format(df::ICUDateFormat, millis::Float64)
    err = UErrorCode[0]
    buflen = 64
    buf = zeros(UChar, buflen)
    len = ccall((_udat_format,iculibi18n), Int32,
          (Ptr{Void}, Float64, Ptr{UChar}, Int32, Ptr{Void}, Ptr{UErrorCode}),
          df.ptr, millis, buf, buflen, C_NULL, err)
    U_FAILURE(err[1]) && error("failed to format time")
    UTF16String(buf[1:len])
end

function parse(df::ICUDateFormat, s::String)
    s16 = utf16(s)
    err = UErrorCode[0]
    ret = ccall((_udat_parse,iculibi18n), Float64,
                (Ptr{Void}, Ptr{UChar}, Int32, Ptr{Int32}, Ptr{UErrorCode}),
                df.ptr, s16.data, length(s16.data), C_NULL, err)
    U_FAILURE(err[1]) && error("failed to parse string")
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

## init ##

set_locale(locale)

end # module
