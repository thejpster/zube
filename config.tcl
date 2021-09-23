# User config
set ::env(DESIGN_NAME) zube

# Change if needed
set ::env(VERILOG_FILES) [glob $::env(DESIGN_DIR)/src/*.v]

set ::env(PL_TARGET_DENSITY) 0.60
# set ::env(FP_CORE_UTIL) 40

set ::env(FP_SIZING) absolute
set ::env(DIE_AREA) "0 0 200 200"

set ::env(CLOCK_PERIOD) "10"
set ::env(CLOCK_PORT) "clk"

set filename $::env(DESIGN_DIR)/$::env(PDK)_$::env(STD_CELL_LIBRARY)_config.tcl
if { [file exists $filename] == 1} {
	source $filename
}

