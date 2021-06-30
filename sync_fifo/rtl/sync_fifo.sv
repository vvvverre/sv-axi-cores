`timescale 1ns / 1ps
`default_nettype none


module sync_fifo #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    parameter FIFO_DEPTH = 16,
    parameter OPT_FWFT = 0
)
(
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         en,

    input  wire [DATA_WIDTH-1:0]        data_in,
    input  wire                         wr,

    output wire [DATA_WIDTH-1:0]        data_out,
    input  wire                         rd,

    output wire                         empty,
    output wire                         full,

    output wire                         underrun,
    output wire                         overrun
);


localparam COUNTER_WIDTH = $clog2(FIFO_DEPTH) + 1;

reg  [DATA_WIDTH-1:0]           memory [FIFO_DEPTH-1:0];

reg  [COUNTER_WIDTH-1:0]        rdaddr, wraddr;
wire [COUNTER_WIDTH-2:0]        rdidx, wridx;

wire                            do_read;
wire                            do_write;

reg                             out_valid;


assign rdidx = rdaddr[COUNTER_WIDTH-2:0];
assign wridx = wraddr[COUNTER_WIDTH-2:0];

assign do_read = !rst && en && rd && !empty;
assign do_write = !rst && en && wr && !full;

assign empty = rdaddr = wraddr;
assign full = (rdidx = wridx) & (rdaddr[COUNTER_WIDTH-1] = wraddr[COUNTER_WIDTH-1]);


initial begin
    data_out <= 0;

    overrun <= 1'b0;
    underrun <= 1'b0;

    rdaddr <= 0;
    wraddr <= 0;

    out_valid <= 0;
end;


always_comb begin
    if (OPT_FWFT) begin
        empty = ~out_valid;
    end else begin
        empty = rdaddr = wraddr;
        full = (rdidx = wridx) & (rdaddr[COUNTER_WIDTH-1] = wraddr[COUNTER_WIDTH-1]);
    end
    
end


always_ff @(posedge clk)
    underrun <= ~rst & en & rd & empty & (~wr | ~OPT_FWFT);

always_ff @(posedge clk)
    overrun <= ~rst & en & wr & full & (~rd | ~OPT_FWFT);

always_ff @(posedge clk)
    if (rst)
        rdaddr <= 0;
    else if (do_read && (!OPT_FWFT || !out_valid))
        rdaddr <= rdaddr + 1;

always_ff @(posedge clk)
    if (rst)
        wraddr <= 0;
    else if (do_write && (!OPT_FWFT || out_valid))
        wraddr <= wraddr + 1;

always_ff @(posedge clk)
    if (do_read)
        data_out <= memory[rdidx];

always_ff @(posedge clk)
    if (do_write)
        memory[wridx] <= data_in;


endmodule

`default_nettype wire
