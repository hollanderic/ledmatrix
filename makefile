
LOCAL_MAKEFILE:=$(MAKEFILE_LIST)

project-name := $(firstword $(MAKECMDGOALS))
ifneq ($(project-name),)
$(info Project Name= $(project-name))

ifneq ($(strip $(wildcard ./projects/$(project-name).mk)),)
do-nothing := 1
$(MAKECMDGOALS) _all: make-make
	@:
make-make:
	PROJECT=$(project-name) $(MAKE) -f$(LOCAL_MAKEFILE) $(filter-out $(project-name), $(MAKECMDGOALS))

.PHONY: make-make
endif
endif

ifneq ($(do-nothing),)
$(info First make pass ending...)
else

ifneq ($(PROJECT),)

-include projects/$(PROJECT).mk
ifndef PACKAGE
$(error Could not find project or no package is defined)
endif
ifndef DEVICE
$(error Could not find project or no device is defined)
endif
ifndef PINDEF
$(error Could not find project or no pin definition is defined)
endif

-include $(APP)/rules.mk

BUILDDIR:=build-$(PROJECT)
$(info BUILDDIR = $(BUILDDIR))
$(shell mkdir -p $(BUILDDIR))

all:: $(SV_SOURCES) $(BUILDDIR)/$(PROJECT).bin
	$(info Ran default rule)

%.blif: $(SV_SOURCES)
	@echo "Running yosys... Build dir =$(BUILDDIR)   $@  $<"
	@yosys -q -p 'synth_ice40 -top top -blif $@' $<

%.asc: %.blif
	@echo "Running arachne-pnr............"
	arachne-pnr -d $(subst hx,,$(subst lp,,$(DEVICE))) -o $@ -p $(PINDEF) $< -P $(PACKAGE)
	@echo "Ran arachne-pnr................"

%.bin: %.asc
	@echo "Running bin rule"
	@icepack $< $@

%.rpt: %.asc
	@echo "Running rpt rule"
	@icetime -d $(DEVICE) -mtr $@ $<

prog: $(BUILDDIR)/$(PROJECT).bin
	sudo /usr/local/bin/iceprog $<

clean:
	rm -rf $(BUILDDIR)

.PRECIOUS: %.blif %.asc %.rpt

.PHONY: default clean
endif
endif