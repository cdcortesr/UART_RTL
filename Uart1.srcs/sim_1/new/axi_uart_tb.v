// ============================================================================
//     axi_uart_tb                                                     
//     Testbench for AXI UART and submodules                                                         
// ============================================================================
//  Engineer   : Chris C.              2026-11-08
// ----------------------------------------------------------------------------

`timescale 1ns / 1ps


module axi_uart_tb(
    );

    localparam CLK_FREQ = 100_000_000;
    localparam CLK_PERIOD_NS = 1.0e9 / CLK_FREQ;
    localparam INT_CLK_FREQ = 20_000_000;   // Assuming same frequency as s_axi_aclk
    localparam INT_CLK_PERIOD_NS = 1.0e9 / INT_CLK_FREQ;

    reg s_axi_aclk;
    reg s_axi_aresetn;
    reg s_axi_awaddr;
    reg s_axi_awvalid;
    reg [2:0] s_axi_awprot;
    wire s_axi_awready;
    reg [31:0] s_axi_wdata;
    reg [3:0] s_axi_wstrb;
    reg s_axi_wvalid;
    wire s_axi_wready;

    reg s_axi_bready;
    wire s_axi_bvalid;
    wire [1:0] s_axi_bresp;

    reg [5:0] s_axi_araddr;
    reg s_axi_arvalid;
    wire s_axi_arready;
    reg [2:0] s_axi_arprot;
    reg s_axi_rready;
    wire s_axi_rvalid;
    wire [31:0] s_axi_rdata;
    wire [1:0] s_axi_rresp;

    reg int_clk;
    reg tx_ready;
    wire tx_valid;
    wire [7:0] tx_data;
    reg [7:0] rx_data;
    reg rx_valid;
    wire rx_ready;

    localparam ADDR_TX_BUFF   = 6'h00;     
    localparam ADDR_RX_BUFF   = 6'h04;
    localparam ADDR_STATUS    = 6'h08;

    axi_fifo_tx uut
    (
        .s_axi_aclk(s_axi_aclk),
        .s_axi_aresetn(s_axi_aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        //.s_axi_awprot(s_axi_awprot),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bready(s_axi_bready),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        //.s_axi_arprot(s_axi_arprot),
        .s_axi_rready(s_axi_rready),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .int_clk(int_clk),
        .tx_ready(tx_ready),
        .tx_valid(tx_valid),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_ready(rx_ready)
    );

    always #(CLK_PERIOD_NS / 2) s_axi_aclk = ~s_axi_aclk;
    always #(INT_CLK_PERIOD_NS / 2) int_clk = ~int_clk;

    initial begin
        s_axi_aclk = 0;
        int_clk = 0;
    end

    initial begin
        s_axi_aresetn = 0;
        # (CLK_PERIOD_NS * 5);
        s_axi_aresetn = 1;

        # (CLK_PERIOD_NS * 5);

        s_axi_awaddr = ADDR_TX_BUFF;
        s_axi_awvalid = 1;
        s_axi_awprot = 0;

        # (CLK_PERIOD_NS * 5);

        s_axi_wdata = 8'hAA;
        s_axi_wstrb = 4'hF;
        s_axi_wvalid = 1;

        wait (s_axi_bvalid == 1);
        s_axi_bready = 1;
        # (CLK_PERIOD_NS * 5);


    end

    always @(posedge s_axi_aclk) begin
        if (s_axi_bvalid == 1 && s_axi_bready == 1) begin
            s_axi_bready <= 0;
        end 
    end

    initial begin
        tx_ready = 0;
        rx_valid = 0;
        rx_data = 8'h00;
    end

    initial begin
        s_axi_awaddr = 0;
        s_axi_awvalid = 0;
        s_axi_awprot = 0;
        s_axi_wdata = 0;
        s_axi_wstrb = 0;
        s_axi_wvalid = 0;
        s_axi_bready = 0;
        s_axi_araddr = 0;
        s_axi_arvalid = 0;
        s_axi_arprot = 0;
        s_axi_rready = 0;
    end





endmodule
