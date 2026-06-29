
module rgb565_unpack(
    input  [15:0] rgb565,
    output [7:0]  r8,
    output [7:0]  g8,
    output [7:0]  b8
);
    wire [4:0] r5 = rgb565[15:11];
    wire [5:0] g6 = rgb565[10:5];
    wire [4:0] b5 = rgb565[4:0];
    assign r8 = {r5, r5[4:2]};
    assign g8 = {g6, g6[5:4]};
    assign b8 = {b5, b5[4:2]};
endmodule
