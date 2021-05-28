`timescale 1ns / 1ps
`default_nettype none


module axis_bram_reader #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 16,
	parameter ADDR_WIDTH = 12
)
(
    input  wire                         aclk,
    input  wire                         aresetn,

    input  wire [ADDR_WIDTH-1:0]        limit,

    /*
     * AXI-Stream slave interface
     */
    output reg  [DATA_WIDTH-1:0]  		m_axis_tdata,
    output reg                          m_axis_tvalid,
    output reg                          m_axis_tlast,
    input  wire                         m_axis_tready,

    /*
     * BRAM interface
     */
    input  wire [DATA_WIDTH-1:0]     	bram_rddata,
    output reg  [ADDR_WIDTH-1:0]		bram_addr,
    output reg  [(DATA_WIDTH)/8-1:0]   	bram_we,
	output reg  						bram_en,
    output reg                          bram_clk
);


    wire m_axis_valid;
    wire last;
    wire stall;


	reg  [ADDR_WIDTH-1:0] bram_addr_next = 0;
    reg  [ADDR_WIDTH-1:0] internal_limit = 0;
    reg  [DATA_WIDTH-1:0] rddata_buf = 0;
    reg  tvalid_next = 1'b0;
    reg  stall_prev = 1'b0;

	assign m_axis_valid = m_axis_tvalid && m_axis_tready;
    assign last = aresetn && (bram_addr == internal_limit);
    assign stall = m_axis_tvalid && !m_axis_tready;
	
    initial begin
        m_axis_tdata <= {DATA_WIDTH{1'b0}};
        m_axis_tvalid <= 1'b0;
        m_axis_tlast <= 1'b0;

        bram_addr <= {ADDR_WIDTH{1'b0}};
        bram_we <= 0;
        bram_en <= 1'b0;
        bram_clk <= 1'b0;
    end

    always_ff @(posedge aclk)
        stall_prev <= stall;

    always_ff @(posedge aclk)
        if (bram_addr == 0)
            internal_limit <= limit - 1;

	always_comb
		if (!aresetn)
			bram_addr_next <= {ADDR_WIDTH{1'b0}};
		else if (last)
			bram_addr_next <= {ADDR_WIDTH{1'b0}};
		else
			bram_addr_next <= bram_addr + 1;

	always_ff @(posedge aclk)
		if (!aresetn)
			bram_addr <= {ADDR_WIDTH{1'b0}};
		else if (!stall)
			bram_addr <= bram_addr_next;
    
    always_ff @(posedge aclk)
        if (!aresetn)
            rddata_buf <= {DATA_WIDTH{1'b0}};
        else if (!stall_prev)
            rddata_buf <= bram_rddata;

	always_comb
		if (!aresetn)
			m_axis_tdata <= {DATA_WIDTH{1'b0}};
		else if (stall_prev)
			m_axis_tdata <= rddata_buf;
        else
            m_axis_tdata <= bram_rddata;

	always_ff @(posedge aclk)
        m_axis_tvalid <= aresetn;

	always_ff @(posedge aclk)
        tvalid_next <= aresetn;

	always_ff @(posedge aclk)
        if (!aresetn)
            m_axis_tlast <= 1'b0;
        else if (!stall)
            m_axis_tlast <= last;

	always_comb
        bram_we <= 0;
	
	always_comb
		bram_clk = aclk;

	always_comb
        bram_en = aresetn;

endmodule

`default_nettype wire
