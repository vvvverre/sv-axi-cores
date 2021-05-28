`timescale 1ns / 1ps
`default_nettype none


module axis_skid_buffer #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 16
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
    output reg  [DATA_WIDTH-1:0]    m_axis_tdata,
    output reg                      m_axis_tvalid,
    output reg                      m_axis_tlast,
    input  wire                     m_axis_tready
);

    reg [DATA_WIDTH-1:0]            r_data = {DATA_WIDTH{1'b0}};
    reg                             r_last = 0;
    reg                             r_valid = 0;


    always @(posedge aclk) begin
        if (!aresetn)
            r_valid <= 1'b0;
        else if ((s_axis_tvalid && s_axis_tready) && (m_axis_tvalid && !m_axis_tready))
            r_valid <= 1'b1;
        else if (m_axis_tready)
            r_valid <= 1'b0;
    end

    always @(posedge aclk)
        if (!aresetn)
            r_data <= {DATA_WIDTH{1'b0}};
        else if (s_axis_tvalid && s_axis_tready)
            r_data <= s_axis_tdata;

    always @(posedge aclk)
        if (!aresetn)
            r_last <= 1'b0;
        else if (s_axis_tvalid && s_axis_tready)
            r_last <= s_axis_tlast;

    // always @(*)
    //     s_axis_tready = !r_valid;

    always @(*)
        m_axis_tvalid = aresetn && (s_axis_tvalid || r_valid);
    
    always @(*)
        if (r_valid)
            m_axis_tdata = r_data;
        else
            m_axis_tdata = s_axis_tdata;

    always @(*)
        if (r_valid)
            m_axis_tlast = r_last;
        else
            m_axis_tlast = s_axis_tlast;

    assign s_axis_tready = !r_valid;

endmodule

`default_nettype wire
