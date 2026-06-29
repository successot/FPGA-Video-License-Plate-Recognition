

module rgb565_to_gray(
    input  [15:0] rgb565,
    output [7:0]  y
);
    wire [7:0] r8;
    wire [7:0] g8;
    wire [7:0] b8;
    wire [15:0] y_tmp;

    rgb565_unpack u_unpack(.rgb565(rgb565), .r8(r8), .g8(g8), .b8(b8));

    assign y_tmp = (r8 * 8'd77) + (g8 * 8'd150) + (b8 * 8'd29);
    assign y = y_tmp[15:8];
endmodule
