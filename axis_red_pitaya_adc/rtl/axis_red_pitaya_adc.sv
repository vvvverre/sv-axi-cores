`timescale 1ns / 1ps
`default_nettype none


module axis_red_pitaya_adc #
(
    // Width of data bus in bits
    parameter ADC_DATA_WIDTH = 16,
    parameter AXIS_DATA_WIDTH = 16
)
(
    input  wire                             aclk,
    input  wire                             aresetn,

    input  wire [ADC_DATA_WIDTH-1:0]        adc_in,

    /*
     * AXI-Stream master interface
     */
    output reg  [AXIS_DATA_WIDTH-1:0]       m_axis_tdata,
    output reg                              m_axis_tvalid,
    input  wire                             m_axis_tready
);

localparam PAD_WIDTH = AXIS_DATA_WIDTH - ADC_DATA_WIDTH;


reg  [ADC_DATA_WIDTH-1:0]   adc_reg;
wire                        stall;

assign stall = m_axis_tvalid & ~m_axis_tready;

always_ff @(posedge aclk)
    if (!aresetn)
        adc_reg <= {ADC_DATA_WIDTH{1'b0}};
    else if (!stall)
        adc_reg <= adc_in;

always_comb
    m_axis_tdata = {{(PAD_WIDTH+1){~adc_reg[ADC_DATA_WIDTH-1]}}, adc_reg[ADC_DATA_WIDTH-2:0]};

always_ff
    m_axis_tvalid <= aresetn;

endmodule

`default_nettype wire

