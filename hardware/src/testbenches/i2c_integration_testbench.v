`timescale 1ns/100ps

`define SECOND 1000000000
`define MS 1000000

// This testbench runs a program on your CPU that should cause it to write
// to and read from a I2C slave device using its embedded I2C controller. Use
// this testbench to verify that you have hooked up the provided I2C
// controller with your processor correctly (i.e. the memory map is correct).
module i2c_integration_testbench (); 
    parameter SYSTEM_CLK_PERIOD = 10;
    parameter SYSTEM_CLK_FREQ = 100_000_000;

    reg sys_clk = 0;
    reg sys_rst = 0;

    // I2C Signals
    wire i2c_sda, i2c_scl;

    always #(SYSTEM_CLK_PERIOD/2) sys_clk <= ~sys_clk;

    // In this testbench, we instantiate ml505top which should contain your 
    // RISCV CPU and an I2C controller hooked up over memory mapped I/O.
    //
    // We also instantiate the i2c_slave_model to check that the expected
    // I2C transactions are being performed.
        
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
        .AUDIO_BIT_CLK(),
        .AUDIO_SDATA_IN(),
        .AUDIO_SDATA_OUT(),
        .AUDIO_SYNC(),
        .FLASH_AUDIO_RESET_B(),

        // UART connections
        .FPGA_SERIAL_RX(1'b1),
        .FPGA_SERIAL_TX(),
        
        //I2C
        .IIC_SDA_VIDEO(i2c_sda),
        .IIC_SCL_VIDEO(i2c_scl)
    );

    i2c_slave_model i2c_slave (
        .scl(i2c_scl),
        .sda(i2c_sda)
    );

    initial begin
        // Initial reset
        sys_rst = 1'b1;
        repeat (10) @(posedge sys_clk);
        sys_rst = 1'b0;
        
        #(3 * `MS);

        $finish();
    end

endmodule
