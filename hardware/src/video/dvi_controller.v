`include "util.vh"

/* ---------------
 * EECS151 FPGA Lab Spring 2017
 * Chrontel Chip DVI Controller 
 *
 * See below for timing. One frame should take 16.7 ms to complete
 * ---------------
 */
 /*
To get parameter configurations for various resolutions, refer to this website: tinyvga.com/vga-timing
Parameters for XGA 1024x768 @ 60 Hz refresh rate
    Pixel Clock: 65.0 Mhz
    Horizontal Timing: (Whole line = 1344 pixels)
        Visible area: 1024 pixels
        Front porch: 24 pixels
        Sync pulse: 136 pixels
        Back porch: 160 pixels
    Vertical Timing: (Whole frame = 806 lines)
        Visible area: 768 lines
        Front porch: 3 lines
        Sync pulse: 6 lines
        Back porch: 29 lines
*/

module dvi_controller # (
    parameter hori_front_porch = 24,
    parameter hori_sync_pulse = 136,
    parameter hori_back_porch = 160,
    parameter hori_visible_area = 1024,
    parameter hori_whole_line = hori_front_porch + hori_sync_pulse + hori_back_porch + hori_visible_area,

    parameter vert_front_porch = 3,
    parameter vert_sync_pulse = 6,
    parameter vert_back_porch = 29,
    parameter vert_visible_area = 768,
    parameter vert_whole_frame = vert_front_porch + vert_sync_pulse + vert_back_porch + vert_visible_area,
   
    parameter refresh_rate = 60,
    parameter xclk_frequency = hori_whole_line * vert_whole_frame * refresh_rate,
   
    parameter sync_polarity = 0,     // sync_polarity == 0 means active-low HSYNC/VSYNC, == 1 means active-high

    parameter RAM_width = 1,
    parameter RAM_depth = 786432,
    parameter RAM_depth_bits = `log2(RAM_depth)
)(
	input				clk,			// This is the pixel clock @ 65 Mhz for 1024 x 768 resolution
    input               rst,            // This is a reset synchronized to the pixel clock

	// Framebuffer Interface
	output	[RAM_depth_bits - 1 :0]		framebuffer_addr,
	input 	[RAM_width-1:0]				framebuffer_data,

    // Chrontel DVI Chip Interface
	output [11:0]		dvi_data,		// Data Inputs 
	output 				dvi_de,			// Data Enable (shoule be high when video data is active)
	output 				dvi_h,			// Horizontal Sync
	output 				dvi_v,			// Vertical Sync
	output 				dvi_reset_b,	// Active-low power-on reset (when high, reset controller over I2C)
	output 				dvi_xclk_n,		// Differential external clock, synchronous wrt DE, H, V, data[11:0]
	output 				dvi_xclk_p

);
    //// Resets
    // Don't reset the Chrontel chip using the 'rst' signal, we will use I2C software reset instead   
    // Don't modify this section.
    reg dvi_reset_b_iob /* synthesis iob="true" */;
	assign dvi_reset_b = dvi_reset_b_iob;
    always @ (posedge clk) begin
       dvi_reset_b_iob <= 1'b1;
    end

    //// Clock forwarding
    // We use dedicated ODDR (output double data rate) registers to drive
    // dvi_xclk_n and dvi_xclk_p from the pixel clk
    // Don't modify this section.
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE")
    ) xclk_n_driver (
        .Q(dvi_xclk_n),
        .C(clk),
        .CE(1'b1),
        .D1(1'b0),  // on posedge clk, xclk_n will be driven to 0
        .D2(1'b1),  // on negedge clk, xclk_n will be driven to 1 (i.e. 180 degree phase shift)
        .R(1'b0),
        .S(1'b0)
    );

    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE")
    ) xclk_p_driver (
        .Q(dvi_xclk_p),
        .C(clk),
        .CE(1'b1),
        .D1(1'b1),  // on posedge clk, xclk_p will be driven to 1
        .D2(1'b0),  // on negedge clk, xclk_p will be driven to 0 (exact same clock, no phase shift)
        .R(1'b0),
        .S(1'b0)
    );

    //// IOB (input/output block) Packing for DE, V, H
    // You can modify this block to set these IOBs on the posedge or negedge
    // of the 'clk', but you shouldn't have to modify this section.
    reg dvi_de_iob, dvi_v_iob, dvi_h_iob /* synthesis iob="true" */;
    initial dvi_de_iob = 1'b0;
    initial dvi_v_iob = 1'b1;
    initial dvi_h_iob = 1'b1;
    wire dvi_de_logic, dvi_v_logic, dvi_h_logic; // These signals are assigned in your design
    assign dvi_de = dvi_de_iob;
    assign dvi_v = dvi_v_iob;
    assign dvi_h = dvi_h_iob;
    always @ (posedge clk) begin
        dvi_v_iob <= dvi_v_logic;
        dvi_h_iob <= dvi_h_logic;
        dvi_de_iob <= dvi_de_logic;
    end

    //// Data DDR forwarding via ODDR for dvi_data
    // Don't modify this section. Assign dvi_data_a_logic and dvi_data_b_logic
    // to match the P0a and P0b data shown on the timing diagram of the
    // Chrontel chip datasheet.
    reg [11:0] dvi_data_a_logic; // These signals are assigned in your design
    reg [11:0] dvi_data_b_logic;
    genvar i;
    generate
        for (i = 0; i < 12; i = i + 1) begin : dvi_buff
            ODDR #(
                .DDR_CLK_EDGE("SAME_EDGE") // on posedge clk, both D1 and D2 will be sampled
            ) dvi_data_driver (
                .Q(dvi_data[i]),
                .C(clk),
                .CE(1'b1),
                .D1(dvi_data_b_logic[i]),   // at posedge clk, dvi_data will be driven by dvi_data_b_logic 
                .D2(dvi_data_a_logic[i]),   // at negedge clk, dvi_data will be driven by dvi_data_a_logic
                                            // that was sampled at the earlier posedge
                .R(1'b0),
                .S(1'b0)
            );
        end
    endgenerate

    
    //// YOUR DVI CONTROLLER GOES HERE
    //
    // You can assign dvi_de_logic, dvi_v_logic, dvi_h_logic, 
    // dvi_data_a_logic [11:0], dvi_data_b_logic [11:0] and framebuffer_addr [19:0].
    //
    // You can change the listed signals above to be regs or wires if needed.
    //
    // You CAN ONLY use the 'clk' input to drive synchronous logic.
	assign dvi_de_logic = 1'b0;
    assign dvi_v_logic = 1'b1;
    assign dvi_h_logic = 1'b1;
    always @ (posedge clk) begin
        dvi_data_a_logic <= 0;
        dvi_data_b_logic <= 0;
    end
    assign framebuffer_addr = 0;
endmodule
