`include "util.vh"

/*
 *
 *  Implemenets the basic Bresenham line-drawing algorithm
 *
 *  Currently designed for single color
 *  To modify for multicolor, change the color components and how they are written.
 * 
 *  Refer to the slides here for the equivalent C algorithm:
 *  https://inst.eecs.berkeley.edu/~cs150/fa10/Lab/CP3/LineDrawing.pdf
 */

module accelerator #(
    parameter pixel_width = 1024,
    parameter pixel_height = 768,
    parameter pixel_width_bits = `log2(pixel_width),   //10-bit
    parameter pixel_height_bits = `log2(pixel_height), //10-bit

    parameter mem_width = 1,
    parameter mem_depth = 786432, 
    parameter mem_addr_width = `log2(mem_depth)
)(
    input   clk,
    //no reset

    //Pixel data
    input [pixel_width_bits - 1 : 0] x0,
    input [pixel_height_bits - 1 : 0] y0,
    input [pixel_width_bits - 1 : 0] x1,
    input [pixel_height_bits - 1 : 0] y1,
    input color,
    
    //CPU interface
    output RX_ready,
    input  RX_valid,    //fire signal

    //Arbiter Interface
    output   XL_wr_en,
    output   [mem_width-1:0] XL_wr_data,
    output   [mem_addr_width-1:0] XL_wr_addr  
);
    // Remove these lines when performing implementation
    assign RX_ready = 1'b0;
    assign XL_wr_en = 1'b0;
    assign XL_wr_data = 0;
    assign XL_wr_addr = 0;
endmodule
