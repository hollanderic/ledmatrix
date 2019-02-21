PROJ = ledz
PIN_DEF = icestick.pcf
DEVICE = hx1k


PROJ:= $(firstword $(MAKECMDGOALS))
BUILDDIR:=build-$(PROJ)
$(info BUILDDIR = $(BUILDDIR))
#mkdir -p $(BUILDDIR)



#$(PROJ).bin

%.blif: %.v
	@echo "Build dir =$(BUILDDIR)"
	yosys -p 'synth_ice40 -top top -blif $(BUILDDIR)/$@' $<

%.asc: $(PIN_DEF) %.blif
	arachne-pnr -d $(subst hx,,$(subst lp,,$(DEVICE))) -o $(BUILDDIR)/$@ -p $(PIN_DEF) $(BUILDDIR) -P tq144

%.bin: %.asc
	icepack $(BUILDDIR)/$< $(BUILDDIR)/$@

%.rpt: %.asc
	icetime -d $(DEVICE) -mtr $(BUILDDIR)/$@ $(BUILDDIR)/$<

prog: $(PROJ).bin
	sudo iceprog $<

sudo-prog: $(PROJ).bin
	@echo 'Executing prog as root!!!'
	sudo iceprog $<

$(BUILDDIR):
	mkdir -p $(BUILDDIR)

clean:
	rm -f $(BUILDDIR)/*
#	rm -f $(PROJ).blif $(PROJ).asc $(PROJ).bin $(PROJ).rpt

$(PROJ): $(BUILDDIR) $(PROJ).rpt


.PHONY: all prog clean