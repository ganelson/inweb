# This makefile was automatically written by inweb -makefile
# and is not intended for human editing

INWEBPLATFORM = macos32

INFORM6OS = MACOS

GLULXEOS = OS_UNIX

EXEEXTENSION = 

INTEST = intest/Tangled/intest
INWEB = inweb/Tangled/inweb

CCOPTS = -DPLATFORM_MACOS=1 -mmacosx-version-min=10.4 -arch i386 -isysroot /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk $(CFLAGS)

MANYWARNINGS = -Weverything -Wno-pointer-arith -Wno-unused-macros -Wno-shadow -Wno-cast-align -Wno-variadic-macros -Wno-missing-noreturn -Wno-missing-prototypes -Wno-unused-parameter -Wno-padded -Wno-missing-variable-declarations -Wno-unreachable-code-break -Wno-class-varargs -Wno-format-nonliteral -Wno-cast-qual -Wno-double-promotion -Wno-comma -Wno-strict-prototypes -Wno-extra-semi-stmt -ferror-limit=1000

FEWERWARNINGS = -Wno-implicit-int -Wno-dangling-else -Wno-pointer-sign -Wno-format-extra-args -Wno-tautological-compare -Wno-deprecated-declarations -Wno-logical-op-parentheses -Wno-format -Wno-extra-semi-stmt

