`timescale 1ns / 1ps
`default_nettype none


module bram #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 12,
    localparam WE_WIDTH = (DATA_WIDTH + 4)/8
)
(

    /*
     * BRAM interface A
     */
    input  wire                         clka,
    input  wire                         rsta,
    input  wire [DATA_WIDTH-1:0]        ina,
    output reg  [DATA_WIDTH-1:0]        outa,
    input  wire [ADDR_WIDTH-1:0]	    addra,
    input  wire [WE_WIDTH-1:0]          wea,
	input  wire 						ena,

    /*
     * BRAM interface B
     */
    input  wire                         clkb,
    input  wire                         rstb,
    input  wire [DATA_WIDTH-1:0]        inb,
    output reg  [DATA_WIDTH-1:0]        outb,
    input  wire [ADDR_WIDTH-1:0]	    addrb,
    input  wire [WE_WIDTH-1:0]          web,
	input  wire 						enb
);

reg [DATA_WIDTH-1:0] memory [(2**ADDR_WIDTH)-1:0];
genvar ii;

initial begin
    outa = {DATA_WIDTH{1'b0}};
    outb = {DATA_WIDTH{1'b0}};

    for (int ii = 0; ii < 2**ADDR_WIDTH; ii = ii + 1) begin
        memory[ii] = {DATA_WIDTH{1'b0}};
    end
end

always_ff @(posedge clka)
    if (ena)
        if (rsta)
            outa <= {DATA_WIDTH{1'b0}};
        else
            outa <= memory[addra];

generate for (ii = 0; ii < WE_WIDTH; ii = ii + 1) begin
    always_ff @(posedge clka) begin
        if (ena & wea[ii])
            memory[addra][(ii+1)*8-1:ii*8] <= ina[(ii+1)*8-1:ii*8];
    end
end endgenerate

always_ff @(posedge clkb)
    if (enb)
        if (rstb)
            outb <= {DATA_WIDTH{1'b0}};
        else
            outb <= memory[addrb];

generate for (ii = 0; ii < WE_WIDTH; ii = ii + 1) begin
    always_ff @(posedge clkb)
        if (enb & web[ii])
            memory[addrb][(ii+1)*8-1:ii*8] <= inb[(ii+1)*8-1:ii*8];
end endgenerate

endmodule

`default_nettype wire
