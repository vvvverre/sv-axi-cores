`timescale 1ns / 1ps
`default_nettype none


module axi_bram_interface #
(
    // Width of data bus in bits
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 16
)
(
    input  wire                             aclk,
    input  wire                             aresetn,

    /*
     * AXI4-Lite Slave Interface
     */
    input  wire [AXI_ADDR_WIDTH-1:0]        s_axil_araddr,
    input  wire                             s_axil_arvalid,
    output reg                              s_axil_arready,

    output reg  [AXI_DATA_WIDTH-1:0]        s_axil_rdata,
    output reg  [1:0]                       s_axil_rresp,
    output reg                              s_axil_rvalid,
    input  wire                             s_axil_rready,

    input  wire [AXI_ADDR_WIDTH-1:0]        s_axil_awaddr,
    input  wire                             s_axil_awvalid,
    output reg                              s_axil_awready,

    input  wire [AXI_DATA_WIDTH-1:0]        s_axil_wdata,
    input  wire [AXI_DATA_WIDTH/8-1:0]      s_axil_wstrb,
    input  wire                             s_axil_wvalid,
    output wire                             s_axil_wready,

    output wire [1:0]                       s_axil_bresp,
    output wire                             s_axil_bvalid,
    input  wire                             s_axil_bready,

    /*
     * BRAM interface
     */
    input  wire [DATA_WIDTH-1:0]     	    bram_rddata,
    output reg  [DATA_WIDTH-1:0]     	    bram_wrdata,
    output reg  [ADDR_WIDTH-1:0]		    bram_addr,
    output reg  [(DATA_WIDTH)/8-1:0]   	    bram_we,
	output reg  						    bram_en,
    output reg                              bram_clk
);

reg  [DATA_WIDTH-1:0]   rdata_buf;
reg                     rdata_buf_valid;

wire                    write;
wire                    bstall;
wire                    rstall;

assign write = s_axil_awvalid & s_axil_awready & s_axil_wvalid & s_axil_wready;

assign bstall = s_axil_bvalid && !s_axil_bready;
assign rstall = s_axil_rvalid && !s_axil_rready;


always_comb
    if (!aresetn)
        bram_addr <= 0;
    else if (write)
        bram_addr <= s_axil_awaddr;
    else
        bram_addr <= s_axil_araddr;

always_ff @(posedge aclk)
    if (!rdata_buf_valid)
        rdata_buf <= bram_rddata;

always_ff @(posedge aclk)
    if (s_axil_arvalid && s_axil_arready)
        rdata_buf_valid <= 1'b1;
    else if (s_axil_rvalid && s_axil_rready)
        rdata_buf_valid <= 1'b0;

always_ff @(posedge aclk)
    if (!aresetn)
        s_axil_rvalid <= 1'b0;
    else if ((s_axil_arvalid && s_axil_arready) || rstall)
        s_axil_rvalid <= 1'b1;
    else
        s_axil_rvalid <= 1'b0;

always_comb
    if (rdata_buf_valid)
        s_axil_rdata <= rdata_buf;
    else
        s_axil_rdata <= bram_rddata;

always_ff @(posedge aclk)
    s_axil_arready <= aresetn & s_axil_arvalid;

always_ff @(posedge aclk)
    s_axil_awready <= aresetn & s_axil_awvalid s_axil_wvalid & !s_axil_arvalid;
    
always_ff @(posedge aclk)
    s_axil_wready <= aresetn & s_axil_awvalid s_axil_wvalid & !s_axil_arvalid;
    
always_ff @(posedge aclk)
    if (write)
        bram_wrdata <= s_axil_wdata;

always_ff @(posedge aclk)
    if (write)
        bram_we <= s_axil_wstrb;
    else
        bram_we <= 0;

always_ff @(posedge aclk)
    bram_en <= 1'b1;

always_ff @(posedge aclk)
    s_axil_bvalid <= write | bstall;

always_comb
    s_axil_bresp <= 2'b00;

always_comb
    s_axil_rresp <= 2'b00;

always_comb
    bram_clk <= aclk;

endmodule

`default_nettype wire
