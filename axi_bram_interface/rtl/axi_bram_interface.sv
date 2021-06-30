`timescale 1ns / 1ps
`default_nettype none


module axi_bram_interface #
(
    // Width of data bus in bits
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 12,
    parameter BRAM_DATA_WIDTH = 24
)
(
    input  wire                             aclk,
    input  wire                             aresetn,

    /*
     * AXI4-Lite Slave Interface
     */
    input  wire [AXI_ADDR_WIDTH-1:0]        s_axil_araddr,
    input  wire [2:0]                       s_axil_arprot,
    input  wire                             s_axil_arvalid,
    output reg                              s_axil_arready,

    output reg  [AXI_DATA_WIDTH-1:0]        s_axil_rdata,
    output reg  [1:0]                       s_axil_rresp,
    output reg                              s_axil_rvalid,
    input  wire                             s_axil_rready,

    input  wire [AXI_ADDR_WIDTH-1:0]        s_axil_awaddr,
    input  wire [2:0]                       s_axil_awprot,
    input  wire                             s_axil_awvalid,
    output reg                              s_axil_awready,

    input  wire [AXI_DATA_WIDTH-1:0]        s_axil_wdata,
    input  wire [AXI_DATA_WIDTH/8-1:0]      s_axil_wstrb,
    input  wire                             s_axil_wvalid,
    output reg                              s_axil_wready,

    output reg  [1:0]                       s_axil_bresp,
    output reg                              s_axil_bvalid,
    input  wire                             s_axil_bready,

    /*
     * BRAM interface
     */
    input  wire [BRAM_DATA_WIDTH-1:0]       bram_rddata,
    output reg  [BRAM_DATA_WIDTH-1:0]       bram_wrdata,
    output reg  [AXI_ADDR_WIDTH-2-1:0]	    bram_addr,
    output reg  [(BRAM_DATA_WIDTH+7)/8-1:0] bram_we,
	output reg  						    bram_en,
    output reg                              bram_clk
);

reg [AXI_DATA_WIDTH-1:0]        rdata_buf;
reg                             rdata_buf_valid;

wire                            bstall;
wire                            rstall;

wire                            read_eligible;
wire                            write_eligible;

wire [AXI_ADDR_WIDTH-2-1:0]     bram_wraddr;
wire [AXI_ADDR_WIDTH-2-1:0]     bram_rdaddr;


assign bstall = s_axil_bvalid && !s_axil_bready;
assign rstall = s_axil_rvalid && !s_axil_rready;

assign read_eligible  = s_axil_arvalid & !s_axil_arready & !rstall;
assign write_eligible = s_axil_awvalid & !s_axil_awready & s_axil_wvalid & !s_axil_wready & !bstall;

assign bram_wraddr = s_axil_awaddr[AXI_ADDR_WIDTH-1:2];
assign bram_rdaddr = s_axil_araddr[AXI_ADDR_WIDTH-1:2];

always_ff @(posedge aclk) begin
    s_axil_arready <= aresetn & read_eligible;
    s_axil_rvalid <= aresetn & (read_eligible | rstall);

    s_axil_awready <= aresetn & write_eligible & !read_eligible;
    s_axil_wready <= aresetn & write_eligible & !read_eligible;
    s_axil_bvalid <= aresetn & ((write_eligible & !read_eligible) | bstall);

    if (!rstall)
        rdata_buf <= bram_rddata;
end

always_comb begin
    bram_wrdata = s_axil_wdata;
    bram_en = write_eligible | read_eligible;
    bram_clk = aclk;

    if (write_eligible && !read_eligible) begin
        bram_addr = bram_wraddr;
        bram_we = s_axil_wstrb;
    end else begin
        bram_addr = bram_rdaddr;
        bram_we = 0;
    end

    if (!rstall)
        s_axil_rdata = bram_rddata;
    else
        s_axil_rdata = rdata_buf;

    s_axil_bresp = 2'b00;
    s_axil_rresp = 2'b00;
end

endmodule

`default_nettype wire
