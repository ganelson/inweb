# This makefile was automatically written by inweb -makefile
# and is not intended for human editing

INWEBPLATFORM = linux

INFORM6OS = LINUX

GLULXEOS = OS_UNIX

EXEEXTENSION =

INTEST = intest/Tangled/intest
INWEB = inweb/Tangled/inweb

CCOPTS = -D_POSIX_C_SOURCE=200112L -D_DEFAULT_SOURCE -DPLATFORM_LINUX -fdiagnostics-color=auto -O2

MANYWARNINGS = -Wall -Wextra -Wimplicit-fallthrough=2 -Wno-pointer-to-int-cast \
    -Wno-unknown-pragmas -Wno-unused-but-set-parameter \
    -Wno-unused-but-set-variable -Wno-unused-function -Wno-unused-parameter \
    -Wno-unused-variable -fmax-errors=1000

FEWERWARNINGS = -Wno-implicit-int

