// ============================================================================
//     axi_fifo_rx                                                     
//     AXI FIFO receiver module                                                         
// ============================================================================
//  Engineer   : Chris C.              2026-11-08
// ----------------------------------------------------------------------------

`timescale 1ns / 1ps

module axi_fifo_rx #(
    parameter C_S_AXI_ADDR_WIDTH = 6,
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter data_bits_g = 8   // Number of data bits
) (
    input  wire        clk_p,
    input  wire        rst_n_p,
    input  wire [7:0]  data_in_p,
    input  wire        valid_p,
    output reg         ready_p = 1'b1
);

endmodule