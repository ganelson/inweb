# This makefile was automatically written by inweb make-makefile
# and is not intended for human editing

INWEBPLATFORM = linux

INFORM6OS = LINUX

EXEEXTENSION =

INTEST = intest/Tangled/intest
INWEB = inweb/Tangled/inweb

CC = clang

CCOPTS = -D_POSIX_C_SOURCE=200112L -D_DEFAULT_SOURCE -DPLATFORM_LINUX \
	-fdiagnostics-color=auto $(CFLAGS)

MANYWARNINGS = -Wall -Wextra -Wno-unknown-warning-option \
    -Wno-declaration-after-statement -Wno-deprecated-non-prototype \
    -Wno-unused-but-set-variable -Wno-unused-parameter

FEWERWARNINGS = -Wno-constant-conversion -Wno-dangling-else -Wno-format \
    -Wno-implicit-int -Wno-pointer-sign

