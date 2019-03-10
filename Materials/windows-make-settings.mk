# Make settings for integrating Inform's user interface and core software.
# This is the Windows version, by David Kinder. To use, you will need
# Cygwin with the Mingw-w64 GCC compiler installed.

INTEST = intest/Tangled/intest
INWEB = inweb/Tangled/inweb

BUILTINCOMPS = ../Build/Compilers
INTERNAL = ../Build/Internal
BUILTINHTML = ../Build/Documentation
BUILTINHTMLINNER = ../Build/Documentation/sections

I6COMPILERNAME = inform6.exe

INDOCOPTS = windows_app
INRTPSOPTS = -nofont
INTESTOPTS = -threads=2 -no-colours

GCC = i686-w64-mingw32-gcc
GCCOPTS = -DPLATFORM_WINDOWS -I.
GCCWARNINGS = -Wno-pointer-arith -Wno-unused-macros -Wno-shadow -Wno-cast-align -Wno-variadic-macros -Wno-missing-noreturn -Wno-missing-prototypes -Wno-unused-parameter -Wno-padded -Wno-missing-variable-declarations -Wno-unreachable-code-break -Wno-class-varargs -Wno-format-nonliteral -Wno-cast-qual
CBLORBWARNINGS = -Wno-format-nonliteral
LINK = $(GCC) $(GCCOPTS) -g
LINKEROPTS = -Wl,--large-address-aware
ARTOOL = ar -r

GLULXEOS = OS_WIN32
INFORM6OS = PC_WIN32

