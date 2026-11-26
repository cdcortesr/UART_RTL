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
    //input wire [2:0] s_axi_awprot,  // Not used in this implementation
    output reg s_axi_awready,

    // AXI4-Lite write data channel
    input wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input wire [C_S_AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,
    input wire s_axi_wvalid,
    output reg s_axi_wready,

    // AXI4-Lite write response channel
    input wire s_axi_bready,
    output reg s_axi_bvalid,
    output reg [1:0] s_axi_bresp,

    // AXI4-Lite read address channel
    input wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input wire s_axi_arvalid,
    output reg s_axi_arready,

    // AXI4-Lite read data channel
    //input wire [2:0] s_axi_arprot,  // Not used in this implementation
    input wire s_axi_rready,
    output reg s_axi_rvalid,
    output reg [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output reg [1:0] s_axi_rresp,

    input wire int_clk,

    // UART tx interface
    input wire tx_ready,
    output reg tx_valid,
    output reg [data_bits_g-1:0] tx_data,

    // UART rx interface
    input wire [data_bits_g-1:0] rx_data,
    input wire rx_valid,
    output reg rx_ready
    
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

    localparam IDLE         = 2'b00;
    localparam TRANSACTION  = 2'b01;
    localparam RESP         = 2'b10;

    reg aw_hndshk, w_hndshk;
    reg [C_S_AXI_ADDR_WIDTH-1:0] write_addr;
    reg [C_S_AXI_DATA_WIDTH-1:0] data_buffer_tx;
    reg [C_S_AXI_DATA_WIDTH/8-1:0] strb;
    reg [C_S_AXI_ADDR_WIDTH-1:0] read_addr;
    reg [1:0] tx_state, rx_state;
     
    localparam DATA_WIDTH = 8;
    localparam ADDR_WIDTH = 5;   // 32 entries in the FIFO, last bit used for wrap-around detection
    
            // pointers are one bit wider than the address
    reg [ADDR_WIDTH:0] wr_ptr_tx = 0;
    reg [ADDR_WIDTH:0] temp_ptr_tx = 0;
    reg [ADDR_WIDTH:0] rd_ptr_tx = 0;

    reg [ADDR_WIDTH:0] wr_ptr_rx = 0;
    reg [ADDR_WIDTH:0] temp_ptr_rx = 0;
    reg [ADDR_WIDTH:0] rd_ptr_rx = 0;

        // storage: no reset, so the tool can infer RAM
    reg [DATA_WIDTH-1:0] mem_w [0:(1<<ADDR_WIDTH)-1];
    reg [DATA_WIDTH-1:0] mem_r [0:(1<<ADDR_WIDTH)-1];


    // flags
    wire empty_tx, full_tx;
    assign empty_tx = (wr_ptr_tx == rd_ptr_tx);
    assign full_tx  = (wr_ptr_tx[ADDR_WIDTH-1:0] == rd_ptr_tx[ADDR_WIDTH-1:0]) &&
                   (wr_ptr_tx[ADDR_WIDTH]     != rd_ptr_tx[ADDR_WIDTH]);


        // flags
    wire empty_rx, full_rx;
    assign empty_rx = (wr_ptr_rx == rd_ptr_rx);
    assign full_rx  = (wr_ptr_rx[ADDR_WIDTH-1:0] == rd_ptr_rx[ADDR_WIDTH-1:0]) &&
                   (wr_ptr_rx[ADDR_WIDTH]     != rd_ptr_rx[ADDR_WIDTH]);

    reg [ADDR_WIDTH:0] free_space =0;
    reg [ADDR_WIDTH:0] used_space = 0;



    // TX Buffer write FSM

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin: write_fsm
        if (!s_axi_aresetn) begin
            tx_state <= IDLE;
            aw_hndshk <= 1'b0;
            w_hndshk <= 1'b0;
            s_axi_bvalid <= 1'b0;   //Mandatory, other signals custom to this implementation
            s_axi_bresp <= RESP_OKAY;   // Default response
            s_axi_awready <= 1'b0;   
            s_axi_wready <= 1'b0;   
            wr_ptr_tx <= 0;
        end else begin
            case (tx_state)
                IDLE: begin
                    if (aw_hndshk == 0)
                        s_axi_awready <= 1'b1;
                    if (w_hndshk == 0)
                        s_axi_wready <= 1'b1;
                    if (s_axi_awvalid && s_axi_awready) begin
                        aw_hndshk <= 1'b1;
                        s_axi_awready <= 1'b0; 
                        write_addr <= s_axi_awaddr;
                    end 
                    if (s_axi_wvalid && s_axi_wready) begin
                        w_hndshk        <= 1'b1;
                        s_axi_wready <= 1'b0;
                        data_buffer_tx  <= s_axi_wdata;
                        strb            <= s_axi_wstrb;
                    end
                    if (aw_hndshk && w_hndshk) begin
                        if (write_addr == ADDR_TX_BUFF) begin
                            if (!full_tx) begin: count_blck
                                integer count;
                                count = strb[0] + strb[1] + strb[2] + strb[3]; 
                                temp_ptr_tx = wr_ptr_tx;   // Use a temporary pointer to track the write location
                                used_space = wr_ptr_tx - rd_ptr_tx+1;
                                free_space = (1 << ADDR_WIDTH);
                                if (free_space >= count) begin: name
                                    integer i;
                                    for (i = 0; i < C_S_AXI_DATA_WIDTH/8; i = i + 1) begin
                                        if (strb[i]) begin
                                            mem_w[temp_ptr_tx[ADDR_WIDTH-1:0]] <= data_buffer_tx[i*8 +: 8];
                                            temp_ptr_tx = temp_ptr_tx + 1'b1;  
                                        end
                                    end
                                    wr_ptr_tx <= temp_ptr_tx;   // Update the actual write pointer after writing all bytes
                                    s_axi_bresp <= RESP_OKAY;   // Indicate a successful response (AXI protocol)
                                end 
                            end else begin                     // Discard write operation when space available is insufficient
                                s_axi_bresp <= RESP_SLVERR;   // Indicate an error response (AXI protocol)
                            end
                        end else begin
                            s_axi_bresp <= 2'b10; // SLVERR response for invalid address
                        end
                        tx_state <= RESP;
                        s_axi_bvalid <= 1'b1;
                    end
                end
                RESP: begin
                    if (s_axi_bready && s_axi_bvalid) begin
                        s_axi_bvalid <= 1'b0;  
                        aw_hndshk <= 1'b0;
                        w_hndshk <= 1'b0;
                        tx_state <= IDLE;
                    end
                end
            endcase
        end
    end


    // TX Buffer read FSM

    always @(posedge int_clk) begin
        if  (!s_axi_aresetn) begin
            rd_ptr_tx <= 0;
        end else begin
            if (!empty_tx) begin
                tx_valid <= 1'b1;
                tx_data <= mem_w[rd_ptr_tx[ADDR_WIDTH-1:0]];   // Read data from FIFO into TX buffer
                if (tx_ready && tx_valid) begin
                    tx_valid <= 1'b0;
                    rd_ptr_tx <= rd_ptr_tx + 1'b1;   // Increment read pointer after reading
                end
            end 
        end
    end


    // RX Buffer Read FSM
    
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin :read_fsm
        if (!s_axi_aresetn) begin
            rx_state <= IDLE;
            s_axi_rdata <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else begin
            case (rx_state)
                IDLE: begin
                    if (s_axi_arvalid && s_axi_arready) begin
                        s_axi_arready <= 1'b0;
                        read_addr <= s_axi_araddr;
                        case (read_addr)
                            ADDR_RX_BUFF: begin
                                if (!empty_rx) begin
                                    s_axi_rdata <= mem_r[rd_ptr_rx[ADDR_WIDTH-1:0]];
                                    rd_ptr_rx <= rd_ptr_rx + 1'b1;   // Increment read pointer after reading
                                    s_axi_rresp <= RESP_OKAY; 
                                end else begin
                                    s_axi_rdata <= {DATA_WIDTH{1'b0}}; // Return zero if FIFO is empty_tx
                                    s_axi_rresp <= RESP_SLVERR; //response for empty_tx FIFO
                                end
                            end
                            ADDR_STATUS: begin
                                // Implement read logic for status register if needed
                            end
                            default: begin
                                    s_axi_rdata <= {DATA_WIDTH{1'b0}}; // Return zero if FIFO is empty_tx
                                    s_axi_rresp <= RESP_DECERR; // response for non existing address
                            end
                        endcase
                        rx_state <= RESP;
                        s_axi_rvalid <= 1'b1;
                    end
                end
                RESP: begin
                    if (s_axi_rready && s_axi_rvalid) begin
                        rx_state <= IDLE;
                        s_axi_rvalid <= 1'b0;
                        s_axi_arready <= 1'b1;
                    end
                end
            endcase
        end
    end

    // RX Buffer Write FSM

    always @(posedge int_clk)begin
        rx_ready <= !full_rx;
        if (rx_valid && rx_ready) begin
            mem_r[wr_ptr_rx[ADDR_WIDTH-1:0]] <= rx_data;   // Write data into FIFO from RX buffer
            wr_ptr_rx <= wr_ptr_rx + 1'b1;   // Increment write pointer after writing
        end
    end


endmodule

// Considerations for FIFO size 
// sprite1(a,1020,862)  max length of instruction   25 bytes