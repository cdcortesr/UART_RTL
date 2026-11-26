// ============================================================================
//     uart_rx_decoder_tb                                                     
//     Reception of Hello World string to verify successful data recovery                                                         
// ============================================================================
//  Engineer   : Chris C.              2026-11-07
// ----------------------------------------------------------------------------

`timescale 10ns / 1ps

module uart_rx_tb(
    input wire rx_tick,
    input wire s_axi_aresetn,
    input wire ready_p,
    output wire valid_p,
    output wire [7:0] data_rx_p,
    output wire frame_err_p,
    output wire parity_err_p
);

    wire rx_serial_p;
    reg uart_rx = 1;
    wire clk_rx_p;
    assign clk_rx_p = rx_tick;
    wire rst_n_p;
    assign rst_n_p = s_axi_aresetn;

    integer bit_idx = 0;
	integer i = 0;
	reg [8*14:1] dataA = "Hello World! 1";
	reg [7:0] string_value [0:13];

    uart_rx uut (
        .rx_serial_p  (rx_serial_p),
        .clk_rx_p (clk_rx_p),
        .rst_n_p      (rst_n_p),
        .ready_p      (ready_p),  // Always ready to receive frames
        .valid_p      (valid_p),
        .data_rx_p      (data_rx_p),
        .frame_err_p  (frame_err_p),
        .parity_err_p (parity_err_p)
    );

        uart_rx_sync rx_sync
    (
        .uart_rx(uart_rx),
        .uart_rx_db(rx_serial_p),
        .clk(rx_tick),
        .rst_n(s_axi_aresetn)
    );

    // Clock generation: 50 MHz
    //always #1 clk_rx_p = ~clk_rx_p;

    // Transmit one UART bit (16x oversampling)
    task send_bit;
        input bit_value;
        begin
            @(posedge clk_rx_p);
            uart_rx = bit_value;
            repeat (16) @(posedge clk_rx_p);
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
        //rst_n_p = 0;
        uart_rx = 1;

        #5;
        //rst_n_p = 1;

        // Allow receiver to stabilize
        #10;
		for (i=0; i<14; i=i+1) begin
			send_frame(string_value[i]);
			//repeat (5) @(posedge clk_rx_p);
		end

        $display("Received frame: %h", data_rx_p);
        $display("Ready: %b", valid_p);
        $display("Frame error: %b", frame_err_p);
        $display("Parity error: %b", parity_err_p);

        //$finish;
    end

endmodule