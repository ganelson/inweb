# This makefile was automatically written by inweb -makefile
# and is not intended for human editing

INWEBPLATFORM = windows

INFORM6OS = PC_WIN32

EXEEXTENSION = .exe

INTEST = intest/Tangled/intest
INWEB = inweb/Tangled/inweb

CCOPTS = -DPLATFORM_WINDOWS=1 $(CFLAGS)

MANYWARNINGS = -Weverything -Wno-unknown-warning-option -Wno-pointer-arith -Wno-unused-macros -Wno-shadow -Wno-cast-align -Wno-variadic-macros -Wno-missing-noreturn -Wno-missing-prototypes -Wno-unused-parameter -Wno-padded -Wno-missing-variable-declarations -Wno-unreachable-code-break -Wno-class-varargs -Wno-format-nonliteral -Wno-cast-qual -Wno-double-promotion -Wno-comma -Wno-strict-prototypes -Wno-extra-semi-stmt -Wno-unreachable-code-return -Wno-unused-but-set-variable -Wno-declaration-after-statement -Wno-used-but-marked-unused -Wno-unsafe-buffer-usage -Wno-misleading-indentation -Wno-implicit-fallthrough -Wno-implicit-int-float-conversion -Wno-incompatible-function-pointer-types-strict -Wno-cast-function-type-strict -Wno-c99-compat -Wno-switch-default -Wno-pre-c11-compat -ferror-limit=1000

FEWERWARNINGS = -Wno-implicit-int -Wno-dangling-else -Wno-pointer-sign -Wno-format-extra-args -Wno-tautological-compare -Wno-deprecated-declarations -Wno-logical-op-parentheses -Wno-format -Wno-extra-semi-stmt -Wno-c11-extensions -Wno-unreachable-code-return

