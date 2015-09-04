#
# ICU - International Components for Unicode
#

module ICU

using Compat

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
       ubrk_setUText,

       # ucasemap
       ucasemap_utf8FoldCase,
       ucasemap_utf8ToLower,
       ucasemap_utf8ToTitle,
       ucasemap_utf8ToUpper,

       # ucnv
       UConverter,
       ucnv_close,
       ucnv_convertEx,
       ucnv_open,
       ucnv_toUChars,

       # ucol
       UCollator,
       ucol_close,
       ucol_open,
       ucol_strcoll,

       # ustring
       u_strFoldCase,
       u_strToLower,
       u_strToUpper,
       u_strToTitle,

       # utext
       UText,
       utext_close,
       utext_open

include("../deps/deps.jl")
include("../deps/versions.jl")

@windows_only begin
    # make sure versions match
    v1 = last(matchall(r"\d{2}", iculib))
    v2 = last(matchall(r"\d{2}", iculibi18n))
    if v1 != v2
        error("ICU library version mismatch -- please correct $(realpath("../deps/deps.jl"))")
    end
end

dliculib = Libdl.dlopen(iculib)
for (suffix,version) in [("",0);
                         [("_$i",i) for i in versions];
                         [("_$(string(i)[1])_$(string(i)[2])",i) for i in versions]]
    if Libdl.dlsym_e(dliculib, "u_strToUpper"*suffix) != C_NULL
        @eval const version = $version
        for f in (:u_strFoldCase,
                  :u_strToLower,
                  :u_strToTitle,
                  :u_strToUpper,
                  :ubrk_close,
                  :ubrk_next,
                  :ubrk_open,
                  :ubrk_setUText,
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
                  :ucnv_close,
                  :ucnv_convertEx,
                  :ucnv_open,
                  :ucnv_toUChars,
                  :ucol_close,
                  :ucol_open,
                  :ucol_strcoll,
                  :ucol_strcollUTF8,
                  :udat_close,
                  :udat_format,
                  :udat_open,
                  :udat_parse,
                  :utext_close,
                  :utext_openUChars,
                  :utext_openUTF8)
            @eval const $(symbol(string('_',f))) = $(string(f,suffix))
        end
        break
    end
end

typealias UBool Int8
typealias UChar UInt16
typealias UErrorCode Int32

U_FAILURE(x::Int32) = x > 0
U_SUCCESS(x::Int32) = x <= 0
U_BUFFER_OVERFLOW_ERROR = 15

locale = C_NULL
casemap = C_NULL
collator = C_NULL

typealias LocaleString Union(ASCIIString,Ptr{Void})

function set_locale(loc::LocaleString)
    global locale, casemap, collator
    if casemap != C_NULL
        ccall((_ucasemap_close, iculib), Void, (Ptr{Void},), casemap)
        casemap = C_NULL
    end
    if collator != C_NULL
        ucol_close(collator)
        collator = C_NULL
    end
    err = UErrorCode[0]
    casemap = ccall((_ucasemap_open, iculib), Ptr{Void},
                    (Ptr{UInt8}, Int32, Ptr{UErrorCode}),
                    loc, 0, err)
    U_FAILURE(err[1]) && error("could not set casemap")
    collator = ucol_open(loc)
    locale = loc
end

## utext ##

immutable UText
    p::Ptr{Void}
end

function utext_open(str::UTF8String)
    err = UErrorCode[0]
    p = ccall((_utext_openUTF8, iculib), Ptr{Void},
              (Ptr{Void}, Ptr{UInt8}, Int64, Ptr{UErrorCode}),
              C_NULL, str.data, sizeof(str.data), err)
    @assert U_SUCCESS(err[1])
    UText(p)
end

function utext_open(str::UTF16String)
    err = UErrorCode[0]
    p = ccall((_utext_openUChars, iculib), Ptr{Void},
              (Ptr{Void}, Ptr{UChar}, Int64, Ptr{UErrorCode}),
              C_NULL, str.data, length(str.data)-1, err)
    @assert U_SUCCESS(err[1])
    UText(p)
end

function utext_close(t::UText)
    if (t.p != C_NULL)
        ccall((_utext_close, iculib), Void, (Ptr{Void},), t.p)
        t.p = C_NULL
    end
end

## ustring ##

for f in [:u_strToLower, :u_strToUpper]
    @eval begin
        function ($f)(s::UTF16String)
            src = s.data
            destsiz = @compat Int32(2*length(src))
            dest = zeros(UInt16, destsiz)
            err = UErrorCode[0]
            n = ccall(($(symbol(string('_',f))), iculib), Int32,
                      (Ptr{UChar}, Int32, Ptr{UChar}, Int32, Ptr{UInt8}, Ptr{UErrorCode}),
                      dest, destsiz, src, length(src)-1, locale, err)
            U_FAILURE(err[1]) && error("failed to map case")
            return UTF16String(dest[1:n+1])
        end
    end
end

function u_strFoldCase(s::UTF16String)
    src = s.data
    destsiz = @compat Int32(2*length(src))
    dest = zeros(UInt16, destsiz)
    err = UErrorCode[0]
    n = ccall((_u_strFoldCase, iculib), Int32,
              (Ptr{UChar}, Int32, Ptr{UChar}, Int32, UInt32, Ptr{UErrorCode}),
              dest, destsiz, src, length(src)-1, 0, err)
    U_FAILURE(err[1]) && error("failed to map case")
    return UTF16String(dest[1:n+1])
end

function u_strToTitle(s::UTF16String)
    src = s.data
    destsiz = @compat Int32(2*length(src))
    dest = zeros(UInt16, destsiz)
    err = UErrorCode[0]
    breakiter = ccall((_ucasemap_getBreakIterator, iculib), Ptr{Void}, (Ptr{Void},), casemap)
    n = ccall((_u_strToTitle, iculib), Int32,
              (Ptr{UChar}, Int32, Ptr{UChar}, Int32, Ptr{Void}, Ptr{UInt8}, Ptr{UErrorCode}),
              dest, destsiz, src, length(src)-1, breakiter, locale, err)
    U_FAILURE(err[1]) && error("failed to map case")
    return UTF16String(dest[1:n+1])
end

## ucasemap ##

for f in [:ucasemap_utf8FoldCase,
          :ucasemap_utf8ToLower,
          :ucasemap_utf8ToTitle,
          :ucasemap_utf8ToUpper]
    @eval begin
        function ($f)(src::UTF8String)
            destsiz = @compat Int32(2*length(src))
            dest = zeros(Cchar, destsiz)
            err = UErrorCode[0]
            n = ccall(($(symbol(string('_',f))), iculib), Int32,
                      (Ptr{Void}, Ptr{Cchar}, Int32, Ptr{Cchar}, Int32, Ptr{UErrorCode}),
                      casemap, dest, destsiz, src.data, sizeof(src.data), err)
            U_FAILURE(err[1]) && error("failed to map case")
            return utf8(dest[1:n])
        end
    end
end

## ubrk ##

typealias UBreakIteratorType Int32
const UBRK_CHARACTER = @compat Int32(0)
const UBRK_WORD = @compat Int32(1)
const UBRK_LINE = @compat Int32(2)
const UBRK_SENTENCE = @compat Int32(3)
const UBRK_TITLE = @compat Int32(4)

type UBreakIterator
    p::Ptr{Void}
    UBreakIterator(p::Ptr) = (self = new(p); finalizer(self, close); self)
end

function ubrk_open(kind::Integer, loc::LocaleString, s::Vector{UInt16})
    err = UErrorCode[0]
    p = ccall((_ubrk_open, iculib), Ptr{Void},
              (UBreakIteratorType, Ptr{UInt8}, Ptr{UChar}, Int32, Ptr{UErrorCode}),
              kind, loc, s, length(s), err)
    @assert U_SUCCESS(err[1])
    UBreakIterator(p)
end

function ubrk_open(kind::Integer, loc::LocaleString)
    err = UErrorCode[0]
    p = ccall((_ubrk_open, iculib), Ptr{Void},
              (UBreakIteratorType, Ptr{UInt8}, Ptr{UChar}, Int32, Ptr{UErrorCode}),
              kind, loc, C_NULL, 0, err)
    @assert U_SUCCESS(err[1])
    UBreakIterator(p)
end

function ubrk_close(bi::UBreakIterator)
    if bi.p != C_NULL
        ccall((_ubrk_close, iculib), Void, (Ptr{Void},), bi.p)
        bi.p = C_NULL
    end
end

ubrk_next(bi::UBreakIterator) =
    ccall((_ubrk_next, iculib), Int32, (Ptr{Void},), bi.p)

function ubrk_setUText(bi::UBreakIterator, t::UText)
    err = UErrorCode[0]
    ccall((_ubrk_setUText, iculib), Void,
          (Ptr{Void}, Ptr{Void}, Ptr{UErrorCode}),
          bi.p, t.p, err)
    @assert U_SUCCESS(err[1])
    nothing
end

## ucnv ##

type UConverter
    p::Ptr{Void}
    UConverter(p::Ptr) = (self = new(p); finalizer(self, close); self)
end

ucnv_close(c::UConverter) =
    ccall((_ucnv_close, iculibi18n), Void, (Ptr{Void},), c.p)

type UConverterPivot
    buf::Vector{UChar}
    pos::Vector{Ptr{UChar}}

    function UConverterPivot(n::Int)
        buf = Array(UChar, n)
        p = pointer(buf)
        new(buf, [p,p])
    end
end

function ucnv_convertEx(dstcnv::UConverter, srccnv::UConverter,
                        dst::IOBuffer, src::IOBuffer, pivot::UConverterPivot,
                        reset::Bool=false, flush::Bool=true)
    p = Ptr{UInt8}[pointer(dst.data, position(dst)+1),
                   pointer(src.data, position(src)+1)]
    p0 = copy(p)
    err = UErrorCode[0]
    ccall((_ucnv_convertEx, iculibi18n), Void,
          (Ptr{Void}, Ptr{Void},
           Ptr{Ptr{UInt8}}, Ptr{UInt8}, Ptr{Ptr{UInt8}}, Ptr{UInt8},
           Ptr{UChar}, Ptr{Ptr{UChar}}, Ptr{Ptr{UChar}}, Ptr{UChar},
           UBool, UBool, Ptr{UErrorCode}),
          dstcnv.p, srccnv.p,
          pointer(p, 1), pointer(dst.data, length(dst.data)+1),
          pointer(p, 2), pointer(src.data, src.size+1),
          pointer(pivot.buf, 1),
          pointer(pivot.pos, 1),
          pointer(pivot.pos, 2),
          pointer(pivot.buf, length(pivot.buf)+1),
          reset, flush, err)
    dst.size += p[1] - p0[1]
    dst.ptr += p[1] - p0[1]
    src.ptr += p[2] - p0[2]
    err[1] == U_BUFFER_OVERFLOW_ERROR && return true
    @assert U_SUCCESS(err[1])
    false
end

function ucnv_open(name::ASCIIString)
    err = UErrorCode[0]
    p = ccall((_ucnv_open, iculibi18n), Ptr{Void},
              (Cstring, Ptr{UErrorCode}),
              name, err)
    U_SUCCESS(err[1]) || error("ICU: could not open converter ", name)
    UConverter(p)
end

function ucnv_toUChars(cnv::UConverter, b::Vector{UInt8})
    u = zeros(UInt16, 2*length(b))
    err = UErrorCode[0]
    n = ccall((_ucnv_toUChars, iculibi18n), Int32,
              (Ptr{Void}, Ptr{UChar}, Int32, Ptr{UInt8}, Int32, Ptr{UErrorCode}),
              cnv.p, u, length(u), b, length(b), err)
    U_SUCCESS(err[1]) || error("ICU: could not open converter ", name)
    UTF16String(u[1:n+1])
end

## ucol ##

type UCollator
    p::Ptr{Void}
    UCollator(p::Ptr) = (self = new(p); finalizer(self, close); self)
end

function ucol_close(c::UCollator)
    if c.p != C_NULL
        ccall((_ucol_close, iculibi18n), Void, (Ptr{Void},), c.p)
        c.p = C_NULL
    end
end

function ucol_open(loc::LocaleString)
    err = UErrorCode[0]
    p = ccall((_ucol_open, iculibi18n), Ptr{Void},
              (Ptr{UInt8}, Ptr{UErrorCode}),
              loc, err)
    U_SUCCESS(err[1]) || error("ICU: could not open collator for locale ", locale)
    UCollator(p)
end

function ucol_strcoll(c::UCollator, a::UTF8String, b::UTF8String)
    err = UErrorCode[0]
    o = ccall((_ucol_strcollUTF8, iculibi18n), Int32,
              (Ptr{Void}, Ptr{UInt8}, Int32, Ptr{UInt8}, Int32, Ptr{UErrorCode}),
              c.p, a.data, sizeof(a.data), b.data, sizeof(b.data), err)
    @assert U_SUCCESS(err[1])
    o
end

function ucol_strcoll(c::UCollator, a::UTF16String, b::UTF16String)
    err = UErrorCode[0]
    o = ccall((_ucol_strcoll, iculibi18n), Int32,
              (Ptr{Void}, Ptr{UChar}, Int32, Ptr{UChar}, Int32, Ptr{UErrorCode}),
              c.p, a.data, length(a.data)-1, b.data, length(b.data)-1, err)
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
    @eval const $a = @compat Int32($i - 1)
end

typealias UDate Float64

type ICUCalendar
    ptr::Ptr{Void}
    ICUCalendar(p::Ptr) = (self = new(p); finalizer(self, close); self)
end

ICUCalendar(timezone::AbstractString) = ICUCalendar(utf16(timezone))
function ICUCalendar(tz::UTF16String)
    err = UErrorCode[0]
    p = ccall((_ucal_open, iculibi18n), Ptr{Void},
              (Ptr{UChar}, Int32, Ptr{UInt8}, Int32, Ptr{UErrorCode}),
              tz.data, length(tz.data)-1, locale, 0, err)
    ICUCalendar(p)
end
function ICUCalendar()
    err = UErrorCode[0]
    p = ccall((_ucal_open, iculibi18n), Ptr{Void},
              (Ptr{UChar}, Int32, Ptr{UInt8}, Int32, Ptr{UErrorCode}),
              C_NULL, 0, locale, 0, err)
    ICUCalendar(p)
end

function close(cal::ICUCalendar)
    if cal.ptr != C_NULL
        ccall((_ucal_close, iculibi18n), Void, (Ptr{Void},), cal.ptr)
        cal.ptr = C_NULL
    end
end

getNow() = ccall((_ucal_getNow, iculibi18n), UDate, ())

function getMillis(cal::ICUCalendar)
    err = UErrorCode[0]
    ccall((_ucal_getMillis, iculibi18n), UDate, (Ptr{Void}, Ptr{UErrorCode}), cal.ptr, err)
end

function setMillis(cal::ICUCalendar, millis::UDate)
    err = UErrorCode[0]
    ccall((_ucal_setMillis, iculibi18n), Void,
          (Ptr{Void}, UDate, Ptr{UErrorCode}),
          cal.ptr, millis, err)
end

function setDate(cal::ICUCalendar, y::Integer, m::Integer, d::Integer)
    err = UErrorCode[0]
    ccall((_ucal_setDate, iculibi18n), Void,
          (Ptr{Void}, Int32, Int32, Int32, Ptr{UErrorCode}),
          cal.ptr, y, m-1, d, err)
end

function setDateTime(cal::ICUCalendar, y::Integer, mo::Integer, d::Integer, h::Integer, mi::Integer, s::Integer)
    err = UErrorCode[0]
    ccall((_ucal_setDateTime, iculibi18n), Void,
          (Ptr{Void}, Int32, Int32, Int32, Int32, Int32, Int32, Ptr{UErrorCode}),
          cal.ptr, y, mo-1, d, h, mi, s, err)
end

function clear(cal::ICUCalendar)
    err = UErrorCode[0]
    ccall((_ucal_clear, iculibi18n), Void,
          (Ptr{Void}, Ptr{UErrorCode}),
          cal.ptr, err)
end

function get(cal::ICUCalendar, field::Int32)
    err = UErrorCode[0]
    ccall((_ucal_get, iculibi18n), Int32,
          (Ptr{Void},Int32,Ptr{UErrorCode}),
          cal.ptr, field, err)
end
get(cal::ICUCalendar, fields::Vector{Int32}) = [get(cal,f) for f in fields]

function add(cal::ICUCalendar, field::Int32, amount::Integer)
    err = UErrorCode[0]
    ccall((_ucal_add, iculibi18n), Int32,
          (Ptr{Void},Int32,Int32,Ptr{UErrorCode}),
          cal.ptr, field, amount, err)
end

function set(cal::ICUCalendar, field::Int32, val::Integer)
             ccall((_ucal_set, iculibi18n), Void,
             (Ptr{Void}, Int32, Int32),
             cal.ptr, field, val)
end

function getTimeZoneDisplayName(cal::ICUCalendar)
    bufsz = 64
    buf = zeros(UInt16, bufsz)
    err = UErrorCode[0]
    len = ccall((_ucal_getTimeZoneDisplayName, iculibi18n), Int32,
                (Ptr{Void}, Int32, Ptr{UInt8}, Ptr{UChar}, Int32, Ptr{UErrorCode}),
                cal.ptr, 1, locale, buf, bufsz, err)
    UTF16String(buf[1:len+1])
end

function getDefaultTimeZone()
    bufsz = 64
    buf = zeros(UInt16, bufsz)
    err = UErrorCode[0]
    len = ccall((_ucal_getDefaultTimeZone, iculibi18n), Int32,
                (Ptr{UChar}, Int32, Ptr{UErrorCode}),
                buf, bufsz, err)
    UTF16String(buf[1:len+1])
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

const UDAT_NONE     = @compat Int32(-1)
const UDAT_FULL     = @compat Int32(0)
const UDAT_LONG     = @compat Int32(1)
const UDAT_MEDIUM   = @compat Int32(2)
const UDAT_SHORT    = @compat Int32(3)
const UDAT_RELATIVE = @compat Int32(1<<7)

type ICUDateFormat
    ptr::Ptr{Void}
    ICUDateFormat(p::Ptr) = (self = new(p); finalizer(self, close); self)
end

ICUDateFormat(pattern::AbstractString, tz::AbstractString) = ICUDateFormat(utf16(pattern), utf16(tz))
function ICUDateFormat(pattern::UTF16String, tz::UTF16String)
    err = UErrorCode[0]
    p = ccall((_udat_open, iculibi18n), Ptr{Void},
              (Int32, Int32, Ptr{UInt8}, Ptr{UChar}, Int32, Ptr{UChar}, Int32, Ptr{UErrorCode}),
              -2, -2, locale, tz.data, length(tz.data)-1,
              pattern.data, length(pattern.data)-1, err)
    U_FAILURE(err[1]) && error("bad date format")
    ICUDateFormat(p)
end

ICUDateFormat(tstyle::Integer, dstyle::Integer, tz::AbstractString) = ICUDateFormat(tstyle, dstyle, utf16(tz))
function ICUDateFormat(tstyle::Integer, dstyle::Integer, tz::UTF16String)
    err = UErrorCode[0]
    p = ccall((_udat_open, iculibi18n), Ptr{Void},
              (Int32, Int32, Ptr{UInt8}, Ptr{UChar}, Int32, Ptr{UChar}, Int32, Ptr{UErrorCode}),
              tstyle, dstyle, locale, tz.data, length(tz.data)-1, C_NULL, 0, err)
    U_FAILURE(err[1]) && error("bad date format")
    ICUDateFormat(p)
end

close(df::ICUDateFormat) =
    ccall((_udat_close, iculibi18n), Void, (Ptr{Void},), df.ptr)

function format(df::ICUDateFormat, millis::Float64)
    err = UErrorCode[0]
    buflen = 64
    buf = zeros(UChar, buflen)
    len = ccall((_udat_format, iculibi18n), Int32,
                (Ptr{Void}, Float64, Ptr{UChar}, Int32, Ptr{Void}, Ptr{UErrorCode}),
                df.ptr, millis, buf, buflen, C_NULL, err)
    U_FAILURE(err[1]) && error("failed to format time")
    UTF16String(buf[1:len+1])
end

parse(df::ICUDateFormat, s::AbstractString) = parse(df, utf16(s))
function parse(df::ICUDateFormat, s16::UTF16String)
    err = UErrorCode[0]
    ret = ccall((_udat_parse, iculibi18n), Float64,
                (Ptr{Void}, Ptr{UChar}, Int32, Ptr{Int32}, Ptr{UErrorCode}),
                df.ptr, s16.data, length(s16.data)-1, C_NULL, err)
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
