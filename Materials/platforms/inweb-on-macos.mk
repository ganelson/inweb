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

ME = inweb
FTEST = $(ME)/foundation-test
LTEST = $(ME)/literate-test
LBUILD = $(ME)/licence-build
SAFETYCOPY = $(ME)/Tangled/inweb_dev

COLONY = $(ME)/colony.inweb

-include $(ME)/platform-settings.mk

.PHONY: all

all: $(ME)/platform-settings.mk $(LBUILD)/Tangled/licence-build $(ME)/Tangled/$(ME) $(FTEST)/Tangled/foundation-test $(LTEST)/Tangled/literate-test

$(LBUILD)/Tangled/licence-build: $(LBUILD)/Contents.w $(LBUILD)/Sections/*.w $(ME)/foundation-module/Contents.w $(ME)/foundation-module/Chapter*/*.w
	$(call make-licence-build)

$(ME)/Tangled/$(ME): $(ME)/Contents.w $(ME)/Chapter*/*.w $(ME)/foundation-module/Contents.w $(ME)/foundation-module/Chapter*/*.w
	$(call make-me)

$(FTEST)/Tangled/foundation-test: $(FTEST)/Contents.w $(FTEST)/Sections/*.w $(ME)/foundation-module/Contents.w $(ME)/foundation-module/Chapter*/*.w
	$(call make-ftest)

$(LTEST)/Tangled/literate-test: $(LTEST)/Contents.w $(LTEST)/Sections/*.w $(ME)/foundation-module/Contents.w $(ME)/foundation-module/Chapter*/*.w $(ME)/literate-module/Contents.w $(ME)/literate-module/Chapter*/*.w
	$(call make-ltest)

.PHONY: force
force: $(ME)/platform-settings.mk
	$(call make-me)
	$(call make-ftest)
	$(call make-ltest)
	$(call make-licence-build)

.PHONY: makers
makers:
	$(INWEB) make-makefile $(FTEST) -to $(FTEST)/foundation-test.mk
	$(INWEB) make-makefile $(LTEST) -to $(LTEST)/literate-test.mk
	$(INWEB) make-makefile $(LBUILD) -to $(LBUILD)/licence-build.mk
	$(INWEB) make-makefile -to $(ME)/Materials/platforms/macos.mk -script $(ME)/Materials/platforms/macos.mkscript
	$(INWEB) make-makefile -to $(ME)/Materials/platforms/inweb-on-macos.mk -platform macos -script $(ME)/scripts/inweb.mkscript
	$(INWEB) make-makefile -to $(ME)/Materials/platforms/macos32.mk -script $(ME)/Materials/platforms/macos32.mkscript
	$(INWEB) make-makefile -to $(ME)/Materials/platforms/inweb-on-macos32.mk -platform macos32 -script $(ME)/scripts/inweb.mkscript
	$(INWEB) make-makefile -to $(ME)/Materials/platforms/macosarm.mk -script $(ME)/Materials/platforms/macosarm.mkscript
	$(INWEB) make-makefile -to $(ME)/Materials/platforms/inweb-on-macosarm.mk -platform macosarm -script $(ME)/scripts/inweb.mkscript
	$(INWEB) make-makefile -to $(ME)/Materials/platforms/macosintel.mk -script $(ME)/Materials/platforms/macosintel.mkscript
	$(INWEB) make-makefile -to $(ME)/Materials/platforms/inweb-on-macosintel.mk -platform macosintel -script $(ME)/scripts/inweb.mkscript
	$(INWEB) make-makefile -to $(ME)/Materials/platforms/macosuniv.mk -script $(ME)/Materials/platforms/macosuniv.mkscript
	$(INWEB) make-makefile -to $(ME)/Materials/platforms/inweb-on-macosuniv.mk -platform macosuniv -script $(ME)/scripts/inweb.mkscript
	$(INWEB) make-makefile -to $(ME)/Materials/platforms/windows.mk -script $(ME)/Materials/platforms/windows.mkscript
	$(INWEB) make-makefile -to $(ME)/Materials/platforms/inweb-on-windows.mk -platform windows -script $(ME)/scripts/inweb.mkscript
	$(INWEB) make-makefile -to $(ME)/Materials/platforms/linux.mk -script $(ME)/Materials/platforms/linux.mkscript
	$(INWEB) make-makefile -to $(ME)/Materials/platforms/inweb-on-linux.mk -platform linux -script $(ME)/scripts/inweb.mkscript
	$(INWEB) make-makefile -to $(ME)/Materials/platforms/unix.mk -script $(ME)/Materials/platforms/unix.mkscript
	$(INWEB) make-makefile -to $(ME)/Materials/platforms/inweb-on-unix.mk -platform unix -script $(ME)/scripts/inweb.mkscript

.PHONY: initial
initial: $(ME)/platform-settings.mk
	$(call make-me-once-tangled)
	$(call make-ftest)
	$(call make-ltest)
	$(call make-licence-build)

.PHONY: safe
safe:
	$(call make-me-using-safety-copy)

.PHONY: licences
licences:
	$(LBUILD)/Tangled/licence-build -from $(ME)/Materials/licenses.json >$(ME)/foundation-module/Chapter\ 7/SPDX\ Licences.w	

define make-me-once-tangled
	clang -std=c11 -c $(MANYWARNINGS) $(CCOPTS) -g  -o $(ME)/Tangled/$(ME).o $(ME)/Tangled/$(ME).c
	clang $(CCOPTS) -g -o $(ME)/Tangled/$(ME)$(EXEEXTENSION) $(ME)/Tangled/$(ME).o 
endef

define make-me
	$(ME)/Tangled/$(ME) tangle $(ME)
	$(call make-me-once-tangled)
endef

define make-me-using-safety-copy
	$(SAFETYCOPY) tangle $(ME)
	$(call make-me-once-tangled)
endef

define make-ftest
	$(INWEB) make-makefile $(FTEST) -to $(FTEST)/foundation-test.mk
	make -f $(FTEST)/foundation-test.mk force
endef

define make-ltest
	$(INWEB) make-makefile $(LTEST) -to $(LTEST)/literate-test.mk
	make -f $(LTEST)/literate-test.mk force
endef

define make-licence-build
	$(INWEB) make-makefile $(LBUILD) -to $(LBUILD)/licence-build.mk
	make -f $(LBUILD)/licence-build.mk force
endef

.PHONY: test
test:
	$(INTEST) -from $(ME) all
	$(INTEST) -from $(FTEST) all
	$(INTEST) -from $(LTEST) all

.PHONY: commit
commit:
	$(INWEB) advance-build $(ME)
	$(INWEB) make-readme $(ME)
	cd $(ME); git commit -a

.PHONY: pages
pages:
	$(INWEB) help > $(ME)/Figures/help.txt
	$(INWEB) inspect -resources > $(ME)/Figures/languages.txt
	$(INWEB) inspect -colony $(COLONY) -member twinprimes -scan > $(ME)/Figures/scan.txt
	$(INWEB) weave -colony $(COLONY) -member twinprimes -as TestingInweb -to $(ME)/Figures/tree.txt
	cp -f $(COLONY) $(ME)/Figures/colony.txt
	$(INWEB) advance-build $(ME)
	mkdir -p $(ME)/docs
	rm -f $(ME)/docs/*.html
	mkdir -p $(ME)/docs/docs-assets
	rm -f $(ME)/docs/docs-assets/*.css
	rm -f $(ME)/docs/docs-assets/*.png
	rm -f $(ME)/docs/docs-assets/*.gif
	cp -f $(ME)/docs-src/Octagram.png $(ME)/docs/docs-assets/Octagram.png
	$(INWEB) make-readme $(ME)
	mkdir -p $(ME)/docs/inweb
	rm -f $(ME)/docs/inweb/*.html
	mkdir -p $(ME)/docs/goldbach
	rm -f $(ME)/docs/goldbach/*.html
	mkdir -p $(ME)/docs/twinprimes
	rm -f $(ME)/docs/twinprimes/*.html
	mkdir -p $(ME)/docs/eastertide
	rm -f $(ME)/docs/eastertide/*.html
	mkdir -p $(ME)/docs/foundation-module
	rm -f $(ME)/docs/foundation-module/*.html
	mkdir -p $(ME)/docs/foundation-test
	rm -f $(ME)/docs/foundation-test/*.html
	$(INWEB) weave -colony $(COLONY) -member overview
	$(INWEB) weave -colony $(COLONY) -member goldbach
	$(INWEB) weave -colony $(COLONY) -member goldbach -as Plain        -to inweb/docs/goldbach/goldbach.txt
	$(INWEB) weave -colony $(COLONY) -member goldbach -as TestingInweb -to inweb/docs/goldbach/goldbach-test.txt
	$(INWEB) weave -colony $(COLONY) -member goldbach -as PDFTeX       -to inweb/docs/goldbach/goldbach.pdf
	$(INWEB) weave -colony $(COLONY) -member goldbach -as TeX          -to inweb/docs/goldbach/goldbach.tex
	$(INWEB) weave -colony $(COLONY) -member twinprimes
	$(INWEB) weave -colony $(COLONY) -member eastertide
	$(INWEB) weave -colony $(COLONY) -member inweb
	$(INWEB) weave -colony $(COLONY) -member foundation
	$(INWEB) weave -colony $(COLONY) -member foundation-test
	$(INWEB) weave -colony $(COLONY) -member literate
	$(INWEB) weave -colony $(COLONY) -member literate-test

.PHONY: clean
clean:
	$(call clean-up)

.PHONY: purge
purge:
	$(call clean-up)

define clean-up
	rm -f $(ME)/Tangled/*.o
	rm -f $(ME)/Tangled/*.h
endef

