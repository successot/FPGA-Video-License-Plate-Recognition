

module gamma_lut #(
    parameter MEM_FILE = "gamma_0p8.mem"
)(
    input             clk,
    input      [7:0]  din,
    output reg [7:0]  dout
);
    reg [7:0] rom [0:255];

    initial begin
        $readmemh(MEM_FILE, rom);
    end

    always @(posedge clk) begin
        dout <= rom[din];
    end
endmodule
