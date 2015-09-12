using ICU
using Base.Test

# Tests for not overrunning buffer
str = "\u3b0"
upp = "\u3a5\u308\u301"

@test u_strToUpper(utf16(str^8)) == utf16(upp^8)
