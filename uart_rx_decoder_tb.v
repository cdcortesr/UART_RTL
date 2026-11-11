// ============================================================================
//     uart_rx_decoder_tb                                                     
//     Trasmission of string to verify successful data recovery                                                         
// ============================================================================
//  Engineer   : Chris C.              2026-11-07
// ----------------------------------------------------------------------------

`timescale 10ns / 1ps

module Decoder_rx_tb();

    reg rx_signal_p = 1;
    reg clk_sample_p = 0;
    reg rst_n_p = 0;

    wire [7:0] frame_p;
    wire valid_p, frame_err_p, parity_err_p;

    integer bit_idx = 0;
	integer i = 0;
	reg [8*14:1] dataA = "Hello World! 1";
	reg [7:0] string_value [0:13];

    uart_rx_decode uut (
        .rx_signal_p  (rx_signal_p),
        .clk_sample_p (clk_sample_p),
        .rst_n_p      (rst_n_p),
        .ready_p      (1'b1),  // Always ready to receive frames
        .valid_p      (valid_p),
        .frame_p      (frame_p),
        .frame_err_p  (frame_err_p),
        .parity_err_p (parity_err_p)
    );

    // Clock generation: 50 MHz
    always #1 clk_sample_p = ~clk_sample_p;

    // Transmit one UART bit (16x oversampling)
    task send_bit;
        input bit_value;
        begin
            @(posedge clk_sample_p);
            rx_signal_p = bit_value;
            repeat (16) @(posedge clk_sample_p);
        end
    endtask

	task send_frame;
		input [7:0] data;
		begin
			// Start bit
			send_bit(0);
			// Data bits (LSB first)
			for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1)
				send_bit(data[bit_idx]);
			// Odd parity
			send_bit(~(^data));
			// Stop bit
			send_bit(1);
		end
	endtask

    initial begin
		for (i=0; i<14; i=i+1) begin
			string_value[i] = dataA[(8*(14-i)) -: 8];
		end

        // Reset
        rst_n_p = 0;
        rx_signal_p = 1;

        #5;
        rst_n_p = 1;

        // Allow receiver to stabilize
        #10;
		for (i=0; i<14; i=i+1) begin
			send_frame(string_value[i]);
			//repeat (5) @(posedge clk_sample_p);
		end

        $display("Received frame: %h", frame_p);
        $display("Ready: %b", valid_p);
        $display("Frame error: %b", frame_err_p);
        $display("Parity error: %b", parity_err_p);

        $finish;
    end

endmodule