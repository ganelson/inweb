# This makefile was automatically written by inweb -makefile
# and is not intended for human editing

INWEBPLATFORM = macosuniv

INFORM6OS = MACOS

GLULXEOS = OS_UNIX

EXEEXTENSION = 

INTEST = intest/Tangled/intest
INWEB = inweb/Tangled/inweb

CCOPTSX = -DPLATFORM_MACOS=1 -target x86_64-apple-macos10.12 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
CCOPTSA = -DPLATFORM_MACOS=1 -target arm64-apple-macos11 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

MANYWARNINGS = -Weverything -Wno-pointer-arith -Wno-unused-macros -Wno-shadow -Wno-cast-align -Wno-variadic-macros -Wno-missing-noreturn -Wno-missing-prototypes -Wno-unused-parameter -Wno-padded -Wno-missing-variable-declarations -Wno-unreachable-code-break -Wno-class-varargs -Wno-format-nonliteral -Wno-cast-qual -Wno-double-promotion -Wno-comma -Wno-strict-prototypes -Wno-extra-semi-stmt -Wno-c11-extensions -Wno-unreachable-code-return -Wno-unused-but-set-variable -ferror-limit=1000

FEWERWARNINGS = -Wno-implicit-int -Wno-dangling-else -Wno-pointer-sign -Wno-format-extra-args -Wno-tautological-compare -Wno-deprecated-declarations -Wno-logical-op-parentheses -Wno-format -Wno-extra-semi-stmt -Wno-c11-extensions -Wno-unreachable-code-return -Wno-unused-but-set-variable

ME = inweb
FTEST = $(ME)/foundation-test
SAFETYCOPY = $(ME)/Tangled/inweb_dev

COLONY = $(ME)/colony.txt

-include $(ME)/platform-settings.mk

.PHONY: all

all: $(ME)/platform-settings.mk $(ME)/Tangled/$(ME) $(FTEST)/Tangled/foundation-test

$(ME)/Tangled/$(ME): $(ME)/Contents.w $(ME)/Chapter*/*.w $(ME)/foundation-module/Contents.w $(ME)/foundation-module/Chapter*/*.w
	$(call make-me)

$(FTEST)/Tangled/foundation-test: $(FTEST)/Contents.w $(FTEST)/Sections/*.w $(ME)/foundation-module/Contents.w $(ME)/foundation-module/Chapter*/*.w
	$(call make-ftest)

.PHONY: force
force: $(ME)/platform-settings.mk
	$(call make-me)
	$(call make-ftest)

.PHONY: makers
makers:
	$(INWEB) $(FTEST) -makefile $(FTEST)/foundation-test.mk
	$(INWEB) -prototype $(ME)/Materials/platforms/macos.mkscript -makefile $(ME)/Materials/platforms/macos.mk
	$(INWEB) -platform macos -prototype $(ME)/scripts/inweb.mkscript -makefile $(ME)/Materials/platforms/inweb-on-macos.mk
	$(INWEB) -prototype $(ME)/Materials/platforms/macos32.mkscript -makefile $(ME)/Materials/platforms/macos32.mk
	$(INWEB) -platform macos32 -prototype $(ME)/scripts/inweb.mkscript -makefile $(ME)/Materials/platforms/inweb-on-macos32.mk
	$(INWEB) -prototype $(ME)/Materials/platforms/macosarm.mkscript -makefile $(ME)/Materials/platforms/macosarm.mk
	$(INWEB) -platform macosarm -prototype $(ME)/scripts/inweb.mkscript -makefile $(ME)/Materials/platforms/inweb-on-macosarm.mk
	$(INWEB) -prototype $(ME)/Materials/platforms/macosuniv.mkscript -makefile $(ME)/Materials/platforms/macosuniv.mk
	$(INWEB) -platform macosuniv -prototype $(ME)/scripts/inweb.mkscript -makefile $(ME)/Materials/platforms/inweb-on-macosuniv.mk
	$(INWEB) -prototype $(ME)/Materials/platforms/windows.mkscript -makefile $(ME)/Materials/platforms/windows.mk
	$(INWEB) -platform windows -prototype $(ME)/scripts/inweb.mkscript -makefile $(ME)/Materials/platforms/inweb-on-windows.mk
	$(INWEB) -prototype $(ME)/Materials/platforms/linux.mkscript -makefile $(ME)/Materials/platforms/linux.mk
	$(INWEB) -platform linux -prototype $(ME)/scripts/inweb.mkscript -makefile $(ME)/Materials/platforms/inweb-on-linux.mk
	$(INWEB) -prototype $(ME)/Materials/platforms/unix.mkscript -makefile $(ME)/Materials/platforms/unix.mk
	$(INWEB) -platform unix -prototype $(ME)/scripts/inweb.mkscript -makefile $(ME)/Materials/platforms/inweb-on-unix.mk

.PHONY: initial
initial: $(ME)/platform-settings.mk
	$(call make-me-once-tangled)
	$(call make-ftest)

.PHONY: safe
safe:
	$(call make-me-using-safety-copy)

define make-me-once-tangled
	clang -std=c11 -c $(MANYWARNINGS) $(CCOPTSX) -g  -o $(ME)/Tangled/$(ME)_x86.o $(ME)/Tangled/$(ME).c
	clang -std=c11 -c $(MANYWARNINGS) $(CCOPTSA) -g  -o $(ME)/Tangled/$(ME)_arm.o $(ME)/Tangled/$(ME).c
	clang $(CCOPTSX) -g -o $(ME)/Tangled/$(ME)$(EXEEXTENSION)_x86 $(ME)/Tangled/$(ME)_x86.o 
	clang $(CCOPTSA) -g -o $(ME)/Tangled/$(ME)$(EXEEXTENSION)_arm $(ME)/Tangled/$(ME)_arm.o 
	lipo -create -output $(ME)/Tangled/$(ME)$(EXEEXTENSION) $(ME)/Tangled/$(ME)$(EXEEXTENSION)_x86 $(ME)/Tangled/$(ME)$(EXEEXTENSION)_arm
endef

define make-me
	$(ME)/Tangled/$(ME) $(ME) -tangle
	$(call make-me-once-tangled)
endef

define make-me-using-safety-copy
	$(SAFETYCOPY) $(ME) -tangle
	$(call make-me-once-tangled)
endef

define make-ftest
	$(INWEB) $(FTEST) -makefile $(FTEST)/foundation-test.mk
	make -f $(FTEST)/foundation-test.mk force
endef

.PHONY: test
test:
	$(INTEST) -from $(ME) all

.PHONY: commit
commit:
	$(INWEB) -advance-build-file $(ME)/build.txt
	$(INWEB) -prototype inweb/scripts/inweb.rmscript -write-me inweb/README.md
	cd $(ME); git commit -a

.PHONY: pages
pages:
	$(INWEB) -help > $(ME)/Figures/help.txt
	$(INWEB) -show-languages > $(ME)/Figures/languages.txt
	$(INWEB) -colony $(COLONY) -member twinprimes -scan > $(ME)/Figures/scan.txt
	$(INWEB) -colony $(COLONY) -member twinprimes -weave-as TestingInweb -weave-to $(ME)/Figures/tree.txt
	cp -f $(COLONY) $(ME)/Figures/colony.txt
	cp -f $(ME)/docs-src/nav.html $(ME)/Figures/nav.txt
	$(INWEB) -advance-build-file $(ME)/build.txt
	mkdir -p $(ME)/docs
	rm -f $(ME)/docs/*.html
	mkdir -p $(ME)/docs/docs-assets
	rm -f $(ME)/docs/docs-assets/*.css
	rm -f $(ME)/docs/docs-assets/*.png
	rm -f $(ME)/docs/docs-assets/*.gif
	cp -f $(ME)/docs-src/Octagram.png $(ME)/docs/docs-assets/Octagram.png
	$(INWEB) -prototype inweb/scripts/inweb.rmscript -write-me inweb/README.md
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
	$(INWEB) -colony $(COLONY) -member overview -weave
	$(INWEB) -colony $(COLONY) -member goldbach -weave
	$(INWEB) -colony $(COLONY) inweb/Examples/goldbach all -weave-as Plain -weave-to inweb/docs/goldbach/goldbach.txt
	$(INWEB) -colony $(COLONY) inweb/Examples/goldbach all -weave-as TestingInweb -weave-to inweb/docs/goldbach/goldbach-test.txt
	$(INWEB) -colony $(COLONY) inweb/Examples/goldbach all -weave-as PDFTeX -weave-to inweb/docs/goldbach/goldbach.pdf
	$(INWEB) -colony $(COLONY) inweb/Examples/goldbach all -weave-as TeX -weave-to inweb/docs/goldbach/goldbach.tex
	$(INWEB) -colony $(COLONY) -member twinprimes -weave
	$(INWEB) -colony $(COLONY) -member eastertide -weave
	$(INWEB) -colony $(COLONY) -member inweb -weave
	$(INWEB) -colony $(COLONY) -member foundation -weave
	$(INWEB) -colony $(COLONY) -member foundation-test -weave

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

