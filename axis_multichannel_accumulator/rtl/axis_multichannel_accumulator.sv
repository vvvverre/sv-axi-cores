`timescale 1ns / 1ps
`default_nettype none


module axis_multichannel_accumulator #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 16,
    parameter CHANNELS = 1024
)
(
    input  wire                     aclk,
    input  wire                     aresetn,

    /*
     * AXI-Stream slave interface
     */
    input  wire [DATA_WIDTH-1:0]    s_axis_tdata,
    input  wire                     s_axis_tvalid,
    input  wire                     s_axis_tlast,
    output wire                     s_axis_tready,

    /*
     * AXI-Stream master interface
     */
    output wire [DATA_WIDTH-1:0]    m_axis_tdata,
    output wire                     m_axis_tvalid,
    output wire                     m_axis_tlast,
    input  wire                     m_axis_tready
);

    localparam COUNTER_WIDTH = $clog2(CHANNELS);

    reg [COUNTER_WIDTH-1:0] counter = {COUNTER_WIDTH{1'b0}};
    reg [DATA_WIDTH-1:0] memory [CHANNELS-1:0];
    
    reg [DATA_WIDTH-1:0] mem_rddata = {DATA_WIDTH{1'b0}};
    reg mem_write = 0;

    reg [COUNTER_WIDTH-1:0] mem_wraddr = {COUNTER_WIDTH{1'b0}};
    reg [DATA_WIDTH-1:0] mem_wrdata = {DATA_WIDTH{1'b0}};

    reg [DATA_WIDTH-1:0] input_data = {DATA_WIDTH{1'b0}};

    wire s_axis_valid;
    wire [DATA_WIDTH:0] sum_wire;

    assign s_axis_valid = s_axis_tvalid && s_axis_tready && aresetn;
    assign sum_wire = mem_rddata + input_data;

    always @(posedge aclk)
        if (!aresetn)
            counter <= {COUNTER_WIDTH{1'b0}};
        else if (s_axis_valid)
            counter <= counter + 1;
    
    always @(posedge aclk)
        input_data <= s_axis_tdata;

    always @(posedge aclk)
        mem_rddata <= memory[counter];    
    
    always @(posedge aclk)
        if (mem_write)
            memory[mem_wraddr] <= mem_wrdata;


endmodule

`default_nettype wire
