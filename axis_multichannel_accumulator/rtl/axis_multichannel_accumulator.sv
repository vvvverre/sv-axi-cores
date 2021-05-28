`timescale 1ns / 1ps
`default_nettype none


module axis_multichannel_accumulator #
(
    // Width of data bus in bits
    parameter INPUT_DATA_WIDTH = 16,
    parameter OUTPUT_DATA_WIDTH = 24,
    parameter CHANNELS = 1024,
    parameter RATE_WIDTH = 8
)
(
    input  wire                             aclk,
    input  wire                             aresetn,

    input  wire [RATE_WIDTH-1:0]            rate,

    /*
     * AXI-Stream slave interface
     */
    input  wire [INPUT_DATA_WIDTH-1:0]      s_axis_tdata,
    input  wire                             s_axis_tvalid,
    input  wire                             s_axis_tlast,
    output wire                             s_axis_tready,

    /*
     * AXI-Stream master interface
     */
    output reg  [OUTPUT_DATA_WIDTH-1:0]     m_axis_tdata,
    output reg                              m_axis_tvalid,
    output reg                              m_axis_tlast,
    input  wire                             m_axis_tready
);

    localparam ADDR_WIDTH = $clog2(CHANNELS);
    localparam ACC_WIDTH = INPUT_DATA_WIDTH + RATE_WIDTH;

    reg [RATE_WIDTH-1:0] counter = {RATE_WIDTH{1'b0}};

    reg [ACC_WIDTH-1:0] memory [CHANNELS-1:0];
    
    reg [ADDR_WIDTH-1:0] mem_rdaddr = {ADDR_WIDTH{1'b0}};
    reg [ACC_WIDTH-1:0] mem_rddata = {ACC_WIDTH{1'b0}};

    reg mem_write = 0;
    reg [ADDR_WIDTH-1:0] mem_wraddr = {ADDR_WIDTH{1'b0}};
    reg [ACC_WIDTH-1:0] mem_wrdata = {ACC_WIDTH{1'b0}};

    reg [INPUT_DATA_WIDTH-1:0] input_data = {INPUT_DATA_WIDTH{1'b0}};
    reg counter_zero_dly = 0;

    wire buf_valid;
    wire [INPUT_DATA_WIDTH-1:0] buf_data;
    wire buf_last;

    wire s_axis_valid;
    wire signed [ACC_WIDTH-1:0] sum_wire;
    wire last;
    wire stall;

    integer i;
    initial begin
        for (i=0;i<CHANNELS;i=i+1)
            memory[i] = 0;
    end

    assign s_axis_valid = buf_valid && !stall && aresetn;
    assign sum_wire = $signed(mem_rddata) + ACC_WIDTH'($signed(input_data));
    assign last = (counter == (rate - 1));
    assign stall = m_axis_tvalid && !m_axis_tready;

    axis_skid_buffer 
    #(
        .DATA_WIDTH(INPUT_DATA_WIDTH)
    ) buffer (   
        .aclk(aclk), 
        .aresetn(aresetn), 

        .s_axis_tdata(s_axis_tdata), 
        .s_axis_tvalid(s_axis_tvalid), 
        .s_axis_tready(s_axis_tready), 
        .s_axis_tlast(s_axis_tlast), 

        .m_axis_tdata(buf_data),
        .m_axis_tvalid(buf_valid), 
        .m_axis_tlast(buf_last), 
        .m_axis_tready(!stall)
    );

    always @(posedge aclk)
        counter_zero_dly <= (counter == 0);

    always @(*)
        if (counter_zero_dly) 
            mem_wrdata = ACC_WIDTH'($signed(input_data));
        else
            mem_wrdata = sum_wire;

    always @(posedge aclk) begin
        if (!aresetn) begin
            mem_rdaddr <= {ADDR_WIDTH{1'b0}};
        end else if (s_axis_valid) begin
            if (buf_last) begin
                mem_rdaddr <= {ADDR_WIDTH{1'b0}};            
            end else begin
                mem_rdaddr <= mem_rdaddr + 1;
            end
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            counter <= 0;
        end else if (buf_last && !stall) begin
            if (last)
                counter <= 0;
            else
                counter <= counter + 1;
        end
    end
    
    always @(posedge aclk)
        if (!stall)
            input_data <= buf_data;

    always @(posedge aclk)
        if (!stall)
            m_axis_tlast <= buf_last;

    always @(*)
        m_axis_tdata = sum_wire;

    always @(posedge aclk)
        if (stall || (last && buf_valid))
            m_axis_tvalid <= 1'b1;
        else
            m_axis_tvalid <= 1'b0;

    always @(posedge aclk)
        mem_wraddr <= mem_rdaddr;

    always @(posedge aclk)
        mem_write <= buf_valid && !stall;

    always @(posedge aclk)
        if (!stall)
            mem_rddata <= memory[mem_rdaddr];    
    
    always @(posedge aclk)
        if (mem_write)
            memory[mem_wraddr] <= mem_wrdata;


    // assign m_axis_tdata = sum_wire;


`ifdef COCOTB_SIM
initial begin
  $dumpfile ("axis_multichannel_accumulator.vcd");
  $dumpvars (0, axis_multichannel_accumulator);
  //#1;
end
`endif

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
                assume($stable(s_axis_tlast));
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
