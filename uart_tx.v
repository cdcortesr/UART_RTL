// ============================================================================
//     uart_tx                                                     
//     FSM to create the UART frame                                                         
// ============================================================================
//  Engineer   : Chris C.              2026-11-08
// ----------------------------------------------------------------------------


module uart_tx #(
    parameter stop_bits_g = 1,  // Number of stop bits (1 or 2)
    parameter flow_ctrl_g = 0,  // 0: No flow control, 1: Flow control enabled
    parameter data_bits_g = 8,
    parameter parity_g = "ODD"  
    )( 
    input  wire        clk_tx_p,
    input  wire        rst_n_p,
    input  wire [data_bits_g-1:0]  data_tx_p,
    input  wire        valid_p,         // valid/ready interface goes to module that provides data to transmit
    output reg         ready_p = 1'b0,         // ready signal to module that provides data to transmit
    output reg         tx_serial_p = 1'b1
);
    localparam [2:0] IDLE = 3'd0,
                 START  = 3'd1,
                 DATA   = 3'd2,
                 PARITY = 3'd3,
                 STOP   = 3'd4;
    reg [2:0] state_tx = IDLE;
    reg [data_bits_g-1:0] buffer = 0;
    integer i = 0;

    initial begin
        tx_serial_p = 1'b1;
    end
    // Next state logic
    always @(posedge clk_tx_p) begin
        if (!rst_n_p) begin
            state_tx <= IDLE;
        end else  begin
            case (state_tx)
            IDLE: begin
                i = 0;
                tx_serial_p <= 1;
                if (valid_p == 1) begin
                    ready_p <= 1;
                    buffer <= data_tx_p;
                    state_tx <= START;
                end
            end
            START: begin
                ready_p <= 0;
                tx_serial_p <= 0; 
                state_tx <= DATA;
            end
            DATA: begin
                tx_serial_p <= buffer[i];
                i = i + 1;
                if (i == data_bits_g-1) begin
                    state_tx <= PARITY;
                end
            end
            PARITY: begin 
                case (parity_g)
                "ODD": tx_serial_p <= ~(^buffer);
                "EVEN": tx_serial_p <= ^buffer;
                "MARK": tx_serial_p <= 1;
                "SPACE": tx_serial_p <= 0;
                endcase
                state_tx <= STOP;
            end
            STOP: begin
                tx_serial_p <= 1;
                state_tx = IDLE;
            end
            default: state_tx = IDLE;
        endcase
        end
    end
endmodule
