module i2c_controller
(
  input clk,  // Input clock will be divided for the I2C bus
  input reset,
  input [15:0] i2c_divider,
  input [15:0] i2c_wdata_unreg, // Data to be written to I2C component
  input [15:0] i2c_slave_addr_unreg, // Select which I2C component to address
  input [15:0] i2c_reg_addr_unreg, // Select which register within the i2c component will be
                                   // read or written
  output reg [15:0] i2c_rdata,  // return data read from an I2C devie

  output reg i2c_ctrl_ready, // the I2C controller is ready for a command
  input i2c_ctrl_valid, // the in i2c_wdata, i2c_slave_addr, i2c_reg_addr are valid
                        // and the I2C controller can start the command

  input i2c_rdata_ready,  // The host is ready to receive data from the I2C controller
  output reg i2c_rdata_valid, // The controller has finished reading an I2C component and
                          // the read data is valid for teh host to read

  inout SDA,  // bidirectional bus, instantiated below
  output reg SCL
);

reg [15:0] i2c_slave_addr, i2c_reg_addr, i2c_wdata;
reg [3:0] i2c_repeat_count;
reg [3:0] next_i2c_repeat_count;
wire [3:0] i2c_repeat_target;

reg SDA_buf;
reg SDA_buf_sel;

IOBUF #(
   .DRIVE(4),   // Specify the output drive strength
   .SLEW("SLOW") // Specify the output slew rate
) IOBUF_inst (
   .IO(SDA),
   .O(SDA_out),     // Buffer output 
   .I(SDA_buf),     // Buffer input
   .T(SDA_buf_sel)      // 3-state enable input T=1 is high impedances output, T=0 means O=I
);

  // Generate a slower clock for i2c

  wire [15:0] I2C_CLK_DIVIDE;
  assign I2C_CLK_DIVIDE = i2c_divider;

  reg [9:0] i2c_clk_counter;

  always @(negedge clk) begin
    if (reset) begin
      i2c_clk_counter <= 0;
      SCL <= 1;
    end else begin
      if (i2c_clk_counter == I2C_CLK_DIVIDE) begin
        i2c_clk_counter <= 0;
        SCL <= ~SCL;
      end else begin
        i2c_clk_counter <= i2c_clk_counter + 1;
      end
    end
  end

  wire SDA_transition; wire startstop_transition;
  assign startstop_transition = (i2c_clk_counter == I2C_CLK_DIVIDE/2) && SCL;
  assign SDA_transition = (i2c_clk_counter == I2C_CLK_DIVIDE/2) && ~SCL; // SDA always changes mid-period

  assign i2c_repeat_target = i2c_reg_addr[11:8];

  reg [3:0] i2c_state, i2c_nextstate;
  reg [7:0] i2c_counter, next_i2c_counter; parameter i2c_ack = 8'd8;
  reg i2c_master_ack, next_i2c_master_ack;
  reg i2c_need_ack, next_i2c_need_ack;

  parameter
  I2C_IDLE = 4'd0,
  I2C_START0 = 4'd1,
  I2C_START1 = 4'd2,
  I2C_ADDR = 4'd3,
  I2C_REG = 4'd4,
  I2C_DATA = 4'd5,
  I2C_STOP = 4'd6,
  I2C_READ_START0 = 4'd7,
  I2C_READ_START1 = 4'd8,
  I2C_READ_ADDR = 4'd9,
  I2C_READ_DATA = 4'd10,
  I2C_STOP2 = 4'd11;

  always @* begin
    i2c_nextstate = i2c_state;
    next_i2c_counter = i2c_counter;
    SDA_buf = 1;
    SDA_buf_sel = 0; // Drive output by default
    next_i2c_master_ack = i2c_master_ack;
	 next_i2c_need_ack = 0;
    i2c_rdata_valid = 0;
    i2c_ctrl_ready = 0;
    next_i2c_repeat_count = i2c_repeat_count;

    case(i2c_state)

      I2C_IDLE: begin
        i2c_rdata_valid = 1;
        i2c_ctrl_ready = 1;
        next_i2c_master_ack = 1'b0;
        next_i2c_repeat_count = 0;
        if (i2c_ctrl_valid) begin  // When an address is loaded, start...
          i2c_nextstate = I2C_START0;
        end
      end

      I2C_START0: begin
        if (startstop_transition) begin
          i2c_nextstate = I2C_START1;
        end
      end

      I2C_START1: begin
        SDA_buf = 0;
        if (SDA_transition) begin
          i2c_nextstate = I2C_ADDR;
          next_i2c_counter = 8'd7;
        end
      end

      I2C_READ_START0: begin
        if (startstop_transition) begin
          i2c_nextstate = I2C_READ_START1;
        end
      end

      I2C_READ_START1: begin
        SDA_buf = 0;
        if (SDA_transition) begin
          i2c_nextstate = I2C_READ_ADDR;
          next_i2c_counter = 8'd7;
        end
      end

      I2C_ADDR: begin
        // Always force write (even reads need to write the destination read
        // register)
        if (i2c_counter == 8'd0) begin
          SDA_buf = 1'b0;
        end else begin
          SDA_buf = i2c_slave_addr[i2c_counter];
        end
        if (i2c_counter == i2c_ack) begin
          SDA_buf_sel = 1;
        end
        if (SDA_transition) begin
          if (i2c_counter == 8'd0) begin
            next_i2c_counter = i2c_ack;
          end else if (i2c_counter == i2c_ack) begin
            i2c_nextstate = I2C_REG;
            next_i2c_counter = 8'd7;
          end else begin
            next_i2c_counter = i2c_counter - 8'd1;
          end
        end
      end

      I2C_READ_ADDR: begin
        SDA_buf = i2c_slave_addr[i2c_counter];
        if (i2c_counter == i2c_ack) begin
          SDA_buf_sel = 1;
        end
        if (SDA_transition) begin
          if (i2c_counter == 8'd0) begin
            next_i2c_counter = i2c_ack;
          end else if (i2c_counter == i2c_ack) begin
            i2c_nextstate = I2C_READ_DATA;
            //next_i2c_counter = 8'd7;
            //next_i2c_counter = (i2c_repeat_target<<3)-8'd1;
            next_i2c_counter = {1'b0,i2c_repeat_target,3'b000} - 8'd1;
          end else begin
            next_i2c_counter = i2c_counter - 8'd1;
          end
        end
      end

      I2C_REG: begin
        SDA_buf = i2c_reg_addr[i2c_counter];
        if (i2c_counter == i2c_ack) begin
          SDA_buf_sel = 1;
        end
        if (SDA_transition) begin
          if (i2c_counter == 8'd0) begin
            next_i2c_counter = i2c_ack;
          end else if (i2c_counter == i2c_ack) begin
            // If writing
            if(i2c_slave_addr[0] == 0) begin
              i2c_nextstate = I2C_DATA;
				 next_i2c_counter = {1'b0,i2c_repeat_target,3'b000} - 8'd1;
            // If reading
            end else begin
              i2c_nextstate = I2C_READ_START0;
				 next_i2c_counter = 8'd7;
            end
            
          end else begin
            next_i2c_counter = i2c_counter - 8'd1;
          end
        end
      end

      I2C_DATA: begin
        SDA_buf = i2c_wdata[i2c_counter];
      
		    if (i2c_need_ack) begin
		      next_i2c_need_ack = 1;
			    SDA_buf_sel = 1;
		    end
		 
        if (SDA_transition) begin
          if (i2c_counter == 8'd0) begin
            next_i2c_counter = i2c_ack;
				    next_i2c_repeat_count = i2c_repeat_count + 4'd1;
				    next_i2c_need_ack = 1;
			    end else if (i2c_counter == i2c_ack && i2c_repeat_count[1:0] == i2c_repeat_target[1:0]) begin
            i2c_nextstate = I2C_STOP;
			    end else if (i2c_counter[2:0] == 3'd0) begin
				    if(i2c_need_ack) begin
				      next_i2c_counter = i2c_counter - 8'd1;
				      next_i2c_need_ack = 0;	
				    end else begin
				      next_i2c_repeat_count = i2c_repeat_count + 4'd1;
              next_i2c_need_ack = 1;	
				    end
          end else begin
            next_i2c_counter = i2c_counter - 8'd1;
          end
        end
      end
      I2C_READ_DATA: begin
        
        // During the ACK cycle: 
        // Send a MASTER ACK if not done reading data
        if (i2c_master_ack && i2c_repeat_count[1:0] != i2c_repeat_target[1:0]) begin
          // ACK
          SDA_buf_sel = 0;
          SDA_buf = 0;
          //SDA_buf_sel = 1;

        // OR let the slave write SDA (float SDA on our side)
        end else begin
          SDA_buf_sel = 1;
        end

        // Note: Need to capture data on the SCL rising edge, not the state machine edge
        // So separate sequential block captures data
        
        if (SDA_transition) begin
          // After an ACK cycle is over, turn off
          // the master ACK and either send a STOP
          // or get the next bit
          if (i2c_master_ack) begin
            next_i2c_master_ack = 0;
            if (i2c_repeat_count[1:0] == i2c_repeat_target[1:0]) begin
              i2c_nextstate = I2C_STOP;
            // More reads: read again
            end else begin
              next_i2c_counter = i2c_counter - 8'd1;
            end
          end else if (i2c_counter[2:0] == 3'd0) begin
          // Every 8 bits, send an ack for 1 cycle
          // before continuing
            next_i2c_master_ack = 1;
            next_i2c_repeat_count = i2c_repeat_count + 4'd1;
          end else begin
            next_i2c_counter = i2c_counter - 8'd1;
          end
        end
      end

      I2C_STOP: begin
        SDA_buf = 0;
        if (startstop_transition) begin
          i2c_nextstate = I2C_STOP2;
        end
      end
      I2C_STOP2: begin
        SDA_buf = 1;
        if (SDA_transition) begin
          i2c_nextstate = I2C_IDLE;
        end
      end

    endcase

  end

  always @(posedge SCL) begin
    if(i2c_state == I2C_READ_DATA && ~i2c_master_ack) begin
      i2c_rdata[i2c_counter] = SDA_out;
    end
  end
  // sequential always block
  always @(negedge clk) begin
    if (reset) begin
      i2c_state <= I2C_IDLE;
      i2c_counter <= 0;
    end else begin
      //if (ep01trigger[0]) begin
        //i2c_state <= I2C_IDLE;
        //i2c_counter <= 8'd0;
        //i2c_master_ack <= 1'b0;
      //end else begin
      i2c_state <= i2c_nextstate;
      i2c_counter <= next_i2c_counter;
      i2c_repeat_count <= next_i2c_repeat_count;
      i2c_master_ack <= next_i2c_master_ack;
                  i2c_need_ack <= next_i2c_need_ack;
      //end

      // don't let data change
      if(i2c_state == I2C_START0) begin
        i2c_wdata <= i2c_wdata_unreg;
        i2c_slave_addr <= i2c_slave_addr_unreg;
        i2c_reg_addr <= i2c_reg_addr_unreg;
      end
    end
  end

endmodule