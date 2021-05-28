`timescale 1ns / 1ps
`default_nettype none


module axis_bram_writer #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 16,
	parameter ADDR_WIDTH = 12,
	parameter OPT_TSTRB = 0,
    parameter OPT_TRIGGER = 0
)
(
    input  wire                         aclk,
    input  wire                         aresetn,

	input  wire 						trigger,
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

	wire active;

	generate if (OPT_TSTRB == 1) begin
		assign strb = {WSTRB_WIDTH{1'b0}};
	end else begin
		assign strb = {WSTRB_WIDTH{1'b1}};
	end endgenerate
	
	assign s_axis_valid = s_axis_tvalid && s_axis_tready;

	always_ff @(posedge aclk)
		bram_en <= aresetn & active & s_axis_valid;
			
	always_ff @(posedge aclk)
		if (!aresetn)
			bram_wrdata <= {DATA_WIDTH{1'b0}};
		else
			bram_wrdata <= s_axis_tdata;
	
	always_ff @(posedge aclk)
		if (!aresetn)
			bram_addr_next <= {ADDR_WIDTH{1'b0}};
		else if (active && s_axis_valid && s_axis_tlast)
			bram_addr_next <= {ADDR_WIDTH{1'b0}};
		else if (active && s_axis_valid)
			bram_addr_next <= bram_addr_next + 1;

	always_ff @(posedge aclk)
		if (!aresetn)
			bram_addr <= {ADDR_WIDTH{1'b0}};
		else
			bram_addr <= bram_addr_next;

	always_ff @(posedge aclk) begin
		if (!aresetn) begin
			bram_we <= {WSTRB_WIDTH{1'b0}};
		end else if (s_axis_valid) begin
			bram_we <= strb | s_axis_tstrb;
		end else begin
			bram_we <= {WSTRB_WIDTH{1'b0}};
		end
	end
		
	always_ff @(posedge aclk)
        interrupt <= s_axis_valid & s_axis_tlast & aresetn;


    generate if (OPT_TRIGGER == 0) begin
        assign active = 1'b1;
    end else begin
        reg  previous_trigger;
        wire pulse_trigger;
        reg  internal_trigger;
        reg  first_sample;

        wire primed;
        reg  running;

        assign pulse_trigger = trigger & !previous_trigger;
        assign primed = (internal_trigger | pulse_trigger) & first_sample;
        assign active = primed | running;

        always_ff @(posedge aclk)
            previous_trigger <= trigger;

        always_ff @(posedge aclk)
            if (!aresetn)
                internal_trigger <= 1'b0;
            else if (primed && s_axis_valid)
                internal_trigger <= 1'b0;
            else if (pulse_trigger)
                internal_trigger <= 1'b1;
        
        always_ff @(posedge aclk)
            if (!aresetn)
                running <= 1'b0;
            else if (s_axis_valid && s_axis_tlast)
                running <= 1'b0;
            else if (primed && s_axis_valid)
                running <= 1'b1;
        
        always_ff @(posedge aclk)
            if (!aresetn)
                first_sample <= 1'b0;
            else if (s_axis_valid)
                first_sample <= s_axis_tlast;
    end endgenerate

	always_comb
		bram_clk = aclk;
	
	assign s_axis_tready = aresetn;

endmodule

`default_nettype wire
