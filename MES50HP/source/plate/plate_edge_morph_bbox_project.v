// -----------------------------------------------------------------------------
// plate_edge_morph_bbox_project.v
// PLATE_V1_STEP4: usable-edge morphology + row/column projection bbox detector.
//
// Input:
//   Aligned STEP3_FIX6 usable_edge stream with local coordinates.
//
// Processing:
//   1. Horizontal dilation H13 on usable_edge.
//   2. Vertical dilation V3 on the H13 result.
//   3. Online row projection from H13/V3 morphology.
//   4. Frame-local column accumulation from H13 horizontal dilation.
//   5. Scan column projection during blanking and publish a filtered bbox.
//
// Notes:
//   * The detector is deliberately lightweight RTL. It is not OCR.
//   * Bbox coordinates are local 800x480 window coordinates.
//   * bbox output is held for a few misses to avoid immediate flicker.
//   * Column counters are overwritten on the first morphology row of each frame;
//     no large reset loop is required.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module plate_edge_morph_bbox_project #(
    parameter integer IMG_W = 800,
    parameter [11:0] IN_X_FIRST = 12'd4,
    parameter [11:0] IN_X_LAST  = 12'd795,
    parameter [11:0] IN_Y_FIRST = 12'd1,
    parameter [11:0] IN_Y_LAST  = 12'd478,
    parameter [10:0] ROW_TH = 11'd18,
    parameter [9:0]  COL_TH = 10'd6,
    parameter [11:0] MIN_PLATE_W = 12'd80,
    parameter [11:0] MAX_PLATE_W = 12'd420,
    parameter [11:0] MIN_PLATE_H = 12'd20,
    parameter [11:0] MAX_PLATE_H = 12'd140,
    parameter [3:0]  HOLD_MISS_FRAMES = 4'd4
)(
    input  wire        clk,
    input  wire        rstn,
    input  wire        frame_start,
    input  wire        in_valid,
    input  wire [11:0] in_x,
    input  wire [11:0] in_y,
    input  wire        usable_edge_in,

    output reg         morph_valid,
    output reg  [11:0] morph_x,
    output reg  [11:0] morph_y,
    output reg         morph_mask,

    output reg         bbox_valid,
    output reg  [11:0] bbox_x0,
    output reg  [11:0] bbox_y0,
    output reg  [11:0] bbox_x1,
    output reg  [11:0] bbox_y1,
    output reg  [19:0] bbox_score,
    output reg         bbox_candidate_valid,
    output reg         bbox_update_pulse,
    output reg  [3:0]  bbox_miss_count,
    output reg  [19:0] morph_pixel_count_last,
    output reg  [19:0] best_row_score_dbg,
    output reg  [19:0] best_col_score_dbg
);

localparam [11:0] H_RADIUS = 12'd6;
localparam [11:0] H_SPAN_MINUS1 = 12'd12;
localparam [11:0] V_RADIUS = 12'd1;
localparam [11:0] MORPH_X_FIRST = IN_X_FIRST + H_RADIUS;
localparam [11:0] MORPH_X_LAST  = IN_X_LAST  - H_RADIUS;
localparam [11:0] MORPH_Y_FIRST = IN_Y_FIRST + V_RADIUS;
localparam [11:0] MORPH_Y_LAST  = IN_Y_LAST  - V_RADIUS;
localparam [11:0] SCAN_SENTINEL = MORPH_X_LAST + 12'd1;

// H13 streaming dilation. Newest pixel is bit 0 after h_shift_next is formed.
reg [12:0] h_shift;
wire [12:0] h_shift_next = (in_x == IN_X_FIRST) ? {12'd0, usable_edge_in} :
                                                        {h_shift[11:0], usable_edge_in};
wire h_dilate_w = |h_shift_next;
wire h_valid_w = in_valid && (in_x >= (IN_X_FIRST + H_SPAN_MINUS1));
wire [11:0] h_center_x_w = in_x - H_RADIUS;

// V3 dilation of the horizontally expanded stream.
reg h_linebuf0 [0:IMG_W-1];
reg h_linebuf1 [0:IMG_W-1];
wire h_lb0_rd = h_valid_w ? h_linebuf0[h_center_x_w] : 1'b0;
wire h_lb1_rd = h_valid_w ? h_linebuf1[h_center_x_w] : 1'b0;
wire morph_valid_w = h_valid_w && (in_y >= (IN_Y_FIRST + 12'd2));
wire [11:0] morph_x_w = h_center_x_w;
wire [11:0] morph_y_w = in_y - V_RADIUS;
wire morph_mask_w = h_dilate_w | h_lb0_rd | h_lb1_rd;
wire morph_frame_end_w = morph_valid_w &&
                         (morph_x_w == MORPH_X_LAST) &&
                         (morph_y_w == MORPH_Y_LAST);

// Projection state.
reg [9:0] col_count [0:IMG_W-1];
reg [10:0] row_count;
reg [19:0] morph_pixel_count;

reg        y_run_active;
reg [11:0] y_run_y0;
reg [11:0] y_run_y1;
reg [19:0] y_run_score;
reg [11:0] best_y0;
reg [11:0] best_y1;
reg [19:0] best_y_score;

reg        scan_active;
reg [11:0] scan_x;
reg        x_run_active;
reg [11:0] x_run_x0;
reg [11:0] x_run_x1;
reg [19:0] x_run_score;
reg [11:0] best_x0;
reg [11:0] best_x1;
reg [19:0] best_x_score;

wire [10:0] row_count_eval_w = (morph_x_w == MORPH_X_FIRST) ?
                               {10'd0, morph_mask_w} :
                               (row_count + {10'd0, morph_mask_w});
wire [19:0] morph_pixel_eval_w = morph_pixel_count + {19'd0, morph_mask_w};
wire [19:0] y_run_score_add_w = y_run_score + {9'd0, row_count_eval_w};
wire row_qual_w = (row_count_eval_w >= ROW_TH);

wire scan_in_range_w = (scan_x >= MORPH_X_FIRST) && (scan_x <= MORPH_X_LAST);
wire [9:0] scan_col_count_w = scan_in_range_w ? col_count[scan_x] : 10'd0;
wire scan_col_qual_w = scan_in_range_w && (scan_col_count_w >= COL_TH);
wire [19:0] x_run_score_add_w = x_run_score + {10'd0, scan_col_count_w};

wire [11:0] candidate_w_w = (best_x1 >= best_x0) ? (best_x1 - best_x0 + 12'd1) : 12'd0;
wire [11:0] candidate_h_w = (best_y1 >= best_y0) ? (best_y1 - best_y0 + 12'd1) : 12'd0;
wire [18:0] aspect_w_x10 = {7'd0, candidate_w_w} * 19'd10;
wire [18:0] aspect_h_x20 = {7'd0, candidate_h_w} * 19'd20;
wire [18:0] aspect_h_x65 = {7'd0, candidate_h_w} * 19'd65;
wire geometry_valid_w = (best_x_score != 20'd0) &&
                        (best_y_score != 20'd0) &&
                        (candidate_w_w >= MIN_PLATE_W) &&
                        (candidate_w_w <= MAX_PLATE_W) &&
                        (candidate_h_w >= MIN_PLATE_H) &&
                        (candidate_h_w <= MAX_PLATE_H) &&
                        (aspect_w_x10 >= aspect_h_x20) &&
                        (aspect_w_x10 <= aspect_h_x65);

always @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        h_shift <= 13'd0;
        morph_valid <= 1'b0;
        morph_x <= 12'd0;
        morph_y <= 12'd0;
        morph_mask <= 1'b0;
        row_count <= 11'd0;
        morph_pixel_count <= 20'd0;
        morph_pixel_count_last <= 20'd0;
        y_run_active <= 1'b0;
        y_run_y0 <= 12'd0;
        y_run_y1 <= 12'd0;
        y_run_score <= 20'd0;
        best_y0 <= 12'd0;
        best_y1 <= 12'd0;
        best_y_score <= 20'd0;
        scan_active <= 1'b0;
        scan_x <= MORPH_X_FIRST;
        x_run_active <= 1'b0;
        x_run_x0 <= 12'd0;
        x_run_x1 <= 12'd0;
        x_run_score <= 20'd0;
        best_x0 <= 12'd0;
        best_x1 <= 12'd0;
        best_x_score <= 20'd0;
        bbox_valid <= 1'b0;
        bbox_x0 <= 12'd0;
        bbox_y0 <= 12'd0;
        bbox_x1 <= 12'd0;
        bbox_y1 <= 12'd0;
        bbox_score <= 20'd0;
        bbox_candidate_valid <= 1'b0;
        bbox_update_pulse <= 1'b0;
        bbox_miss_count <= 4'd0;
        best_row_score_dbg <= 20'd0;
        best_col_score_dbg <= 20'd0;
    end else begin
        bbox_update_pulse <= 1'b0;
        morph_valid <= morph_valid_w;
        morph_x <= morph_valid_w ? morph_x_w : 12'd0;
        morph_y <= morph_valid_w ? morph_y_w : 12'd0;
        morph_mask <= morph_valid_w ? morph_mask_w : 1'b0;

        if(in_valid)
            h_shift <= h_shift_next;
        else
            h_shift <= 13'd0;

        if(h_valid_w) begin
            h_linebuf1[h_center_x_w] <= h_lb0_rd;
            h_linebuf0[h_center_x_w] <= h_dilate_w;
            // Column projection intentionally uses H13 rather than H13/V3.
            // This keeps character-edge columns connected while reducing the
            // chance that isolated points become tall false columns.
            if(in_y == IN_Y_FIRST)
                col_count[h_center_x_w] <= {9'd0, h_dilate_w};
            else if(h_dilate_w)
                col_count[h_center_x_w] <= col_count[h_center_x_w] + 10'd1;
        end

        if(frame_start) begin
            row_count <= 11'd0;
            morph_pixel_count <= 20'd0;
            y_run_active <= 1'b0;
            y_run_y0 <= 12'd0;
            y_run_y1 <= 12'd0;
            y_run_score <= 20'd0;
            best_y0 <= 12'd0;
            best_y1 <= 12'd0;
            best_y_score <= 20'd0;
            scan_active <= 1'b0;
            scan_x <= MORPH_X_FIRST;
            x_run_active <= 1'b0;
            x_run_x0 <= 12'd0;
            x_run_x1 <= 12'd0;
            x_run_score <= 20'd0;
            best_x0 <= 12'd0;
            best_x1 <= 12'd0;
            best_x_score <= 20'd0;
        end else begin
            if(morph_valid_w) begin
                morph_pixel_count <= morph_pixel_eval_w;

                if(morph_x_w == MORPH_X_FIRST)
                    row_count <= {10'd0, morph_mask_w};
                else
                    row_count <= row_count + {10'd0, morph_mask_w};

                if(morph_x_w == MORPH_X_LAST) begin
                    row_count <= 11'd0;
                    if(row_qual_w) begin
                        if(y_run_active) begin
                            y_run_y1 <= morph_y_w;
                            y_run_score <= y_run_score_add_w;
                            if(y_run_score_add_w > best_y_score) begin
                                best_y0 <= y_run_y0;
                                best_y1 <= morph_y_w;
                                best_y_score <= y_run_score_add_w;
                            end
                        end else begin
                            y_run_active <= 1'b1;
                            y_run_y0 <= morph_y_w;
                            y_run_y1 <= morph_y_w;
                            y_run_score <= {9'd0, row_count_eval_w};
                            if({9'd0, row_count_eval_w} > best_y_score) begin
                                best_y0 <= morph_y_w;
                                best_y1 <= morph_y_w;
                                best_y_score <= {9'd0, row_count_eval_w};
                            end
                        end
                    end else begin
                        y_run_active <= 1'b0;
                        y_run_score <= 20'd0;
                    end
                end

                if(morph_frame_end_w) begin
                    morph_pixel_count_last <= morph_pixel_eval_w;
                    scan_active <= 1'b1;
                    scan_x <= MORPH_X_FIRST;
                    x_run_active <= 1'b0;
                    x_run_x0 <= 12'd0;
                    x_run_x1 <= 12'd0;
                    x_run_score <= 20'd0;
                    best_x0 <= 12'd0;
                    best_x1 <= 12'd0;
                    best_x_score <= 20'd0;
                end
            end

            if(scan_active) begin
                if(scan_col_qual_w) begin
                    if(x_run_active) begin
                        x_run_x1 <= scan_x;
                        x_run_score <= x_run_score_add_w;
                        if(x_run_score_add_w > best_x_score) begin
                            best_x0 <= x_run_x0;
                            best_x1 <= scan_x;
                            best_x_score <= x_run_score_add_w;
                        end
                    end else begin
                        x_run_active <= 1'b1;
                        x_run_x0 <= scan_x;
                        x_run_x1 <= scan_x;
                        x_run_score <= {10'd0, scan_col_count_w};
                        if({10'd0, scan_col_count_w} > best_x_score) begin
                            best_x0 <= scan_x;
                            best_x1 <= scan_x;
                            best_x_score <= {10'd0, scan_col_count_w};
                        end
                    end
                end else begin
                    x_run_active <= 1'b0;
                    x_run_score <= 20'd0;
                end

                if(scan_x == SCAN_SENTINEL) begin
                    scan_active <= 1'b0;
                    bbox_candidate_valid <= geometry_valid_w;
                    bbox_update_pulse <= 1'b1;
                    best_row_score_dbg <= best_y_score;
                    best_col_score_dbg <= best_x_score;
                    if(geometry_valid_w) begin
                        bbox_valid <= 1'b1;
                        bbox_x0 <= best_x0;
                        bbox_y0 <= best_y0;
                        bbox_x1 <= best_x1;
                        bbox_y1 <= best_y1;
                        bbox_score <= morph_pixel_count_last;
                        bbox_miss_count <= 4'd0;
                    end else if(bbox_valid) begin
                        if(bbox_miss_count >= (HOLD_MISS_FRAMES - 4'd1)) begin
                            bbox_valid <= 1'b0;
                            bbox_miss_count <= 4'd0;
                        end else begin
                            bbox_miss_count <= bbox_miss_count + 4'd1;
                        end
                    end
                end else begin
                    scan_x <= scan_x + 12'd1;
                end
            end
        end
    end
end

endmodule
