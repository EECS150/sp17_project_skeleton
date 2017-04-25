`timescale 1ns/1ps

/* ---------------
 * EECS151 FPGA Lab Spring 2017
 * Simple integration test of the Framebuffer and the Chrontel DVI Chip Controller
 * Uses Chrontel codec model
 *
 * Chrontel model displays timing errors in the transcript
 * Functionality can also be confirmed visually in ModelSim 
 * Add more tests as necessary
 * See below for timing. One frame should take 16.7 ms to complete
 * ---------------
 */

module dvi_controller_testbench ();
	reg rst = 1;

    reg pixel_clock = 1;
	reg cpu_clock = 1;
	localparam PIXEL_CLOCK_PERIOD = 15.385; // 65 MHz clock
	localparam CPU_CLOCK_PERIOD = 20; // 50 Mhz clock

	always #(PIXEL_CLOCK_PERIOD/2) pixel_clock = ~pixel_clock;
    always #(CPU_CLOCK_PERIOD/2) cpu_clock = ~cpu_clock;
    
    // Chrontel DVI chip interface
    wire [11:0] dvi_data;
    wire dvi_de, dvi_h, dvi_v, dvi_reset_b, dvi_xclk_n, dvi_xclk_p;
    
    // Framebuffer interface
    wire [19:0] framebuffer_read_addr;
    wire framebuffer_read_data;
    reg [19:0] framebuffer_write_addr;
    reg framebuffer_write_en, framebuffer_write_data;
    
    dvi_controller #(
        .sync_polarity(0),
        .RAM_width(1),
        .RAM_depth(786432)
    ) dvi_controller (
        .clk(pixel_clock),
        .rst(rst),
        .framebuffer_addr(framebuffer_read_addr),
        .framebuffer_data(framebuffer_read_data),

        .dvi_data		(dvi_data),
        .dvi_de			(dvi_de),
        .dvi_h			(dvi_h),
        .dvi_v			(dvi_v),
        .dvi_reset_b	(dvi_reset_b),
        .dvi_xclk_n		(dvi_xclk_n),
        .dvi_xclk_p		(dvi_xclk_p)
    );
		
	ch7301c_model chrontel_chip (
		.dvi_data(dvi_data),
		.dvi_de(dvi_de),
		.dvi_h(dvi_h),
		.dvi_v(dvi_v),
		.dvi_reset_b(dvi_reset_b),
		.dvi_xclk_n(dvi_xclk_n),
		.dvi_xclk_p(dvi_xclk_p)
	);
	
    frame_buffer_1_786432 framebuffer(
        // Write interface
        .arb_we(framebuffer_write_en),
        .arb_clk(cpu_clock),
        .arb_din(framebuffer_write_data),
        .arb_addr(framebuffer_write_addr),

        // Read interface
        .vga_clk(pixel_clock),
        .vga_dout(framebuffer_read_data),
        .vga_addr(framebuffer_read_addr)
    );
	
	integer x_pixel, y_pixel;
	integer i;
	
	initial begin
        rst = 1'b1;
        repeat (20) @(posedge pixel_clock);
        rst = 1'b0;
        fork
            // Delay thread
            begin
                // Let 2 video frames elapse
                repeat (1344 * 806 * 2) @(posedge dvi_xclk_p);
                // Some extra time
                repeat (1000) @(posedge dvi_xclk_p);
            end
            // Framebuffer write thread
            begin
                // We will draw some simple bars on the screen
                for (y_pixel = 0; y_pixel <= 704; y_pixel = y_pixel + 64) begin
                    for (i = 0; i < 32; i = i + 1) begin
                        for (x_pixel = 0; x_pixel < 1024; x_pixel = x_pixel + 1) begin
                            framebuffer_write_data = 1;
                            framebuffer_write_addr = (y_pixel + i ) * 1024 + x_pixel;
                            framebuffer_write_en = 1;
                            @(posedge cpu_clock);
                        end
                    end
                end
                framebuffer_write_en = 0;
            end
        join

		$finish();
	end
	
endmodule
