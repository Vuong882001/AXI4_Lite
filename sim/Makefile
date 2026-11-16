# Questa/ModelSim direct RTL simulation flow, adapted from the SPI sim layout.
QUESTA_HOME ?= /home/thanhvuong/questasim
QUESTA_BIN ?= $(QUESTA_HOME)/linux_x86_64
QUESTA_LICENSE ?= $(QUESTA_HOME)/license.dat
TB_NAME ?= tb_axi4_lite_regs
TESTNAME ?= axi4_lite_regs_direct
LIBRARY ?= work

.PHONY: all build compile run run_wave exec_wave clean

all: run

build compile:
	@if [ ! -d $(LIBRARY) ]; then $(QUESTA_BIN)/vlib $(LIBRARY); fi
	$(QUESTA_BIN)/vmap $(LIBRARY) $(LIBRARY)
	$(QUESTA_BIN)/vlog -sv -O0 +acc=rn -work $(LIBRARY) -f compile.f -l compile.log

run: compile
	LM_LICENSE_FILE=$(QUESTA_LICENSE) $(QUESTA_BIN)/vsim -l $(TESTNAME).log \
		-assertdebug -c -lib $(LIBRARY) $(TB_NAME) \
		-do "log -r /*; run -all; quit -f"

run_wave: compile
	LM_LICENSE_FILE=$(QUESTA_LICENSE) $(QUESTA_BIN)/vsim -debugDB \
		-voptargs=+acc -assertdebug -wlf $(TESTNAME).wlf \
		-l $(TESTNAME).log -c -lib $(LIBRARY) $(TB_NAME) \
		-do "log -r /*; run -all; quit -f"

exec_wave:
	LM_LICENSE_FILE=$(QUESTA_LICENSE) $(QUESTA_BIN)/vsim -i -lib $(LIBRARY) $(TB_NAME)

clean:
	rm -rf $(LIBRARY) vsim.dbg *.ini *.log *.wlf transcript
