# This makefile was automatically written by inweb make-makefile
# and is not intended for human editing

INWEBPLATFORM = macos

INFORM6OS = MACOS

EXEEXTENSION = 

INTEST = intest/Tangled/intest
INWEB = inweb/Tangled/inweb

SDKPATH := $(shell xcrun -show-sdk-path)

CCOPTS = -DPLATFORM_MACOS=1 -target arm64-apple-macos11 -isysroot $(SDKPATH) $(CFLAGS)

MANYWARNINGS = -Weverything -Wno-unknown-warning-option -Wno-pointer-arith -Wno-unused-macros -Wno-shadow -Wno-cast-align -Wno-variadic-macros -Wno-missing-noreturn -Wno-missing-prototypes -Wno-unused-parameter -Wno-padded -Wno-missing-variable-declarations -Wno-unreachable-code-break -Wno-class-varargs -Wno-format-nonliteral -Wno-cast-qual -Wno-double-promotion -Wno-comma -Wno-strict-prototypes -Wno-extra-semi-stmt -Wno-unreachable-code-return -Wno-unused-but-set-variable -Wno-declaration-after-statement -Wno-c99-compat -Wno-pre-c11-compat -Wno-switch-default -Wno-reserved-identifier -ferror-limit=1000

FEWERWARNINGS = -Wno-implicit-int -Wno-dangling-else -Wno-pointer-sign -Wno-format-extra-args -Wno-tautological-compare -Wno-deprecated-declarations -Wno-logical-op-parentheses -Wno-format -Wno-extra-semi-stmt -Wno-c11-extensions -Wno-unreachable-code-return -Wno-unused-but-set-variable

INWEB = /Users/grahamnelson/git/snapshot/inweb/Tangled/inweb
INTEST = /Users/grahamnelson/git/snapshot/intest/Tangled/intest
MYNAME = literate-test
ME = inweb/literate-test

$(ME)/Tangled/$(MYNAME): inweb/literate-test/*.w inweb/foundation-module/Preliminaries/*.w inweb/foundation-module/Chapter*/*.w inweb/literate-module/Preliminaries/*.w inweb/literate-module/Chapter*/*.w inweb/literate-test/Sections/*.w
	$(call make-me)

.PHONY: force
force:
	$(call make-me)

define make-me
	$(INWEB) tangle $(ME)
	clang -std=c11 -c $(MANYWARNINGS) $(CCOPTS) -g  -o $(ME)/Tangled/$(MYNAME).o $(ME)/Tangled/$(MYNAME).c
	clang $(CCOPTS) -g -o $(ME)/Tangled/$(MYNAME)$(EXEEXTENSION) $(ME)/Tangled/$(MYNAME).o 
endef

.PHONY: test
test:
	$(INTEST) -from $(ME) all

.PHONY: pages
pages:
	mkdir -p $(ME)/docs/$(MYNAME)
	$(INWEB) weave $(ME) -as GitHubPages -to $(ME)/docs/$(MYNAME)

.PHONY: clean
clean:
	$(call clean-up)

.PHONY: purge
purge:
	$(call clean-up)
	rm -f $(ME)/Tangled/$(MYNAME)

define clean-up
	rm -f $(ME)/Tangled/*.o
	rm -f $(ME)/Tangled/*.c
	rm -f $(ME)/Tangled/*.h
endef

