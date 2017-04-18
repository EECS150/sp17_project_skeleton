start i2c_integration_testbench
file copy -force ../../../software/i2c_integration_tb/i2c_integration_tb.mif imem_blk_ram.mif
file copy -force ../../../software/i2c_integration_tb/i2c_integration_tb.mif dmem_blk_ram.mif
file copy -force ../../../software/i2c_integration_tb/i2c_integration_tb.mif bios_mem.mif
add wave i2c_integration_testbench/*
add wave i2c_integration_testbench/top/*
add wave i2c_integration_testbench/top/i2c_master/*
add wave i2c_integration_testbench/i2c_slave/*
run 4ms
