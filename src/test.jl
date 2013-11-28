using Base.Test
using ICU

noel1 = utf16("noe\U0308l")
noel2 = utf16("noël")
@test noel1 == noel2

set_locale("de")
@test utf16("Köpfe") < utf16("Kypper")
@test uppercase("testingß") == "TESTINGSS"
set_locale("sv")
@test utf16("Kypper") < utf16("Köpfe")
set_locale("tr")
@test uppercase("testingß") == "TESTİNGSS"

