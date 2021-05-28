`timescale 1ns / 1ps
`default_nettype none


module axis_bram_writer #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 16,
	parameter ADDR_WIDTH = 12,
	parameter OPT_TSTRB = 0
)
(
    input  wire                         aclk,
    input  wire                         aresetn,

	output reg							interrupt,

    /*
     * AXI-Stream slave interface
     */
    input  wire [DATA_WIDTH-1:0]  		s_axis_tdata,
	input  wire [(DATA_WIDTH)/8-1:0]	s_axis_tstrb,
    input  wire                         s_axis_tvalid,
    input  wire                         s_axis_tlast,
    output wire                         s_axis_tready,

    /*
     * BRAM interface
     */
    output reg  [DATA_WIDTH-1:0]     	bram_wrdata,
    output reg  [ADDR_WIDTH-1:0]		bram_addr,
    output reg  [(DATA_WIDTH)/8-1:0]   	bram_we,
	output reg  						bram_en,
    output reg                          bram_clk
);

	localparam WSTRB_WIDTH = (DATA_WIDTH)/8;

	wire s_axis_valid;
	wire [WSTRB_WIDTH-1:0] strb;
	reg  [ADDR_WIDTH-1:0] bram_addr_next;

	generate if (OPT_TSTRB == 1) begin
		assign strb = {WSTRB_WIDTH{1'b0}};
	end else begin
		assign strb = {WSTRB_WIDTH{1'b1}};
	end endgenerate
	
	assign s_axis_valid = s_axis_tvalid && s_axis_tready;

	always_ff @(posedge aclk)
		if (!aresetn)
			bram_en <= 1'b0;
		else
			bram_en <= s_axis_valid;
			
	always_ff @(posedge aclk)
		if (!aresetn)
			bram_wrdata <= {DATA_WIDTH{1'b0}};
		else
			bram_wrdata <= s_axis_tdata;
	
	always_ff @(posedge aclk)
		if (!aresetn)
			bram_addr_next <= {ADDR_WIDTH{1'b0}};
		else if (s_axis_valid && s_axis_tlast)
			bram_addr_next <= {ADDR_WIDTH{1'b0}};
		else if (s_axis_valid)
			bram_addr_next <= bram_addr_next + 1;

	always_ff @(posedge aclk)
		if (!aresetn)
			bram_addr <= {ADDR_WIDTH{1'b0}};
		else
			bram_addr <= bram_addr_next;
		
	always_ff @(posedge aclk)
		if (!aresetn)
			interrupt <= 1'b0;
		else
			interrupt <= s_axis_valid && s_axis_tlast;

	always_ff @(posedge aclk) begin
		if (!aresetn) begin
			bram_we <= {WSTRB_WIDTH{1'b0}};
		end else if (s_axis_valid) begin
			bram_we <= strb | s_axis_tstrb;
		end else begin
			bram_we <= {WSTRB_WIDTH{1'b0}};
		end
	end
	
	always_comb
		bram_clk = aclk;
	
	assign s_axis_tready = aresetn;

endmodule

`default_nettype wire
