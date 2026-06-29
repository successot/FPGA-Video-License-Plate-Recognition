// -----------------------------------------------------------------------------
// File    : gamma_rgb565.v
// Function:
//   RGB565 gamma LUT processor with 1-cycle registered video stream interface.
//
// Interface is compatible with video_preprocess_top.v:
//
//   gamma_rgb565 u_gamma (
//       .clk(clk),
//       .rst_n(rst_n),
//       .in_valid(in_valid),
//       .in_href(in_href),
//       .in_vsync(in_vsync),
//       .in_rgb565(in_rgb565),
//       .gamma_sel(gamma_sel),
//       .out_valid(gamma_valid),
//       .out_href(gamma_href),
//       .out_vsync(gamma_vsync),
//       .out_rgb565(gamma_rgb565)
//   );
//
// gamma_sel:
//   2'd0 : raw bypass
//   2'd1 : gamma = 0.8, dark-scene enhancement
//   2'd2 : gamma = 1.2, bright-scene suppression
//   2'd3 : raw bypass, reserved
//
// Notes:
//   1. This file fixes the old undeclared identifiers:
//        pixel_in  -> in_rgb565
//        pixel_out -> out_rgb565
//        mode      -> gamma_sel
//   2. in_valid/in_href/in_vsync are registered by 1 clock to align with data.
//   3. Gamma is implemented with synthesizable LUT case tables, not pow().
// -----------------------------------------------------------------------------

module gamma_rgb565(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        in_valid,
    input  wire        in_href,
    input  wire        in_vsync,
    input  wire [15:0] in_rgb565,
    input  wire [1:0]  gamma_sel,

    output reg         out_valid,
    output reg         out_href,
    output reg         out_vsync,
    output reg  [15:0] out_rgb565
);

    // -------------------------------------------------------------------------
    // RGB565 split
    // -------------------------------------------------------------------------
    wire [4:0] r5_in;
    wire [5:0] g6_in;
    wire [4:0] b5_in;

    assign r5_in = in_rgb565[15:11];
    assign g6_in = in_rgb565[10:5];
    assign b5_in = in_rgb565[4:0];

    // -------------------------------------------------------------------------
    // 5-bit LUT for R/B channel
    // -------------------------------------------------------------------------
    function [4:0] gamma5_lut;
        input [4:0] din;
        input [1:0] sel;
        begin
            case (sel)
                2'd1: begin
                    case (din)
                    5'd0: gamma5_lut = 5'd0;
                    5'd1: gamma5_lut = 5'd2;
                    5'd2: gamma5_lut = 5'd3;
                    5'd3: gamma5_lut = 5'd5;
                    5'd4: gamma5_lut = 5'd6;
                    5'd5: gamma5_lut = 5'd7;
                    5'd6: gamma5_lut = 5'd8;
                    5'd7: gamma5_lut = 5'd9;
                    5'd8: gamma5_lut = 5'd10;
                    5'd9: gamma5_lut = 5'd12;
                    5'd10: gamma5_lut = 5'd13;
                    5'd11: gamma5_lut = 5'd14;
                    5'd12: gamma5_lut = 5'd15;
                    5'd13: gamma5_lut = 5'd15;
                    5'd14: gamma5_lut = 5'd16;
                    5'd15: gamma5_lut = 5'd17;
                    5'd16: gamma5_lut = 5'd18;
                    5'd17: gamma5_lut = 5'd19;
                    5'd18: gamma5_lut = 5'd20;
                    5'd19: gamma5_lut = 5'd21;
                    5'd20: gamma5_lut = 5'd22;
                    5'd21: gamma5_lut = 5'd23;
                    5'd22: gamma5_lut = 5'd24;
                    5'd23: gamma5_lut = 5'd24;
                    5'd24: gamma5_lut = 5'd25;
                    5'd25: gamma5_lut = 5'd26;
                    5'd26: gamma5_lut = 5'd27;
                    5'd27: gamma5_lut = 5'd28;
                    5'd28: gamma5_lut = 5'd29;
                    5'd29: gamma5_lut = 5'd29;
                    5'd30: gamma5_lut = 5'd30;
                    5'd31: gamma5_lut = 5'd31;
                        default: gamma5_lut = din;
                    endcase
                end

                2'd2: begin
                    case (din)
                    5'd0: gamma5_lut = 5'd0;
                    5'd1: gamma5_lut = 5'd1;
                    5'd2: gamma5_lut = 5'd1;
                    5'd3: gamma5_lut = 5'd2;
                    5'd4: gamma5_lut = 5'd3;
                    5'd5: gamma5_lut = 5'd3;
                    5'd6: gamma5_lut = 5'd4;
                    5'd7: gamma5_lut = 5'd5;
                    5'd8: gamma5_lut = 5'd6;
                    5'd9: gamma5_lut = 5'd7;
                    5'd10: gamma5_lut = 5'd8;
                    5'd11: gamma5_lut = 5'd9;
                    5'd12: gamma5_lut = 5'd10;
                    5'd13: gamma5_lut = 5'd11;
                    5'd14: gamma5_lut = 5'd12;
                    5'd15: gamma5_lut = 5'd13;
                    5'd16: gamma5_lut = 5'd14;
                    5'd17: gamma5_lut = 5'd15;
                    5'd18: gamma5_lut = 5'd16;
                    5'd19: gamma5_lut = 5'd17;
                    5'd20: gamma5_lut = 5'd18;
                    5'd21: gamma5_lut = 5'd19;
                    5'd22: gamma5_lut = 5'd21;
                    5'd23: gamma5_lut = 5'd22;
                    5'd24: gamma5_lut = 5'd23;
                    5'd25: gamma5_lut = 5'd24;
                    5'd26: gamma5_lut = 5'd25;
                    5'd27: gamma5_lut = 5'd26;
                    5'd28: gamma5_lut = 5'd27;
                    5'd29: gamma5_lut = 5'd29;
                    5'd30: gamma5_lut = 5'd30;
                    5'd31: gamma5_lut = 5'd31;
                        default: gamma5_lut = din;
                    endcase
                end

                default: begin
                    gamma5_lut = din;
                end
            endcase
        end
    endfunction

    // -------------------------------------------------------------------------
    // 6-bit LUT for G channel
    // -------------------------------------------------------------------------
    function [5:0] gamma6_lut;
        input [5:0] din;
        input [1:0] sel;
        begin
            case (sel)
                2'd1: begin
                    case (din)
                    6'd0: gamma6_lut = 6'd0;
                    6'd1: gamma6_lut = 6'd2;
                    6'd2: gamma6_lut = 6'd4;
                    6'd3: gamma6_lut = 6'd6;
                    6'd4: gamma6_lut = 6'd7;
                    6'd5: gamma6_lut = 6'd8;
                    6'd6: gamma6_lut = 6'd10;
                    6'd7: gamma6_lut = 6'd11;
                    6'd8: gamma6_lut = 6'd12;
                    6'd9: gamma6_lut = 6'd13;
                    6'd10: gamma6_lut = 6'd14;
                    6'd11: gamma6_lut = 6'd16;
                    6'd12: gamma6_lut = 6'd17;
                    6'd13: gamma6_lut = 6'd18;
                    6'd14: gamma6_lut = 6'd19;
                    6'd15: gamma6_lut = 6'd20;
                    6'd16: gamma6_lut = 6'd21;
                    6'd17: gamma6_lut = 6'd22;
                    6'd18: gamma6_lut = 6'd23;
                    6'd19: gamma6_lut = 6'd24;
                    6'd20: gamma6_lut = 6'd25;
                    6'd21: gamma6_lut = 6'd26;
                    6'd22: gamma6_lut = 6'd27;
                    6'd23: gamma6_lut = 6'd28;
                    6'd24: gamma6_lut = 6'd29;
                    6'd25: gamma6_lut = 6'd30;
                    6'd26: gamma6_lut = 6'd31;
                    6'd27: gamma6_lut = 6'd32;
                    6'd28: gamma6_lut = 6'd33;
                    6'd29: gamma6_lut = 6'd34;
                    6'd30: gamma6_lut = 6'd35;
                    6'd31: gamma6_lut = 6'd36;
                    6'd32: gamma6_lut = 6'd37;
                    6'd33: gamma6_lut = 6'd38;
                    6'd34: gamma6_lut = 6'd38;
                    6'd35: gamma6_lut = 6'd39;
                    6'd36: gamma6_lut = 6'd40;
                    6'd37: gamma6_lut = 6'd41;
                    6'd38: gamma6_lut = 6'd42;
                    6'd39: gamma6_lut = 6'd43;
                    6'd40: gamma6_lut = 6'd44;
                    6'd41: gamma6_lut = 6'd45;
                    6'd42: gamma6_lut = 6'd46;
                    6'd43: gamma6_lut = 6'd46;
                    6'd44: gamma6_lut = 6'd47;
                    6'd45: gamma6_lut = 6'd48;
                    6'd46: gamma6_lut = 6'd49;
                    6'd47: gamma6_lut = 6'd50;
                    6'd48: gamma6_lut = 6'd51;
                    6'd49: gamma6_lut = 6'd52;
                    6'd50: gamma6_lut = 6'd52;
                    6'd51: gamma6_lut = 6'd53;
                    6'd52: gamma6_lut = 6'd54;
                    6'd53: gamma6_lut = 6'd55;
                    6'd54: gamma6_lut = 6'd56;
                    6'd55: gamma6_lut = 6'd57;
                    6'd56: gamma6_lut = 6'd57;
                    6'd57: gamma6_lut = 6'd58;
                    6'd58: gamma6_lut = 6'd59;
                    6'd59: gamma6_lut = 6'd60;
                    6'd60: gamma6_lut = 6'd61;
                    6'd61: gamma6_lut = 6'd61;
                    6'd62: gamma6_lut = 6'd62;
                    6'd63: gamma6_lut = 6'd63;
                        default: gamma6_lut = din;
                    endcase
                end

                2'd2: begin
                    case (din)
                    6'd0: gamma6_lut = 6'd0;
                    6'd1: gamma6_lut = 6'd0;
                    6'd2: gamma6_lut = 6'd1;
                    6'd3: gamma6_lut = 6'd2;
                    6'd4: gamma6_lut = 6'd2;
                    6'd5: gamma6_lut = 6'd3;
                    6'd6: gamma6_lut = 6'd4;
                    6'd7: gamma6_lut = 6'd5;
                    6'd8: gamma6_lut = 6'd5;
                    6'd9: gamma6_lut = 6'd6;
                    6'd10: gamma6_lut = 6'd7;
                    6'd11: gamma6_lut = 6'd8;
                    6'd12: gamma6_lut = 6'd9;
                    6'd13: gamma6_lut = 6'd9;
                    6'd14: gamma6_lut = 6'd10;
                    6'd15: gamma6_lut = 6'd11;
                    6'd16: gamma6_lut = 6'd12;
                    6'd17: gamma6_lut = 6'd13;
                    6'd18: gamma6_lut = 6'd14;
                    6'd19: gamma6_lut = 6'd15;
                    6'd20: gamma6_lut = 6'd16;
                    6'd21: gamma6_lut = 6'd17;
                    6'd22: gamma6_lut = 6'd18;
                    6'd23: gamma6_lut = 6'd19;
                    6'd24: gamma6_lut = 6'd20;
                    6'd25: gamma6_lut = 6'd21;
                    6'd26: gamma6_lut = 6'd22;
                    6'd27: gamma6_lut = 6'd23;
                    6'd28: gamma6_lut = 6'd24;
                    6'd29: gamma6_lut = 6'd25;
                    6'd30: gamma6_lut = 6'd26;
                    6'd31: gamma6_lut = 6'd27;
                    6'd32: gamma6_lut = 6'd28;
                    6'd33: gamma6_lut = 6'd29;
                    6'd34: gamma6_lut = 6'd30;
                    6'd35: gamma6_lut = 6'd31;
                    6'd36: gamma6_lut = 6'd32;
                    6'd37: gamma6_lut = 6'd33;
                    6'd38: gamma6_lut = 6'd34;
                    6'd39: gamma6_lut = 6'd35;
                    6'd40: gamma6_lut = 6'd37;
                    6'd41: gamma6_lut = 6'd38;
                    6'd42: gamma6_lut = 6'd39;
                    6'd43: gamma6_lut = 6'd40;
                    6'd44: gamma6_lut = 6'd41;
                    6'd45: gamma6_lut = 6'd42;
                    6'd46: gamma6_lut = 6'd43;
                    6'd47: gamma6_lut = 6'd44;
                    6'd48: gamma6_lut = 6'd45;
                    6'd49: gamma6_lut = 6'd47;
                    6'd50: gamma6_lut = 6'd48;
                    6'd51: gamma6_lut = 6'd49;
                    6'd52: gamma6_lut = 6'd50;
                    6'd53: gamma6_lut = 6'd51;
                    6'd54: gamma6_lut = 6'd52;
                    6'd55: gamma6_lut = 6'd54;
                    6'd56: gamma6_lut = 6'd55;
                    6'd57: gamma6_lut = 6'd56;
                    6'd58: gamma6_lut = 6'd57;
                    6'd59: gamma6_lut = 6'd58;
                    6'd60: gamma6_lut = 6'd59;
                    6'd61: gamma6_lut = 6'd61;
                    6'd62: gamma6_lut = 6'd62;
                    6'd63: gamma6_lut = 6'd63;
                        default: gamma6_lut = din;
                    endcase
                end

                default: begin
                    gamma6_lut = din;
                end
            endcase
        end
    endfunction

    // -------------------------------------------------------------------------
    // Combinational LUT result
    // -------------------------------------------------------------------------
    wire [4:0] r5_gamma;
    wire [5:0] g6_gamma;
    wire [4:0] b5_gamma;

    assign r5_gamma = gamma5_lut(r5_in, gamma_sel);
    assign g6_gamma = gamma6_lut(g6_in, gamma_sel);
    assign b5_gamma = gamma5_lut(b5_in, gamma_sel);

    // -------------------------------------------------------------------------
    // 1-cycle output register.
    // Keep sync aligned with pixel data.
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid  <= 1'b0;
            out_href   <= 1'b0;
            out_vsync  <= 1'b0;
            out_rgb565 <= 16'd0;
        end else begin
            out_valid  <= in_valid;
            out_href   <= in_href;
            out_vsync  <= in_vsync;
            out_rgb565 <= {r5_gamma, g6_gamma, b5_gamma};
        end
    end

endmodule
