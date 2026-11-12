// ============================================================================
//     axi_fifo_tx                                                     
//     AXI FIFO for UART transmission                                                         
// ============================================================================
//  Engineer   : Chris C.              2026-11-08
// ----------------------------------------------------------------------------

`timescale 1ns / 1ps

module axi_fifo_tx #(
    parameter C_S_AXI_ADDR_WIDTH = 6,
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter data_bits_g = 8   // Number of data bits
)(
    // Global signals
    input wire s_axi_aclk,
    input wire s_axi_aresetn,       //Synchronous assertion (high) and optional asynchronous deassertion (low)

    // AXI4-Lite write address channel
    input wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input wire s_axi_awvalid,
    input wire [2:0] s_axi_awprot,  // Not used in this implementation
    output wire s_axi_awready,

    // AXI4-Lite write data channel
    input wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input wire [C_S_AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,
    input wire s_axi_wvalid,
    output wire s_axi_wready,

    // AXI4-Lite write response channel
    input wire s_axi_bready,
    output reg s_axi_bvalid,
    output reg [1:0] s_axi_bresp,

    // AXI4-Lite read address channel
    input wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input wire s_axi_arvalid,
    output wire s_axi_arready,

    // AXI4-Lite read data channel
    input wire [2:0] s_axi_arprot,  // Not used in this implementation
    input wire s_axi_rready,
    output reg s_axi_rvalid,
    output reg [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output reg [1:0] s_axi_rresp,

    // UART interface
    input wire tx_ready,
    output reg tx_valid,
    output reg [data_bits_g-1:0] tx_data
    );

    // AXI response codes
    localparam RESP_OKAY  = 2'b00;
    localparam RESP_EXOKAY = 2'b01;     // Not used in AXI4-lite
    localparam RESP_SLVERR = 2'b10;     // Target with declined/conditional access
    localparam RESP_DECERR = 2'b11;     // Target not found

    // --------------------------------------------------
    // Register address map
    // --------------------------------------------------

    localparam ADDR_TX_BUFF   = 6'h00;      // # of bytes taken or written into the buffer is encoded in the lower 8 bits
    localparam ADDR_RX_BUFF   = 6'h04;
    localparam ADDR_STATUS    = 6'h08;
    localparam ADDR_CONTROL   = 6'h0C;
    localparam ADDR_IRQ_EN    = 6'h10;
    localparam ADDR_IRQ_STAT  = 6'h14;

    // Write FSM states

    localparam [1:0] WR_IDLE = 2'd0,
                     WR_EXEC = 2'd1,
                     WR_RESP = 2'd2;

    // Read FSM states

    localparam [1:0] RD_IDLE = 2'd0,
                     RD_EXEC = 2'd1,
                     RD_RESP = 2'd2;



    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin :write_fsm
        if (!s_axi_aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= RESP_OKAY;
        end else begin
                case (wr_state)
                    WR_IDLE: begin
                        s_axi_awready <= 1'b1;
                        s_axi_wready  <= 1'b1;
                        s_axi_bvalid  <= 1'b0;
                        s_axi_bresp   <= RESP_OKAY;
                        if (s_axi_awvalid && s_axi_wvalid) begin
                            wr_state <= WR_EXEC;
                        end
                    end
                    WR_EXEC: begin
                        s_axi_awready <= 1'b0;
                        s_axi_wready  <= 1'b0; 
                    end
                    WR_RESP: begin
                        s_axi_bvalid <= 1'b1;
                        if (s_axi_bready) begin
                            wr_state <= WR_IDLE;
                        end
                    end
                    default: begin
                        wr_state <= WR_IDLE;
                    end
                endcase
            end
        end
    end

    // Read FSM
    
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin :read_fsm
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= RESP_OKAY;
            s_axi_rdata   <= {C_S_AXI_DATA_WIDTH{1'b0}};
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    s_axi_arready <= 1'b1;
                    s_axi_rvalid  <= 1'b0;
                    s_axi_rresp   <= RESP_OKAY;
                    if (s_axi_arvalid) begin
                        rd_state <= RD_EXEC;
                    end
                end
                RD_EXEC: begin
                    s_axi_arready <= 1'b0;
                end
                RD_RESP: begin
                    s_axi_rvalid <= 1'b1;
                    if (s_axi_rready) begin
                        rd_state <= RD_IDLE;
                    end
                end
                default: begin
                    rd_state <= RD_IDLE;
                end
            endcase
        end
    end

endmodule
