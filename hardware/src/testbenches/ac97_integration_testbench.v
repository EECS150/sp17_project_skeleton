`timescale 1ns/100ps

`define SECOND 1000000000
`define MS 1000000

// This testbench runs a program on your CPU which transmits samples to the AC97 sample FIFO.
// The program transmits the PCM samples -50, -49, -48, ..., 0, 1, 2, ..., 48, 49, 50.
// You should inspect the waveform and verify that the AC97 codec model receives each sample in order by inspecting Slot 3 and Slot 4.
module ac97_integration_testbench();
    parameter SYSTEM_CLK_PERIOD = 10;
    parameter SYSTEM_CLK_FREQ = 100_000_000;    

    reg sys_clk = 0;
    reg sys_rst = 0;

    // AC97 Signals
    wire bit_clk, sdata_out, sdata_in, reset_b, sync;

    always #(SYSTEM_CLK_PERIOD/2) sys_clk <= ~sys_clk;

    // In this testbench, we instantiate ml505top which should contain your RISCV CPU, an async FIFO, and the AC97 controller
    // We also instantiate the ac97_codec_model in the testbench to check that the expected AC97 frames are transmitted.
        
    ml505top # (
        .SYSTEM_CLOCK_FREQ(SYSTEM_CLK_FREQ),
        .B_SAMPLE_COUNT_MAX(1),
        .B_PULSE_COUNT_MAX(1),
        .R_SAMPLE_COUNT_MAX(1),
        .R_PULSE_COUNT_MAX(1)
    ) top (
        .USER_CLK(sys_clk),

        .GPIO_DIP(8'd0),
        .FPGA_ROTARY_INCA(1'b0),
        .FPGA_ROTARY_INCB(1'b0),
        .FPGA_ROTARY_PUSH(1'b0),
        .GPIO_BUTTONS(5'd0),
        .FPGA_CPU_RESET_B(~sys_rst),

        .PIEZO_SPEAKER(),
        .GPIO_LED(),
        .GPIO_LED_C(),
        .GPIO_LED_N(),
        .GPIO_LED_E(), 
        .GPIO_LED_W(),
        .GPIO_LED_S(),

        // AC97 Protocol Signals
        .AUDIO_BIT_CLK(bit_clk),
        .AUDIO_SDATA_IN(sdata_in),
        .AUDIO_SDATA_OUT(sdata_out),
        .AUDIO_SYNC(sync),
        .FLASH_AUDIO_RESET_B(reset_b),

        // UART connections
        .FPGA_SERIAL_RX(1'b1),
        .FPGA_SERIAL_TX()
    );

    ac97_codec_model codec_model (
        .sdata_out(sdata_out),
        .bit_clk(bit_clk),
        .sdata_in(sdata_in),
        .sync(sync),
        .reset_b(reset_b)
    );

    initial begin
        // Initial reset
        sys_rst <= 1'b1;
        repeat (50) @(posedge sys_clk);
        sys_rst <= 1'b0;

        // Wait until the codec receives the PCM sample 50
        while (codec_model.slot_3 !== 50) @(posedge sys_clk);

        // Wait for a few more frames to see that PCM sample 50 is being transmitted even after the FIFO is empty
        repeat(256 * 10) @(posedge bit_clk);

        // Inspect the waveform to see that all the PCM samples were sent and that the async FIFO is empty!!
        $finish();
    end

endmodule
