# Makefile: VCS + Verdi for lfsr_rng + tb_lfsr_rng 

SHELL      := /bin/bash

#Tools
VCS        ?= vcs
VERDI      ?= verdi

#change names based on file
TOP        := test_qrs.sv
SRC        := QRS.sv R-Peak.sv CLT.sv test_qrs.sv

#Output
OUTDIR     := simv_out
SIMV       := $(OUTDIR)/simv
CLOG       := $(OUTDIR)/compile.log
RLOG       := $(OUTDIR)/run.log

#FSDB output
FSDB       := $(OUTDIR)/novas.fsdb

TIMESCALE  := 1ns/1ps

VCS_CFLAGS := -full64 -sverilog -timescale=$(TIMESCALE) \
              -debug_access+all -kdb \
              +lint=TFIPC-L \
              -o $(SIMV)

#Always enble FSDB dumping in TB
DUMP_DEFS  := +define+DUMP_FSDB +define+FSDB_FILE=\"$(FSDB)\"
# Targets
.PHONY: all build run gui clean help

all: run

$(OUTDIR):
	@mkdir -p $(OUTDIR)

build: $(OUTDIR)
	@$(VCS) $(VCS_CFLAGS) $(DUMP_DEFS) $(SRC) |& tee $(CLOG)

run: build
	@echo "Running simulation"
	@cd $(OUTDIR) && ./simv |& tee run.log
	@echo "Finished"

gui:
	@if [ ! -f "$(FSDB)" ]; then \
	  echo "[GUI] ERROR: $(FSDB) not found. Run 'make run' first."; \
	  exit 1; \
	fi
	@echo "Lauching verdi"
	@$(VERDI) -full64 -sv $(SRC) -top $(TOP) -ssf $(FSDB) &

clean:
	@echo "Removing artifacts..."
	@rm -rf $(OUTDIR) simv simv.daidir csrc ucli.key *.vpd *.vcd *.fsdb *.log *.key
