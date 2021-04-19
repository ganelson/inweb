# This is make-intools-settings.mk for Windows.
# To use, you will need to install Cygwin with the Mingw-w64 clang compiler.

INTEST = intest/Tangled/intest
INWEB = inweb/Tangled/inweb

# Use the MinGW x64 clang compiler
CC = x86_64-w64-mingw32-clang -std=c99 -c $(MANYWARNINGS) $(CCOPTS) 
INDULGENTCC = x86_64-w64-mingw32-clang -std=c99 -c $(FEWERWARNINGS) $(CCOPTS)

# Define the Windows platform preprocessor symbol
CCOPTS = -DPLATFORM_WINDOWS=1 -D_WIN32_WINNT=0x0600
MANYWARNINGS = -Weverything -Wno-pointer-arith -Wno-unused-macros -Wno-shadow -Wno-cast-align -Wno-variadic-macros -Wno-missing-noreturn -Wno-missing-prototypes -Wno-unused-parameter -Wno-padded -Wno-missing-variable-declarations -Wno-unreachable-code-break -Wno-class-varargs -Wno-format-nonliteral -Wno-cast-qual -Wno-double-promotion -Wno-comma -Wno-strict-prototypes -Wno-extra-semi-stmt -Wno-used-but-marked-unused -ferror-limit=1000
FEWERWARNINGS = -Wno-implicit-int -Wno-dangling-else -Wno-pointer-sign -Wno-format-extra-args -Wno-tautological-compare -Wno-deprecated-declarations -Wno-logical-op-parentheses -Wno-format -Wno-extra-semi-stmt

LINK = x86_64-w64-mingw32-clang $(CCOPTS)
LINKEROPTS = -lshlwapi

# Set the standard Windows executable file extension
EXEEXTENSION = .exe
ARTOOL = ar -r

INFORM6OS = PC_WIN32
GLULXEOS = OS_WIN32

