start dvi_controller_integration_testbench 
file copy -force ../../../software/dvi_controller_testbench/dvi_controller_testbench.mif imem_blk_ram.mif
file copy -force ../../../software/dvi_controller_testbench/dvi_controller_testbench.mif dmem_blk_ram.mif
file copy -force ../../../software/dvi_controller_testbench/dvi_controller_testbench.mif bios_mem.mif
add wave dvi_controller_integration_testbench/*
add wave dvi_controller_integration_testbench/i2c_slave/*
add wave dvi_controller_integration_testbench/chrontel_chip/*
add wave dvi_controller_integration_testbench/top/*
add wave dvi_controller_integration_testbench/top/CPU/*
add wave dvi_controller_integration_testbench/top/framebuffer/*
add wave dvi_controller_integration_testbench/top/video_arbiter/*
add wave dvi_controller_integration_testbench/top/video_ctrl/*
run 17ms
