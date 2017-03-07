`include "util.vh"

module ac97_controller #(
    parameter SYS_CLK_FREQ = 50_000_000
) (
    // AC97 Protocol Signals
    input sdata_in,           // Serial line from the codec (not used in this lab)
    input bit_clk,            // Bit clock from the codec (used for all logic in this module except reset)
    input [19:0] sample_fifo_tone_data,
    input sample_fifo_empty,
    output sample_fifo_rd_en,
    output sdata_out,         // Serial line to the codec
    output sync,              // Sync signal to the codec
    output reset_b,           // Active low reset (reset bar) to the codec
    input [3:0] volume_control,  // This input is tied to GPIO switches 3, 4, 5, 6    
    
    input system_clock,       // Clock used for resetting codec
    input system_reset       // Reset signal coming from the CPU_RESET button
                              // you will need to generate the reset signal for the codec in this controller
                              // (This reset signal should trigger the codec reset)

);
    assign sdata_out = 1'b0;
    assign sync = 1'b0;
    assign sample_fifo_rd_en = 1'b0;
    assign reset_b = 1'b1;
endmodule
