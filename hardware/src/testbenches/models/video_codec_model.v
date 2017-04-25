`timescale 1ns/1ps

/*
 * This is a behavioral model of the Chrontel CH7301C DVI Transmitter Device.
 *
 * This model's behavior is set at instantiation by parameters, and the
 * behavior can't be changed during runtime. The I2C interface to this chip
 * isn't used in this model.
 *
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

// Set this to 1 if you want the data collection thread to print out the
    // pixel count as it receives pixels
`define print_pixel_count  0 

// By default this model doesn't print messages when the horizontal timing
// (hsync pulse, hori back porch, hori data region, hori front porch) is OK.
// To print the timing with vertical line number, change this to 1
`define print_hori_timing_info 0

module ch7301c_model # (
    parameter clock_period = 15.385,

    parameter hori_front_porch = 24,
    parameter hori_sync_pulse = 136,
    parameter hori_back_porch = 160,
    parameter hori_visible_area = 1024,
    parameter hori_whole_line = hori_front_porch + hori_sync_pulse + hori_back_porch + hori_visible_area, // 1344

    parameter vert_front_porch = 3,
    parameter vert_sync_pulse = 6,
    parameter vert_back_porch = 29,
    parameter vert_visible_area = 768,
    parameter vert_whole_frame = vert_front_porch + vert_sync_pulse + vert_back_porch + vert_visible_area, // 806
   
    parameter refresh_rate = 60,
    parameter xclk_frequency = hori_whole_line * vert_whole_frame * refresh_rate,
    
    // SO FAR ONLY ddr_latching = 1 is SUPPORTED IN THIS MODEL
    parameter ddr_latching = 1,     // 1 = data latched on both clock edges, 0 = data latched on single clock edge
   
    // SO FAR ONLY IDF = 3 is SUPPORTED IN THIS MODEL
    parameter idf = 3,              // IDF = input clock and data format. Possble values = 0,1,2,3,4
                                    // 5 different multiplexed data formats
                                    // IDF = 0: 12-bit multiplexed RGB (24-bit color)
                                    // IDF = 1: 12-bit multiplexed RGB2 (24-bit color)
                                    // IDF = 2: 8-bit multiplexed RGB (16-bit color, 565)
                                    // IDF = 3: 8-bit multiplexed RGB (15-bit color, 555)
                                    // IDF = 4: 8-bit multiplexed YCrCb (24-bit color)
                                    // With IDF = 3, if the 2 data packets received on 1 cycle of xclk are
                                        // labeled P0a and P0b, then R = P0b[10:6], G = P0b[5:4],P0a[11:9],
                                        // B = P0a[8:4]
    parameter sync_polarity = 0     // sync_polarity == 0 means active-low HSYNC/VSYNC, == 1 means active-high
) (
    input [11:0] dvi_data,  // Data Inputs 
    input dvi_de,           // Data Enable (shoule be high when video data is active)
    input dvi_h,            // Horizontal Sync
    input dvi_v,            // Vertical Sync
    input dvi_reset_b,      // Active-low power-on reset (when high, reset controller over I2C)
    input dvi_xclk_n,       // Differential external clock, synchronous wrt DE, H, V, data[11:0]
    input dvi_xclk_p
);

    // This function checks if 2 times are within floating-point precision
    // variation of each other. tolerance is specified in ns.
    function integer equal;
        input time1, time2, tolerance;
        realtime time1, time2, tolerance;

        begin
            if (time1 < time2) begin
                if (time2 - time1 > tolerance) equal = 0;
                else equal = 1;
            end
            else if (time1 >= time2) begin
                if (time1 - time2 > tolerance) equal = 0;
                else equal = 1;
            end
        end
    endfunction

    wire hsync_asserted, vsync_asserted, de_asserted; 
    assign hsync_asserted = sync_polarity ? dvi_h === 1'b1 : dvi_h === 1'b0;
    assign vsync_asserted = sync_polarity ? dvi_v === 1'b1 : dvi_v === 1'b0;
    assign de_asserted = dvi_de === 1'b1;

    reg [11:0] dvi_data_a;
    reg [11:0] dvi_data_b;
    wire [4:0] red_data;
    wire [4:0] blue_data;
    wire [4:0] green_data;
    always @ (posedge dvi_xclk_p) begin
        dvi_data_b <= dvi_data;
    end
    always @ (negedge dvi_xclk_p) begin
        dvi_data_a <= dvi_data;
    end
    
    // These assignments are based on a particular value of IDF (IDF = 3)
    assign red_data = {dvi_data_b[10:6]};
    assign green_data = {dvi_data_b[5:4], dvi_data_a[11:9]};
    assign blue_data = {dvi_data_a[8:4]};

    // Variables used in timing check thread 
    realtime vsync_assertion_start_time;
    realtime vsync_assertion_end_time;
    event vsync_pulse_done;
    `define vsync_pulse_time (vsync_assertion_end_time - vsync_assertion_start_time)
    `define vsync_pulse_time_expected (clock_period * vert_sync_pulse * hori_whole_line)

    realtime vert_back_porch_start_time;
    realtime vert_back_porch_end_time;
    event vert_back_porch_done;
    `define vert_back_porch_time (vert_back_porch_end_time - vert_back_porch_start_time)
    `define vert_back_porch_time_expected (clock_period * vert_back_porch * hori_whole_line)

    realtime vert_front_porch_start_time;
    realtime vert_front_porch_end_time;
    event vert_front_porch_done;
    `define vert_front_porch_time (vert_front_porch_end_time - vert_front_porch_start_time)
    `define vert_front_porch_time_expected (clock_period * vert_front_porch * hori_whole_line)
   
    integer vertical_line_count = 0;
    realtime hsync_assertion_start_time;
    realtime hsync_assertion_end_time;
    event hsync_pulse_done;
    `define hsync_pulse_time (hsync_assertion_end_time - hsync_assertion_start_time)
    `define hsync_pulse_time_expected (clock_period * hori_sync_pulse)

    realtime hori_back_porch_start_time;
    realtime hori_back_porch_end_time;
    event hori_back_porch_done;
    `define hori_back_porch_time (hori_back_porch_end_time - hori_back_porch_start_time)
    `define hori_back_porch_time_expected (clock_period * hori_back_porch)

    realtime hori_data_start_time;
    realtime hori_data_end_time;
    event hori_data_done;
    `define hori_data_time (hori_data_end_time - hori_data_start_time)
    `define hori_data_time_expected (clock_period * hori_visible_area)

    realtime hori_front_porch_start_time;
    realtime hori_front_porch_end_time;
    event hori_front_porch_done;
    `define hori_front_porch_time (hori_front_porch_end_time - hori_front_porch_start_time)
    `define hori_front_porch_time_expected (clock_period * hori_front_porch)

    // Variables used in data collection thread
    integer video_data_file;
    integer pixel_count = 0;
    integer frame_count = 0;

    // Event triggered timing checks
    always @(vsync_pulse_done) begin
        if (!equal(`vsync_pulse_time, `vsync_pulse_time_expected, 0.5)) begin
            $display("VIDEO CODEC ERROR (vsync pulse timing): The length of the vsync pulse was %t, expected %t, at time %t", `vsync_pulse_time, `vsync_pulse_time_expected, $time);
        end
        else begin
            $display("VIDEO CODEC info (vsync pulse timing): The length of the vsync pulse was %t, done at time %t", `vsync_pulse_time, $time);
        end
    end

    always @(vert_back_porch_done) begin
        if (!equal(`vert_back_porch_time, `vert_back_porch_time_expected, 0.5)) begin
            $display("VIDEO CODEC ERROR (vert back porch timing): The length of the vert back porch was %t, expected %t, at time %t", `vert_back_porch_time, `vert_back_porch_time_expected, $time);
        end
        else begin
            $display("VIDEO CODEC info (vert back porch timing): The length of the vert back porch was %t, done at time %t", `vert_back_porch_time, $time);
        end
    end

    always @(vert_front_porch_done) begin
        if (!equal(`vert_front_porch_time, `vert_front_porch_time_expected, 0.5)) begin
            $display("VIDEO CODEC ERROR (vert front porch timing): The length of the vert front porch was %t, expected %t, at time %t", `vert_front_porch_time, `vert_front_porch_time_expected, $time);
        end
        else begin
            $display("VIDEO CODEC info (vert front porch timing): The length of the vert front porch was %t, done at time %t", `vert_front_porch_time, $time);
        end
    end


    always @(hsync_pulse_done) begin
        if (!equal(`hsync_pulse_time, `hsync_pulse_time_expected, 2.5)) begin
            $display("VIDEO CODEC ERROR (hsync pulse timing): The length of the hsync pulse was %t, expected %t, on line %d, at time %t", `hsync_pulse_time, `hsync_pulse_time_expected, vertical_line_count, $time);
        end
        else begin
            if (`print_hori_timing_info)
            $display("VIDEO CODEC info (hsync pulse timing): The length of the hsync pulse was %t, on line %d, done at time %t", `hsync_pulse_time, vertical_line_count, $time);
        end
    end

    always @(hori_back_porch_done) begin
        if (!equal(`hori_back_porch_time, `hori_back_porch_time_expected, 2.5)) begin
            $display("VIDEO CODEC ERROR (hori back porch timing): The length of the hori back porch was %t, expected %t, on line %d, at time %t", `hori_back_porch_time, `hori_back_porch_time_expected, vertical_line_count, $time);
        end
        else begin
            if (`print_hori_timing_info)
            $display("VIDEO CODEC info (hori back porch timing): The length of the hori back porch was %t, on line %d, done at time %t", `hori_back_porch_time, vertical_line_count, $time);
        end
    end
    
    always @(hori_data_done) begin
        if (!equal(`hori_data_time, `hori_data_time_expected, 2.5)) begin
            $display("VIDEO CODEC ERROR (hori data timing): The length of the hori data region was %t, expected %t, on line %d, at time %t", `hori_data_time, `hori_data_time_expected, vertical_line_count, $time);
        end
        else begin
            if (`print_hori_timing_info)
            $display("VIDEO CODEC info (hori data timing): The length of the hori data region was %t, on line %d, done at time %t", `hori_data_time, vertical_line_count, $time);
        end
    end

    always @(hori_front_porch_done) begin
        if (!equal(`hori_front_porch_time, `hori_front_porch_time_expected, 2.5)) begin
            $display("VIDEO CODEC ERROR (hori front porch timing): The length of the hori front porch was %t, expected %t, on line %d, at time %t", `hori_front_porch_time, `hori_front_porch_time_expected, vertical_line_count, $time);
        end
        else begin
            if (`print_hori_timing_info)
            $display("VIDEO CODEC info (hori front porch timing): The length of the hori front porch was %t, on line %d, done at time %t", `hori_front_porch_time, vertical_line_count, $time);
        end
    end

    // General checks that should hold true on every clock cycle
    always @ (posedge dvi_xclk_p or negedge dvi_xclk_p) begin
        // ONLY 1 of the hsync, vsync, or DE signals can be high at a time.
        if (de_asserted + hsync_asserted + vsync_asserted > 1) begin
            $display("VIDEO CODEC ERROR (signaling): at time %t, more than 1 of H, V, or DE were high at the same time", $time);
        end
    end

    initial begin
        // Print out time in nanoseconds so it can be easily pasted into
        // Modelsim
        $timeformat(-9, 2, " ns", 13);
        $display("\n");
        // Open the video data file which will contain pixel data
        video_data_file = $fopen("video_data.txt", "w");

        fork
            // Data collection thread
            begin
                forever begin
                    // Wait for assertion and deassertion of the vsync pulse
                    @(posedge vsync_asserted);
                    @(negedge vsync_asserted);

                    // Pixel data is valid for vert_visible_area lines of
                    // de_asserted
                    repeat (vert_visible_area) begin
                        @(posedge de_asserted);
                        pixel_count = 0;
                        repeat (hori_visible_area) begin
                            @(negedge dvi_xclk_p);
                            $fwrite(video_data_file, "%d,%d,%d|", red_data, green_data, blue_data);
                            if (`print_pixel_count) $display("VIDEO CODEC info (data collection): received pixel %d at time %t", pixel_count, $time);
                            pixel_count = pixel_count + 1;
                        end
                        @(negedge de_asserted);
                    end

                    $display("VIDEO CODEC info (data collection): received video frame %d at time %t", frame_count, $time);
                    frame_count = frame_count + 1;
                    $fwrite(video_data_file, "\n");
                end
            end
            // Timing check thread
            begin
                @(posedge vsync_asserted);
                forever begin
                    $display("VIDEO CODEC info (timing): video frame starting with vsync assertion at time: %t", $time);
                    vsync_assertion_start_time = $realtime;
                    @(negedge vsync_asserted);
                    vsync_assertion_end_time = $realtime;
                    -> vsync_pulse_done;

                    vert_back_porch_start_time = $realtime;
                    @(posedge hsync_asserted);
                    vert_back_porch_end_time = $realtime;
                    -> vert_back_porch_done;

                    for (vertical_line_count = 0; vertical_line_count <= vert_visible_area - 1; vertical_line_count = vertical_line_count + 1) begin
                        // Hsync pulse
                        hsync_assertion_start_time = $realtime;
                        @(negedge hsync_asserted);
                        hsync_assertion_end_time = $realtime;
                        -> hsync_pulse_done;

                        // Horizontal back porch
                        hori_back_porch_start_time = $realtime;
                        @(posedge de_asserted); 
                        hori_back_porch_end_time = $realtime;
                        -> hori_back_porch_done;

                        // Horizontal data (display/visible region)
                        hori_data_start_time = $realtime;
                        @(negedge de_asserted);
                        hori_data_end_time = $realtime;
                        -> hori_data_done;

                        // Horizontal front porch
                        hori_front_porch_start_time = $realtime;
                        if (vertical_line_count == vert_visible_area - 1) begin
                            repeat (hori_front_porch) @(posedge dvi_xclk_p);
                            hori_front_porch_end_time = $realtime;
                            vert_front_porch_start_time = $realtime;
                            -> hori_front_porch_done;
                        end else begin
                            @(posedge hsync_asserted);
                            hori_front_porch_end_time = $realtime;
                            -> hori_front_porch_done;
                        end
                    end

                    @(posedge vsync_asserted);
                    vert_front_porch_end_time = $realtime;
                    -> vert_front_porch_done;
                    $display("VIDEO CODEC info (timing): full video frame received at time %t\n", $time);
                end
            end
        join
    end
endmodule
