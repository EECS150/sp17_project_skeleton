`timescale 1ns/100ps

`define SECOND 1000000000
`define MS 1000000

// This testbench runs a program on your CPU which transmits samples to the AC97 sample FIFO.
// The program transmits the PCM samples -50, -49, -48, ..., 0, 1, 2, ..., 48, 49, 50.
// You should inspect the waveform and verify that the AC97 codec model receives each sample in order by inspecting Slot 3 and Slot 4.
module ac97_integration_testbench();
    parameter SYSTEM_CLK_PERIOD = 20;
    parameter SYSTEM_CLK_FREQ = 50_000_000;    

    reg sys_clk = 0;
    reg sys_rst = 0;

    // AC97 Signals
    wire bit_clk, sdata_out, sdata_in, reset_b, sync;

    // AC97 Sample FIFO Signals
    wire ac97_fifo_wr_en, ac97_fifo_rd_en, ac97_fifo_empty, ac97_fifo_full;
    wire [19:0] ac97_fifo_din, ac97_fifo_dout;

    always #(SYSTEM_CLK_PERIOD/2) sys_clk <= ~sys_clk;

    // In this testbench, we instantiate the RISCV CPU, an async FIFO, the AC97 controller, and the AC97 codec model

    // You may have to change the port list on your CPU depending on whether you instantiated the AC97 controller/FIFO
    // in the CPU itself or in ml505top.
    Riscv151 #(
        .CPU_CLOCK_FREQ(SYSTEM_CLK_FREQ)
    ) CPU(
        .clk(sys_clk),
        .rst(sys_rst),
        .AC97_val(ac97_fifo_wr_en),
        .AC97_data(ac97_fifo_din),
        .AC97_full(ac97_fifo_full)
    );

    // Your async FIFO with the write interface exposed to the CPU and read interface exposed to the AC97 controller
    async_fifo #(
        .data_width(20),
        .fifo_depth(8)
    ) ac97_fifo (
        .wr_clk(sys_clk),
        .rd_clk(bit_clk),
        .wr_en(ac97_fifo_wr_en),
        .rd_en(ac97_fifo_rd_en),
        .din(ac97_fifo_din),
        .full(ac97_fifo_full),
        .empty(ac97_fifo_empty),
        .dout(ac97_fifo_dout)
    );

    // The AC97 controller is hooked to the read side of the async FIFO 
    ac97_controller #(
        .SYS_CLK_FREQ(SYSTEM_CLK_FREQ)
    ) audio_controller (
        .sdata_in(sdata_in),
        .sdata_out(sdata_out),
        .bit_clk(bit_clk),
        .sample_fifo_tone_data(ac97_fifo_dout),
        .sample_fifo_empty(ac97_fifo_empty),
        .sample_fifo_rd_en(ac97_fifo_rd_en),
        .sync(sync),
        .reset_b(reset_b),
        .volume_control(4'b0),  // Change this to connect to the memory mapped register coming from your CPU
        .system_clock(sys_clk),
        .system_reset(sys_rst)
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
        repeat (10) @(posedge sys_clk);
        sys_rst <= 1'b0;

        // Wait until the codec receives the PCM sample 50
        while (codec_model.slot_3 !== 50) @(posedge sys_clk);

        // Wait for a few more frames to see that PCM sample 50 is being transmitted even after the FIFO is empty
        repeat(256 * 10) @(posedge bit_clk);

        // Inspect the waveform to see that all the PCM samples were sent and that the FIFO is empty!!
        $finish();
    end

endmodule
