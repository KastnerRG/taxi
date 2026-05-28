# SPDX-License-Identifier: CERN-OHL-S-2.0

TOP = test_taxi_axi_crossbar_decerr_write

RTL_DIR = ../../rtl
PRIM_DIR = ../../../prim/rtl

VERILOG_SOURCES = \
	$(RTL_DIR)/taxi_axi_if.sv \
	$(PRIM_DIR)/taxi_penc.sv \
	$(PRIM_DIR)/taxi_arbiter.sv \
	$(RTL_DIR)/taxi_axi_register_wr.sv \
	$(RTL_DIR)/taxi_axi_register_rd.sv \
	$(RTL_DIR)/taxi_axi_crossbar_addr.sv \
	$(RTL_DIR)/taxi_axi_crossbar_wr.sv \
	$(RTL_DIR)/taxi_axi_crossbar_rd.sv \
	$(RTL_DIR)/taxi_axi_crossbar.sv \
	$(TOP).sv

.PHONY: all run clean

all: run

obj_dir/V$(TOP): $(VERILOG_SOURCES)
	verilator --binary --timing --trace-fst -Wno-WIDTH --top-module $(TOP) $(VERILOG_SOURCES)

run: obj_dir/V$(TOP)
	./obj_dir/V$(TOP)

clean:
	rm -rf obj_dir *.fst *.vcd
