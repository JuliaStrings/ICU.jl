using Base.Test
using ICU

noel1 = UnicodeText("noe\u0308l")
noel2 = UnicodeText("noël")
@test noel1 == noel2
@test length(noel1) == length(noel2) == 4
@test noel1[1:3] == "noe\u0308"
@test noel1[3] == "e\u0308"

set_locale("de")
@test UnicodeText("Köpfe") < UnicodeText("Kypper")
@test uppercase("testingß") == "TESTINGSS"
@test uppercase(UnicodeText("testingß")) == "TESTINGSS"
set_locale("sv")
@test UnicodeText("Kypper") < UnicodeText("Köpfe")
set_locale("tr")
@test uppercase("testingß") == "TESTİNGSS"
@test uppercase(UnicodeText("testingß")) == "TESTİNGSS"

