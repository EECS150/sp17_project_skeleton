start ac97_integration_testbench
file copy -force ../../../software/ac97_integration_tb/ac97_integration_tb.mif imem_blk_ram.mif
file copy -force ../../../software/ac97_integration_tb/ac97_integration_tb.mif dmem_blk_ram.mif
file copy -force ../../../software/ac97_integration_tb/ac97_integration_tb.mif bios_mem.mif
add wave ac97_integration_testbench/*
add wave ac97_integration_testbench/ac97_fifo/*
add wave ac97_integration_testbench/ac97_fifo/buff/*
add wave ac97_integration_testbench/audio_controller/*
add wave ac97_integration_testbench/codec_model/*
add wave ac97_integration_testbench/codec_model/codec_ready
add wave ac97_integration_testbench/codec_model/bit_counter
add wave ac97_integration_testbench/codec_model/slot_1
add wave ac97_integration_testbench/codec_model/slot_2
add wave ac97_integration_testbench/codec_model/slot_3
add wave ac97_integration_testbench/codec_model/slot_4
add wave ac97_integration_testbench/codec_model/sdata_out_shift
add wave ac97_integration_testbench/codec_model/control_regs/*
run 6ms
