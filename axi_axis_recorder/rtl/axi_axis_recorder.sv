`timescale 1ns / 1ps
`default_nettype none


module axi_axis_recorder #
(
    // Width of data bus in bits
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 14,
    parameter DATA_WIDTH = 24,
    parameter OPT_TSTRB = 0,
    parameter OPT_TRIGGER = 1
)
(
    input  wire                             aclk,
    input  wire                             aresetn,

    input  wire                             enable,
	input  wire 						    trigger,
	output wire 						    interrupt,

    /*
     * AXI4-Lite Slave Interface
     */
    input  wire [AXI_ADDR_WIDTH-1:0]        s_axil_araddr,
    input  wire [2:0]                       s_axil_arprot,
    input  wire                             s_axil_arvalid,
    output wire                             s_axil_arready,

    output wire [AXI_DATA_WIDTH-1:0]        s_axil_rdata,
    output wire [1:0]                       s_axil_rresp,
    output wire                             s_axil_rvalid,
    input  wire                             s_axil_rready,

    input  wire [AXI_ADDR_WIDTH-1:0]        s_axil_awaddr,
    input  wire [2:0]                       s_axil_awprot,
    input  wire                             s_axil_awvalid,
    output wire                             s_axil_awready,

    input  wire [AXI_DATA_WIDTH-1:0]        s_axil_wdata,
    input  wire [AXI_DATA_WIDTH/8-1:0]      s_axil_wstrb,
    input  wire                             s_axil_wvalid,
    output wire                             s_axil_wready,

    output wire [1:0]                       s_axil_bresp,
    output wire                             s_axil_bvalid,
    input  wire                             s_axil_bready,

    /*
     * AXI4-Stream Slave Interface
     */
    input  wire [DATA_WIDTH-1:0]  		    s_axis_tdata,
	input  wire [(DATA_WIDTH)/8-1:0]	    s_axis_tstrb,
    input  wire                             s_axis_tvalid,
    input  wire                             s_axis_tlast,
    output wire                             s_axis_tready
);


wire [DATA_WIDTH-1:0]           bram_ina;
wire [DATA_WIDTH-1:0]           bram_outa;
wire [AXI_ADDR_WIDTH-2-1:0]     bram_addra;
wire [DATA_WIDTH/8-1:0]         bram_wea;
wire                            bram_ena;
wire                            bram_clka;

wire [DATA_WIDTH-1:0]           bram_inb;
wire [AXI_ADDR_WIDTH-2-1:0]     bram_addrb;
wire [DATA_WIDTH/8-1:0]         bram_web;
wire                            bram_enb;
wire                            bram_clkb;


axi_bram_interface
#(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
) axi_interface (
    .aclk(aclk), 
    .aresetn(aresetn), 

    .s_axil_araddr(s_axil_araddr),
    .s_axil_arprot(s_axil_arprot),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),

    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready),

    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awprot(s_axil_awprot),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),

    .s_axil_wdata(s_axil_wdata),
    .s_axil_wstrb(s_axil_wstrb),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),

    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),

    .bram_rddata(bram_outa),
    .bram_wrdata(bram_ina),
    .bram_addr(bram_addra),
    .bram_we(bram_wea),
    .bram_en(bram_ena),
    .bram_clk(bram_clka)
);

axis_bram_writer
#(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(AXI_ADDR_WIDTH-2),
    .OPT_TSTRB(OPT_TSTRB),
    .OPT_TRIGGER(OPT_TRIGGER)
) bram_writer (
    .aclk(aclk), 
    .aresetn(enable & aresetn), 

    .trigger(trigger),
    .interrupt(interrupt),

    .s_axis_tdata(s_axis_tdata),
    .s_axis_tstrb(s_axis_tstrb),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tready(s_axis_tready),

    .bram_wrdata(bram_inb),
    .bram_addr(bram_addrb),
    .bram_we(bram_web),
    .bram_en(bram_enb),
    .bram_clk(bram_clkb)
);

bram
#(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(AXI_ADDR_WIDTH-2)
) memory (
    .clka(bram_clka),
    .rsta(1'b0),
    .ina(bram_ina),
    .outa(bram_outa),
    .addra(bram_addra),
    .wea(bram_wea),
    .ena(bram_ena),

    .clkb(bram_clkb),
    .rstb(1'b0),
    .inb(bram_inb),
    .addrb(bram_addrb),
    .web(bram_web),
    .enb(bram_enb)
);

endmodule

`default_nettype wire
