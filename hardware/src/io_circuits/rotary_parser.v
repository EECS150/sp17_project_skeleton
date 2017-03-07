module rotary_parser #(
    parameter sample_count_max = 25000,
    parameter pulse_count_max = 20
)(
    input clk,
    input rst,
    input rotary_A,
    input rotary_B,
    output rotary_event,
    output rotary_left
);

    wire rotary_A_sync, rotary_B_sync;
    wire rotary_A_deb, rotary_B_deb;

    synchronizer #(
        .width(2)
    ) rotary_synchronizer (
        .clk(clk),
        .async_signal({rotary_A, rotary_B}),
        .sync_signal({rotary_A_sync,rotary_B_sync})
    );

    debouncer #(
        .width(2),
        .sample_count_max(sample_count_max), 
        .pulse_count_max(pulse_count_max)
    ) rotary_debouncer (
        .clk(clk),
        .glitchy_signal({rotary_A_sync,rotary_B_sync}),
        .debounced_signal({rotary_A_deb,rotary_B_deb})
    );

    rotary_decoder wheel_decoder (
        .clk(clk),
        .rst(rst),
        .rotary_A(rotary_A_deb),
        .rotary_B(rotary_B_deb),
        .rotary_event(rotary_event),
        .rotary_left(rotary_left)
    );
endmodule
