# This makefile was automatically written by inweb -makefile
# and is not intended for human editing

INWEBPLATFORM = unix

INFORM6OS = LINUX

EXEEXTENSION = 

INTEST = intest/Tangled/intest
INWEB = inweb/Tangled/inweb

CCOPTS = -Wno-unused -DPLATFORM_UNIX -DUNIX64 -DCPU_WORDSIZE_MULTIPLIER=2 -O2

MANYWARNINGS = -Weverything -Wno-unknown-warning-option -Wno-pointer-arith -Wno-unused-macros -Wno-shadow -Wno-cast-align -Wno-variadic-macros -Wno-missing-noreturn -Wno-missing-prototypes -Wno-unused-parameter -Wno-padded -Wno-missing-variable-declarations -Wno-unreachable-code-break -Wno-class-varargs -Wno-format-nonliteral -Wno-cast-qual -Wno-double-promotion -Wno-comma -Wno-strict-prototypes -Wno-extra-semi-stmt -Wno-c11-extensions -Wno-unreachable-code-return -Wno-unused-but-set-variable -Wno-declaration-after-statement -ferror-limit=1000

FEWERWARNINGS = -Wno-implicit-int -Wno-dangling-else -Wno-pointer-sign -Wno-format-extra-args -Wno-tautological-compare -Wno-deprecated-declarations -Wno-logical-op-parentheses -Wno-format -Wno-extra-semi-stmt -Wno-c11-extensions -Wno-unreachable-code-return

