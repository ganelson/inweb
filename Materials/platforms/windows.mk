# This makefile was automatically written by inweb make-makefile
# and is not intended for human editing

INWEBPLATFORM = windows

INFORM6OS = PC_WIN32

EXEEXTENSION = .exe

INTEST = intest/Tangled/intest
INWEB = inweb/Tangled/inweb

CCOPTS = -DPLATFORM_WINDOWS=1 $(CFLAGS)

MANYWARNINGS = -Wno-deprecated-non-prototype -ferror-limit=1000

FEWERWARNINGS = -Wno-implicit-int -Wno-dangling-else -Wno-pointer-sign -Wno-format-extra-args -Wno-tautological-compare -Wno-deprecated-declarations -Wno-logical-op-parentheses -Wno-format -Wno-extra-semi-stmt -Wno-c11-extensions -Wno-unreachable-code-return

