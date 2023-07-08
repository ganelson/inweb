# This makefile was automatically written by inweb -makefile
# and is not intended for human editing

INWEBPLATFORM = linux

INFORM6OS = LINUX

EXEEXTENSION =

INTEST = intest/Tangled/intest
INWEB = inweb/Tangled/inweb

CCOPTS = -D_POSIX_C_SOURCE=200112L -D_DEFAULT_SOURCE -DPLATFORM_LINUX \
	-fdiagnostics-color=auto $(CFLAGS)

MANYWARNINGS = -Wall -Wextra -Wimplicit-fallthrough=2 -Wno-pointer-to-int-cast \
    -Wno-unknown-pragmas -Wno-unused-but-set-parameter \
    -Wno-unused-but-set-variable -Wno-unused-function -Wno-unused-parameter \
    -Wno-unused-variable -fmax-errors=1000

FEWERWARNINGS = -Wno-implicit-int

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
	$(CC) -std=c11 -c $(MANYWARNINGS) $(CCOPTS) -g  -o $(ME)/Tangled/$(ME).o $(ME)/Tangled/$(ME).c
	$(CC) $(CCOPTS) -o $(ME)/Tangled/$(ME)$(EXEEXTENSION) $(ME)/Tangled/$(ME).o  -lm -pthread $(LDFLAGS)
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

