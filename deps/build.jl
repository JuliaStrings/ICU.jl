using BinDeps

using Compat

include("versions.jl")

@BinDeps.setup

icu_aliases = ["libicuuc"]
i18n_aliases = ["libicui18n"]
@osx_only begin
    icu_aliases = ["libicucore"]
    i18n_aliases = ["libicucore"]
end
@windows_only begin
    icu_aliases = ["icuuc$v" for v in versions]
    i18n_aliases = [["icui18n$v" for v in versions];
                    ["icuin$v" for v in versions]]
end
icu = library_dependency("icu", aliases=icu_aliases)
icui18n = library_dependency("icui18n", aliases=i18n_aliases)

@windows_only begin
    using WinRPM
    provides(WinRPM.RPM, "icu", [icu,icui18n], os=:Windows)
end
provides(AptGet, @compat Dict(["libicu$v" => [icu,icui18n] for v in apt_versions]))
provides(Yum, "icu", [icu, icui18n])

@BinDeps.install @compat Dict(:icu => :iculib, :icui18n => :iculibi18n)
