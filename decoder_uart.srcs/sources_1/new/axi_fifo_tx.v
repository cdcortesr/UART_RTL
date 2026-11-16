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
    input wire s_axi_aresetn,       //Synchronous assertion (high) && optional asynchronous deassertion (low)

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
    output wire s_axi_bvalid,
    output reg [1:0] s_axi_bresp,

    // AXI4-Lite read address channel
    input wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input wire s_axi_arvalid,
    output wire s_axi_arready,

    // AXI4-Lite read data channel
    input wire [2:0] s_axi_arprot,  // Not used in this implementation
    input wire s_axi_rready,
    output wire s_axi_rvalid,
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

    localparam ADDR_TX_BUFF   = 6'h00;     
    localparam ADDR_RX_BUFF   = 6'h04;
    localparam ADDR_STATUS    = 6'h08;
    localparam ADDR_CONTROL   = 6'h0C;
    localparam ADDR_IRQ_EN    = 6'h10;
    localparam ADDR_IRQ_STAT  = 6'h14;

    localparam IDLE         = 2'b00;
    localparam TRANSACTION  = 2'b01;
    localparam RESP         = 2'b10;

    reg aw_hndshk, w_hndshk, b_hndshk;
    reg [C_S_AXI_ADDR_WIDTH-1:0] addr_buffer_tx;
    reg [C_S_AXI_DATA_WIDTH-1:0] data_buffer_tx;
    reg [C_S_AXI_DATA_WIDTH/8-1:0] strb;
    reg ar_hndshk, r_hndshk;
    reg [C_S_AXI_ADDR_WIDTH-1:0] addr_buffer_rx;
    reg done_wtransaction, done_rtransaction;
    reg start_wtransaction, start_rtransaction;
    reg w_state, r_state;
    reg int_clk;
    reg overrun;

    // Write FSM

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            start_wtransaction <= 1'b0;
            w_state <= IDLE;
            aw_hndshk <= 1'b0;
            w_hndshk <= 1'b0;
            b_hndshk <= 1'b0;
        end else begin
            case (w_state)
                IDLE: begin
                    if (s_axi_awvalid && s_axi_awready) begin
                        aw_hndshk <= 1'b1;
                        addr_buffer_tx <= s_axi_awaddr;
                    end 
                    if (s_axi_wvalid && s_axi_wready) begin
                        w_hndshk        <= 1'b1;
                        data_buffer_tx  <= s_axi_wdata;
                        strb            <= s_axi_wstrb;
                    end
                    if (aw_hndshk && w_hndshk) begin
                        w_state <= TRANSACTION;
                        start_wtransaction <= 1'b1;
                    end
                end
                TRANSACTION: begin
                    if (done_wtransaction) begin
                        start_wtransaction <= 1'b0;
                        w_state <= RESP;
                        b_hndshk <= 1'b0;
                    end
                end
                RESP: begin
                    if (s_axi_bready && s_axi_bvalid) begin
                        b_hndshk <= 1'b1;
                        aw_hndshk <= 1'b0;
                        w_hndshk <= 1'b0;
                        w_state <= IDLE;
                    end
                end
            endcase
        end
    end

    // A MASTER interface must drive ARVALID, AWVALID, && WVALID LOW.
    // The earliest point after reset that a master is permitted to begin driving ARVALID, AWVALID, or WVALID HIGH is at a rising ACLK edge after ARESETn is HIGH

    assign s_axi_awready = s_axi_aresetn && !aw_hndshk;
    assign s_axi_wready  = s_axi_aresetn && !w_hndshk;
    assign s_axi_bvalid  = s_axi_aresetn && !b_hndshk;       //Mandatory, other signals custom to this implementation
    // AXI3 can assert bvalid just with wvalid/ready exchange no need to wait 4 aw exchange.
    // Missing to implement bresp at reset
    // Read FSM
    
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin :read_fsm
        if (!s_axi_aresetn) begin
            start_rtransaction <= 1'b0;
            r_state <= IDLE;
            s_axi_rdata <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            ar_hndshk <= 1'b0;
            r_hndshk <= 1'b0;
        end else begin
            case (r_state)
                IDLE: begin
                    if (s_axi_arvalid && s_axi_arready) begin
                        addr_buffer_rx <= s_axi_araddr;
                        ar_hndshk <= 1'b1;
                        r_state <= TRANSACTION;
                        start_rtransaction <= 1'b1;
                    end
                end
                TRANSACTION: begin
                    if (done_rtransaction) begin
                        start_rtransaction <= 1'b0;
                        r_state <= RESP;
                        r_hndshk <= 1'b0;
                    end
                end
                RESP: begin
                    if (s_axi_rready && s_axi_rvalid) begin
                        r_hndshk <= 1'b1;
                        r_state <= IDLE;
                    end
                end
            endcase
        end
    end

    assign s_axi_arready = s_axi_aresetn && !ar_hndshk;
    assign s_axi_rvalid  = s_axi_aresetn && !r_hndshk;      //Mandatory, other signals custom to this implementation
    // Missing to implement rresp && rdata at reset

    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 5;   // 32 entries in the FIFO

        // storage: no reset, so the tool can infer RAM
    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    // pointers are one bit wider than the address
    reg [ADDR_WIDTH:0] wr_ptr;
    reg [ADDR_WIDTH:0] rd_ptr;

    // flags
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]) &&
                   (wr_ptr[ADDR_WIDTH]     != rd_ptr[ADDR_WIDTH]);

    reg count;
    reg i;
    always @(*) begin
        count = 0;
        for (i = 0; i < DATA_WIDTH/8; i = i + 1)
            count = count + strb[i];
    end

    // pointers && overrun flag
    always @(posedge int_clk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            wr_ptr  <= 0;
            rd_ptr  <= 0;
            overrun <= 1'b0;
        end else begin
            if (start_wtransaction && !full) begin
                if (wr_ptr - rd_ptr >= count) begin
                    for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin
                        if (strb[i] && !full) begin
                            mem[wr_ptr[ADDR_WIDTH-1:0]] <= data_buffer_tx[i*8 +: 8];
                        end
                        wr_ptr  <= wr_ptr + 1'b1;   // wraps by itself
                    end
                    done_wtransaction <= 1'b1;
                    s_axi_bresp <= RESP_OKAY;   // Indicate a successful response (AXI protocol)
                end else if (start_wtransaction && full) begin
                    overrun <= 1'b1;
                    done_wtransaction <= 1'b1;
                    s_axi_bresp <= RESP_SLVERR;   // Indicate an error response (AXI protocol)
                end
            end
            if (start_rtransaction && !empty) begin

                rd_ptr  <= rd_ptr + 1'b1;              // rd_ptr increments in next cycle, so memory still points to the correct location for this cycle
                s_axi_rdata <= mem[rd_ptr[ADDR_WIDTH-1:0]];
                s_axi_rresp <= RESP_OKAY;   // Indicate a successful response (AXI protocol)
                done_rtransaction <= 1'b1;
            end else if (start_rtransaction && empty) begin
                s_axi_rresp <= RESP_SLVERR;   // Indicate an error response (AXI protocol)
                done_rtransaction <= 1'b1;
            end
            done_rtransaction <= 1'b0;
            done_wtransaction <= 1'b0;
        end
    end

endmodule

// Considerations for FIFO size 
// sprite1(a,1020,862)  max length of instruction   25 bytes