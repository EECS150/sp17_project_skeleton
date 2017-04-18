start dvi_controller_testbench

add wave dvi_controller_testbench/*
add wave dvi_controller_testbench/dvi_controller/*
add wave dvi_controller_testbench/chrontel_chip/*
add wave dvi_controller_testbench/framebuffer/*
add wave dvi_controller_testbench/dvi_controller/xclk_n_driver/*
add wave dvi_controller_testbench/dvi_controller/xclk_p_driver/*
run 100ms
