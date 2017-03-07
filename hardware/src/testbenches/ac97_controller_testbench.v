`timescale 1ns/100ps

`define SECOND 1000000000
`define MS 1000000
`define BIT_CLK_PERIOD 81.38

module ac97_controller_testbench();
    parameter SYSTEM_CLK_PERIOD = 20;
    parameter SYSTEM_CLK_FREQ = 50_000_000;

    // System clock domain I/O
    reg system_clock = 0;
    reg system_reset = 0;
    //reg square_wave = 0;
    reg wr_en;
    reg signed [19:0] din;
    wire full;
    reg [3:0] volume_control = 0;
    wire sample_fifo_rd_en;
    wire sample_fifo_empty;
    wire [19:0] sample_fifo_tone_data;    
    // Connections between AC97 codec and controller
    wire sdata_out, sync, reset_b, bit_clk;

    // Generate system clock
    always #(SYSTEM_CLK_PERIOD/2) system_clock = ~system_clock;

    ac97_codec_model model (
        .sdata_in(),    // sdata_in isn't used in this testbench
        .sdata_out(sdata_out),
        .sync(sync),
        .reset_b(reset_b),
        .bit_clk(bit_clk)
    );

    ac97_controller #(
        .SYS_CLK_FREQ(SYSTEM_CLK_FREQ)  
    ) DUT (
        .sdata_in(),
        .bit_clk(bit_clk),
        .sdata_out(sdata_out),
        .sync(sync),
        .reset_b(reset_b),
        .system_clock(system_clock),
        .system_reset(system_reset),
        .volume_control(volume_control),
        .sample_fifo_tone_data(sample_fifo_tone_data),
        .sample_fifo_empty(sample_fifo_empty),
        .sample_fifo_rd_en(sample_fifo_rd_en)
    );

    async_fifo # (
        .data_width(20)
    )sample_fifo (
        .wr_clk(system_clock),
        .rd_clk(bit_clk),
        .wr_en(wr_en),
        .rd_en(sample_fifo_rd_en),
        .din(din),
        .full(full),
        .empty(sample_fifo_empty),
        .dout(sample_fifo_tone_data)
    );

    initial begin
        // Pulse the system reset to the ac97 controller
        @(posedge system_clock);
        system_reset = 1'b1;
        @(posedge system_clock);
        system_reset = 1'b0;

        // Push a few packets of data into the AC97 FIFO
        wr_en = 1'd1;
        din = -20'd500000;
        @(posedge system_clock);
        din = -20'd300000;
        @(posedge system_clock);
        din = 20'd0;
        @(posedge system_clock);
        din = 20'd300000;
        @(posedge system_clock);
        din = 20'd500000;
        @(posedge system_clock);
        wr_en = 1'd0;

        // Let 10 AC97 frames pass
        repeat (256 * 10) @(posedge bit_clk);
        
        // Let 1 AC97 frame pass
        repeat (256) @(posedge bit_clk);

        $finish();
    end


endmodule
