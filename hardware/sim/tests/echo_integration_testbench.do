start echo_integration_testbench 
file copy -force ../../../software/echo/echo.mif imem_blk_ram.mif
file copy -force ../../../software/echo/echo.mif dmem_blk_ram.mif
file copy -force ../../../software/echo/echo.mif bios_mem.mif
add wave echo_integration_testbench/*
add wave echo_integration_testbench/top/*
add wave echo_integration_testbench/off_chip_uart/*
run 10000us
