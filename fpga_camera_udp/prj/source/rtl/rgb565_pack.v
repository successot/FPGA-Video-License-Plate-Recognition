

module rgb565_pack(
    input  [7:0]  r8,
    input  [7:0]  g8,
    input  [7:0]  b8,
    output [15:0] rgb565
);
    assign rgb565 = {r8[7:3], g8[7:2], b8[7:3]};
endmodule
