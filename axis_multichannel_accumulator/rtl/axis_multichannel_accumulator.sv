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
    output wire [OUTPUT_DATA_WIDTH-1:0]     m_axis_tdata,
    output wire                             m_axis_tvalid,
    output wire                             m_axis_tlast,
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
    reg reg_tlast = 0;
    reg reg_tvalid = 0;
    reg [OUTPUT_DATA_WIDTH-1:0] m_axis_tdata_int;
    reg last_dly = 0;

    wire buf_valid;
    wire [INPUT_DATA_WIDTH-1:0] buf_data;
    wire buf_last;

    wire s_axis_valid;
    wire signed [ACC_WIDTH-1:0] sum_wire;
    wire last;
    wire stall;
    wire nstall;

    integer i;
    initial begin
        for (i=0;i<CHANNELS;i=i+1)
            memory[i] = 0;
    end

    assign s_axis_valid = buf_valid && nstall && aresetn;
    assign sum_wire = $signed(mem_rddata) + $signed(input_data);
    assign last = (counter == (rate - 1));
    assign stall = reg_tvalid && !m_axis_tready;
    assign nstall = !stall;

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
        .m_axis_tready(nstall)
    );

    always @(posedge aclk)
        last_dly <= last;

    always @(*)
        if (last_dly) 
            mem_wrdata <= {ACC_WIDTH{1'b0}};
        else
            mem_wrdata <= sum_wire;

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
        end else if (buf_last) begin
            if (last)
                counter <= 0;
            else
                counter <= counter + 1;
        end
    end
    
    always @(posedge aclk) begin
        input_data <= buf_data;
        reg_tlast <= buf_last;

        mem_wraddr <= mem_rdaddr;
        mem_write <= buf_valid && nstall;
    end

    always @(posedge aclk)
        if (stall || (last && buf_valid))
            reg_tvalid <= 1'b1;
        else
            reg_tvalid <= 1'b0;

    always @(posedge aclk)
        m_axis_tdata_int <= sum_wire;

    always @(posedge aclk)
        mem_rddata <= memory[mem_rdaddr];    
    
    always @(posedge aclk)
        if (mem_write)
            memory[mem_wraddr] <= mem_wrdata;


    assign m_axis_tdata = sum_wire;
    assign m_axis_tlast = reg_tlast;
    assign m_axis_tvalid = reg_tvalid;


`ifdef COCOTB_SIM
initial begin
  $dumpfile ("axis_multichannel_accumulator.vcd");
  $dumpvars (0, axis_multichannel_accumulator);
  #1;
end
`endif

endmodule

`default_nettype wire
