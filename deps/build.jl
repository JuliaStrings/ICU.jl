using BinDeps

@BinDeps.setup

icu = library_dependency("icu", aliases=["libicuuc","libicucore","icuuc"])
icui18n = library_dependency("icui18n",  aliases=["libicui18n","libicucore","icuin"])

@windows_only begin
    using WinRPM
    provides(WinRPM.RPM, "icu", [icu,icui18n] ,os=:Windows)
end
provides(AptGet, "libicu48", [icu, icui18n])
provides(Yum, "icu", [icu, icui18n])

@BinDeps.install [:icu => :iculib, :icui18n => :iculibi18n]
