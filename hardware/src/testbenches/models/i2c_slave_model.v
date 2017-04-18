`timescale 1ns/100ps

/*
 * This is a behavioral I2C slave model. It is not synthesizable and is to
 * only be used in testbenches. 
 * 
 * This model will always ACK any master command and will always send
 * a predefined byte for any read requests. Any write requests will just be
 * ACK'ed.
 *
 * This model will print out all interaction it has with the master. It will
 * never attempt to stretch the clock..
 */

module i2c_slave_model # (
    parameter read_data = 8'b10100101,  // When a I2C read request is received, it will always be serviced with this data
    parameter i2c_scl_freq = 100_000    // Don't think this is really needed
) (
    input scl,
    inout sda
);

    reg slave_sda_driver = 1'b1;
    reg drive_sda = 1'b0;
    assign sda = drive_sda ? slave_sda_driver : 1'bz;

    // Defined for every I2C transaction
    reg [6:0] slave_address;
    reg r_w;
    reg [7:0] reg_address;

    // Defined for I2C write transactions
    reg [7:0] reg_write_data;

    // Defined for I2C read transactions
    reg [3:0] current_read_data_bit;
    reg master_read_ack;
    
    // For the slave model specifically
    reg transaction_in_progress = 1'b0;
    reg repeated_start_condition = 1'b0;

    initial begin
        slave_sda_driver = 1'b1;
        drive_sda = 1'b0;
        // Receive I2C transactions in an infinite loop
        forever begin
            fork : i2c_transaction_or_repeated_start
                begin : repeated_start_checker
                    forever begin
                        @(negedge sda);
                        if (scl == 1'b1 && transaction_in_progress) begin
                            repeated_start_condition = 1'b1;
                            $display("\tI2C slave model: detected repeated start condition at time: %t", $time);
                            @(negedge scl);
                            disable i2c_transaction;
                            disable repeated_start_checker;
                        end
                    end
                end
                begin : i2c_transaction
                    if (!repeated_start_condition) begin
                        // I2C transactions start with SDA being pulled low, then SCL
                        @(negedge sda);
                        @(negedge scl);
                        transaction_in_progress = 1'b1;
                        $display("I2C slave model: transaction start at time %t", $time);
                    end
                    repeated_start_condition = 1'b0;
                    
                    // The slave receives 7 address bits, then a R/W bit. The SDA line
                    // is stable when SCL is high.
                    repeat (7) begin
                        @(posedge scl);
                        slave_address = {slave_address[5:0], sda};
                    end
                    
                    // R/W bit. 0 = WRITE, 1 = READ
                    @(posedge scl);
                    r_w = sda;

                    // The slave sends an ACK. The master will release the SDA line
                    // when SCL is high. The slave should take control of SDA and
                    // drive it low for the entire time SCL is high.
                    @(negedge scl);
                    slave_sda_driver = 1'b0;
                    drive_sda = 1'b1;  
                    @(negedge scl); 
                    drive_sda = 1'b0;

                    $display("\tI2C slave model: received slave addr: %h, r/w: %b, ACK'ed at time %t", slave_address, r_w, $time);
                    
                    // If we received a read request, send the read_data parameter to
                    // the master, and check that the master ACK'ed the response.
                    if (r_w === 1'b1) begin
                        master_read_ack = 1'b0;
                        @(posedge sda);
                        #10;
                        // Take control of the bus
                        slave_sda_driver = read_data[7];
                        drive_sda = 1'b1;
                        current_read_data_bit = 3'd6;
                        repeat (7) begin
                            @(negedge scl);
                            slave_sda_driver = read_data[current_read_data_bit];
                            current_read_data_bit = current_read_data_bit - 3'd1;
                        end
                        @(negedge scl);
                        drive_sda = 1'b0;
                        @(posedge scl);
                        master_read_ack = sda === 1'b0 ? 1'b1 : 1'b0;

                        $display("\tI2C slave model: sent master the read data: %h, master ACK'ed? %b at time %t", read_data, master_read_ack, $time);
                        if (master_read_ack === 1'b0) begin
                            $display("\tI2C slave model: master didn't ACK the read data, indicating the transaction is about to finish");
                        end
                    end
                    // Otherwise, the master is gong to keep writing to this device, so take in the reg_addr and write_data
                    else begin
                        // The master now sends us the register it wants to access
                        // (8-bits) of data followed by a slave ACK.
                        repeat (8) begin
                            @(posedge scl);
                            reg_address = {reg_address[6:0], sda};
                        end

                        @(negedge scl);
                        slave_sda_driver = 1'b0;
                        drive_sda = 1'b1;
                        @(negedge scl);
                        drive_sda = 1'b0;

                        $display("\tI2C slave model: received reg addr: %h, ACK'ed at time %t", reg_address, $time);
                        
                        // The master will now send the data to be written (write_data) to reg_addr, we will reply with an ACK
                        repeat (8) begin
                            @(posedge scl);
                            reg_write_data = {reg_write_data[6:0], sda};                    
                        end
                        @(negedge scl);
                        slave_sda_driver = 1'b0;
                        drive_sda = 1'b1;
                        @(negedge scl);
                        drive_sda = 1'b0;

                        $display("\tI2C slave model: received reg write data: %h, ACK'ed at time %t", reg_write_data, $time);
                    end

                    // Now the transaction should complete with a STOP condition (i.e.
                    // SDA going high after SCL)
                    @(posedge scl);
                    @(posedge sda);
                    $display("\tI2C slave model: transaction complete as indicated by master at time %t\n", $time);
                    transaction_in_progress = 1'b0;
                    disable repeated_start_checker;
                end
            join
        end
    end

endmodule
