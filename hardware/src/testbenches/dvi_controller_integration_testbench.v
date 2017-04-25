`timescale 1ns/1ps

/* ---------------
 * EECS151 FPGA Lab Spring 2017
 * Simple test of Chrontel controller and I2C control scheme
 * Uses I2C slave model and Chrontel codec model
 *
 * I2C model displays acknowledgements of packet receipts in the transcript.
 * Chrontel model displays timing errors in the transcript
 * Functionality can also be confirmed visually in ModelSim 
 * Add more tests as necessary
 * See below for timing. One frame should take 16.7 ms to complete
 * ---------------
 */
module dvi_controller_integration_testbench ();
    parameter SYSTEM_CLK_PERIOD = 10;
    parameter SYSTEM_CLK_FREQ = 100_000_000;    

    reg system_clock = 0;
    reg system_reset = 0;

    always #(SYSTEM_CLK_PERIOD/2) system_clock <= ~system_clock;
    
    // I2C interface
    wire scl, sda;
    
    // Chrontel DVI chip interface
    wire [11:0] dvi_data;
    wire dvi_de, dvi_h, dvi_v, dvi_reset_b, dvi_xclk_n, dvi_xclk_p;
	
	ml505top # (
        .SYSTEM_CLOCK_FREQ(SYSTEM_CLK_FREQ),
        .B_SAMPLE_COUNT_MAX(1),
        .B_PULSE_COUNT_MAX(1),
        .R_SAMPLE_COUNT_MAX(1),
        .R_PULSE_COUNT_MAX(1)
    ) top (
        .USER_CLK(system_clock),

        .GPIO_DIP(8'd0),
        .FPGA_ROTARY_INCA(1'b0),
        .FPGA_ROTARY_INCB(1'b0),
        .FPGA_ROTARY_PUSH(1'b0),
        .GPIO_BUTTONS(5'd0),
        .FPGA_CPU_RESET_B(~system_reset),

        .PIEZO_SPEAKER(),
        .GPIO_LED(),
        .GPIO_LED_C(),
        .GPIO_LED_N(),
        .GPIO_LED_E(), 
        .GPIO_LED_W(),
        .GPIO_LED_S(),

        // AC97 Protocol Signals
        .AUDIO_BIT_CLK(),
        .AUDIO_SDATA_IN(),
        .AUDIO_SDATA_OUT(),
        .AUDIO_SYNC(),
        .FLASH_AUDIO_RESET_B(),

        // UART connections
        .FPGA_SERIAL_RX(1'b1),
        .FPGA_SERIAL_TX(),
        
        //I2C
        .IIC_SDA_VIDEO(sda),
        .IIC_SCL_VIDEO(scl),

        //Chrontel
        .DVI_D(dvi_data),
        .DVI_DE(dvi_de),
        .DVI_H(dvi_h),
        .DVI_V(dvi_v),
        .DVI_RESET_B(dvi_reset_b),
        .DVI_XCLK_N(dvi_xclk_n),
        .DVI_XCLK_P(dvi_xclk_p)
    );
    
	i2c_slave_model i2c_slave (
		.scl(scl),
		.sda(sda)
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
	
	initial begin
	    system_reset = 1'b1;
	    repeat (30) @(posedge system_clock);
	    system_reset = 1'b0;

        // Let 1 video frame elapse
        repeat (1344 * 806) @(posedge dvi_xclk_p);
        
        // Some extra time
        repeat (1000) @(posedge dvi_xclk_p);

		$finish();
	end
endmodule
