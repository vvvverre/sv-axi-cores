`timescale 1ns / 1ps
`default_nettype none


module axis_packetizer #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 16,
    parameter COUNTER_WIDTH = 16,
    parameter OPT_REGISTER = 0
)
(
    input  wire                             aclk,
    input  wire                             aresetn,

    input  wire [COUNTER_WIDTH-1:0]         frame_length,

    /*
     * AXI-Stream slave interface
     */
    input  wire [DATA_WIDTH-1:0]            s_axis_tdata,
    input  wire                             s_axis_tvalid,
    output wire                             s_axis_tready,

    /*
     * AXI-Stream master interface
     */
    output reg  [DATA_WIDTH-1:0]            m_axis_tdata,
    output reg                              m_axis_tvalid,
    output reg                              m_axis_tlast,
    input  wire                             m_axis_tready
);

reg  [COUNTER_WIDTH-1:0]    int_frame_length = 0;
reg  [COUNTER_WIDTH-1:0]    counter = 0;

always_ff @(posedge aclk)
    if (counter == 0)
        int_frame_length <= frame_length - 1;

always_ff @(posedge aclk)
    if (!aresetn)
        counter <= 0;
    else if (m_axis_tvalid && m_axis_tready && m_axis_tlast)
        counter <= 0;
    else if (m_axis_tvalid && m_axis_tready)
        counter <= counter + 1;

generate if (OPT_REGISTER == 0) begin : COMBINATORIAL

    assign m_axis_tdata = s_axis_tdata;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tlast = (counter == int_frame_length);

    assign s_axis_tready = m_axis_tready;

end else begin : REGISTERED
    wire [DATA_WIDTH-1:0]   buf_tdata;
    wire                    buf_tvalid;
    wire                    stall;

    assign stall = m_axis_tvalid && !m_axis_tready;

    axis_skid_buffer 
    #(
        .DATA_WIDTH(DATA_WIDTH)
    ) buffer (   
        .aclk(aclk), 
        .aresetn(aresetn), 

        .s_axis_tdata(s_axis_tdata), 
        .s_axis_tvalid(s_axis_tvalid), 
        .s_axis_tready(s_axis_tready), 

        .m_axis_tdata(buf_tdata),
        .m_axis_tvalid(buf_tvalid),
        .m_axis_tready(!stall)
    );

    always_ff @(posedge aclk)
        m_axis_tvalid <= aresetn && (stall || buf_tvalid);
    
    always_ff @(posedge aclk)
        if (!stall)
            m_axis_tdata <= buf_tdata;

end endgenerate


`ifdef FORMAL
    reg	f_past_valid = 1'b0;
    always @(posedge aclk)
        f_past_valid <= 1'b1;

    always @(*)
        if (!f_past_valid)
            assume(!aresetn);
    
    always @(posedge aclk) begin
        if (f_past_valid && $past(aresetn)) begin
            if ($past(s_axis_tvalid && !s_axis_tready)) begin
                assume(s_axis_tvalid);
                assume($stable(s_axis_tdata));
            end

            if ($past(m_axis_tvalid && !m_axis_tready)) begin
                assert(m_axis_tvalid);
                assert($stable(m_axis_tdata));
                assert($stable(m_axis_tlast));
            end
        end
    end
`endif

endmodule

`default_nettype wire
