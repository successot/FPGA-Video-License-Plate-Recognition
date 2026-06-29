`timescale 1ns / 1ps
`default_nettype wire
`define UD #1
// -----------------------------------------------------------------------------
// MES50HP Stage7F14C 4CH DIRECT DDR COMPILEFIX
//
// SFP0/lane2 -> QSGMII -> GMII ch0/ch1/ch2/ch3
// -> four UDP5000/FPGV RGB565 800x480 receivers
// -> shared DDR3 two-bank-per-channel frame storage
// -> 1920x1080 HDMI 2x2 quad view, no scaling/no stretching.
//
// Layout on 1920x1080:
//   margin L/R = 140, margin T/B = 40, center gap X/Y = 40
//   ch0: top-left      x=140..939,  y=40..519
//   ch1: top-right     x=980..1779, y=40..519
//   ch2: bottom-left   x=140..939,  y=560..1039
//   ch3: bottom-right  x=980..1779, y=560..1039
// -----------------------------------------------------------------------------
module mes50hp_stage7f14c_4ch_direct_ddr_compilefix_top #(
    parameter MEM_ROW_ADDR_WIDTH   = 15,
    parameter MEM_COL_ADDR_WIDTH   = 10,
    parameter MEM_BADDR_WIDTH      = 3,
    parameter MEM_DQ_WIDTH         = 32,
    parameter MEM_DQS_WIDTH        = 32/8
)(
    input                                sys_clk,
    input                                rst_n,

    input                                i_p_refckn_0,
    input                                i_p_refckp_0,
    input                                i_p_l2rxn,
    input                                i_p_l2rxp,
    output                               o_p_l2txn,
    output                               o_p_l2txp,
    input                                i_p_l3rxn,
    input                                i_p_l3rxp,
    output                               o_p_l3txn,
    output                               o_p_l3txp,
    input                                sfp0_los,
    input                                sfp1_los,
    output [1:0]                         tx_disable,

    output [7:0]                         led,

    output                               mem_rst_n,
    output                               mem_ck,
    output                               mem_ck_n,
    output                               mem_cke,
    output                               mem_cs_n,
    output                               mem_ras_n,
    output                               mem_cas_n,
    output                               mem_we_n,
    output                               mem_odt,
    output      [MEM_ROW_ADDR_WIDTH-1:0] mem_a,
    output      [MEM_BADDR_WIDTH-1:0]    mem_ba,
    inout       [MEM_DQ_WIDTH/8-1:0]     mem_dqs,
    inout       [MEM_DQ_WIDTH/8-1:0]     mem_dqs_n,
    inout       [MEM_DQ_WIDTH-1:0]       mem_dq,
    output      [MEM_DQ_WIDTH/8-1:0]     mem_dm,

    output                               rstn_out,
    output                               iic_tx_scl,
    inout                                iic_tx_sda,
    output                               pix_clk,
    output reg                           vs_out,
    output reg                           hs_out,
    output reg                           de_out,
    output reg [7:0]                     r_out,
    output reg [7:0]                     g_out,
    output reg [7:0]                     b_out
);

localparam CTRL_ADDR_WIDTH = MEM_ROW_ADDR_WIDTH + MEM_BADDR_WIDTH + MEM_COL_ADDR_WIDTH;
localparam TH_1S = 27'd33000000;
localparam [11:0] SRC_W = 12'd800;
localparam [11:0] SRC_H = 12'd480;
localparam [11:0] WIN_W = 12'd800;
localparam [11:0] WIN_H = 12'd480;
localparam [11:0] WIN0_X = 12'd140;
localparam [11:0] WIN1_X = 12'd980;
localparam [11:0] WIN0_Y = 12'd40;
localparam [11:0] WIN1_Y = 12'd560;

wire sys_rst_n;
cross_reset_sync u_sys_reset_sync (
    .free_clk_pll  (sys_clk),
    .external_rstn (rst_n),
    .rst_n         (sys_rst_n)
);

wire cfg_clk;
wire clk_25M_unused;
wire locked;
wire init_over_tx;
wire init_over_rx;
wire iic_scl;
wire iic_sda;
reg  [15:0] rstn_1ms;

// Stage7F13: pll.v ratios changed so clkout0 is approximately 148.48 MHz.
pll u_pll (
    .clkin1   (sys_clk),
    .clkout0  (pix_clk),
    .clkout1  (cfg_clk),
    .clkout2  (clk_25M_unused),
    .pll_lock (locked)
);

ms72xx_ctl ms72xx_ctl (
    .clk          (cfg_clk),
    .rst_n        (rstn_out),
    .init_over_tx (init_over_tx),
    .init_over_rx (init_over_rx),
    .iic_tx_scl   (iic_tx_scl),
    .iic_tx_sda   (iic_tx_sda),
    .iic_scl      (iic_scl),
    .iic_sda      (iic_sda)
);

always @(posedge cfg_clk) begin
    if(!locked)
        rstn_1ms <= 16'd0;
    else if(rstn_1ms == 16'h2710)
        rstn_1ms <= rstn_1ms;
    else
        rstn_1ms <= rstn_1ms + 1'b1;
end
assign rstn_out = (rstn_1ms == 16'h2710);

wire [7:0] sfp_debug_led;
wire p0_clk, p1_clk, p2_clk, p3_clk;
wire p0_rstn, p1_rstn, p2_rstn, p3_rstn;
wire [7:0] p0_rxd, p1_rxd, p2_rxd, p3_rxd;
wire p0_dv, p1_dv, p2_dv, p3_dv;
wire p0_er, p1_er, p2_er, p3_er;
wire [3:0] sfp_rx_activity_live;
wire [3:0] sfp_rx_frame_seen;
wire [3:0] sfp_udp5000_seen;
wire [3:0] sfp_fpgv_seen;
wire [3:0] sfp_rx_error_seen;
wire hsst_pll_lock;
wire sfp0_lane_done;
wire sfp0_pcs_synced;

mes50hp_sfp_rx_gmii_4ch u_sfp_rx (
    .i_free_clk           (sys_clk),
    .rst_n                (rst_n),
    .i_p_refckn_0         (i_p_refckn_0),
    .i_p_refckp_0         (i_p_refckp_0),
    .i_p_l2rxn            (i_p_l2rxn),
    .i_p_l2rxp            (i_p_l2rxp),
    .o_p_l2txn            (o_p_l2txn),
    .o_p_l2txp            (o_p_l2txp),
    .i_p_l3rxn            (i_p_l3rxn),
    .i_p_l3rxp            (i_p_l3rxp),
    .o_p_l3txn            (o_p_l3txn),
    .o_p_l3txp            (o_p_l3txp),
    .sfp0_los             (sfp0_los),
    .sfp1_los             (sfp1_los),
    .tx_disable           (tx_disable),
    .led                  (sfp_debug_led),
    .out_p0_sgmii_clk     (p0_clk),
    .out_p1_sgmii_clk     (p1_clk),
    .out_p2_sgmii_clk     (p2_clk),
    .out_p3_sgmii_clk     (p3_clk),
    .out_p0_rx_rstn       (p0_rstn),
    .out_p1_rx_rstn       (p1_rstn),
    .out_p2_rx_rstn       (p2_rstn),
    .out_p3_rx_rstn       (p3_rstn),
    .out_p0_gmii_rxd      (p0_rxd),
    .out_p1_gmii_rxd      (p1_rxd),
    .out_p2_gmii_rxd      (p2_rxd),
    .out_p3_gmii_rxd      (p3_rxd),
    .out_p0_gmii_rx_dv    (p0_dv),
    .out_p1_gmii_rx_dv    (p1_dv),
    .out_p2_gmii_rx_dv    (p2_dv),
    .out_p3_gmii_rx_dv    (p3_dv),
    .out_p0_gmii_rx_er    (p0_er),
    .out_p1_gmii_rx_er    (p1_er),
    .out_p2_gmii_rx_er    (p2_er),
    .out_p3_gmii_rx_er    (p3_er),
    .out_rx_activity_live (sfp_rx_activity_live),
    .out_rx_frame_seen    (sfp_rx_frame_seen),
    .out_udp5000_seen     (sfp_udp5000_seen),
    .out_fpgv_seen        (sfp_fpgv_seen),
    .out_rx_error_seen    (sfp_rx_error_seen),
    .out_hsst_pll_lock    (hsst_pll_lock),
    .out_sfp0_lane_done   (sfp0_lane_done),
    .out_sfp0_pcs_synced  (sfp0_pcs_synced)
);

// Stage7F14C: FPGV packets are no longer converted into a VIN stream here.
// The direct-DDR wrapper parses all four GMII channels and writes each packet
// payload to DDR according to byte_offset.
wire [31:0] ch0_overflow_count, ch1_overflow_count, ch2_overflow_count, ch3_overflow_count;

wire [15:0] fb_rgb0, fb_rgb1, fb_rgb2, fb_rgb3;
wire        fb_de0, fb_de1, fb_de2, fb_de3;
wire [3:0]  fb_init_done;
wire [3:0]  fb_frame_done_seen;
wire [31:0] fb_done_cnt0, fb_done_cnt1, fb_done_cnt2, fb_done_cnt3;
wire        vs_o;
wire        hs_o;
wire        vg_de_o;
wire        de_re;
wire [11:0] vg_x;
wire [11:0] vg_y;

wire [12:0] pre_x = {1'b0, vg_x} + 13'd2;
wire        y_top = (vg_y >= WIN0_Y) && (vg_y < WIN0_Y + WIN_H);
wire        y_bot = (vg_y >= WIN1_Y) && (vg_y < WIN1_Y + WIN_H);
wire        pre_x_left  = (pre_x >= WIN0_X) && (pre_x < WIN0_X + WIN_W);
wire        pre_x_right = (pre_x >= WIN1_X) && (pre_x < WIN1_X + WIN_W);
wire        x_left_now  = (vg_x >= WIN0_X) && (vg_x < WIN0_X + WIN_W);
wire        x_right_now = (vg_x >= WIN1_X) && (vg_x < WIN1_X + WIN_W);

wire rd_en_ch0 = de_re && y_top && pre_x_left;
wire rd_en_ch1 = de_re && y_top && pre_x_right;
wire rd_en_ch2 = de_re && y_bot && pre_x_left;
wire rd_en_ch3 = de_re && y_bot && pre_x_right;

wire [CTRL_ADDR_WIDTH-1:0]  axi_awaddr;
wire [3:0]                  axi_awuser_id;
wire [3:0]                  axi_awlen;
wire                        axi_awready;
wire                        axi_awvalid;
wire [MEM_DQ_WIDTH*8-1:0]   axi_wdata;
wire [MEM_DQ_WIDTH*8/8-1:0] axi_wstrb;
wire                        axi_wready;
wire                        axi_wusero_last;
wire [CTRL_ADDR_WIDTH-1:0]  axi_araddr;
wire [3:0]                  axi_aruser_id;
wire [3:0]                  axi_arlen;
wire                        axi_arready;
wire                        axi_arvalid;
wire [MEM_DQ_WIDTH*8-1:0]   axi_rdata;
wire                        axi_rvalid;
wire [3:0]                  axi_rid;
wire                        axi_rlast;
wire                        core_clk;
wire                        pll_lock;
wire                        ddr_init_done;
reg  [26:0]                 cnt;
reg                         heart_beat_led;

fram_buf_4ch_direct_f14c #(
    .MEM_ROW_WIDTH(MEM_ROW_ADDR_WIDTH),
    .MEM_COLUMN_WIDTH(MEM_COL_ADDR_WIDTH),
    .MEM_BANK_WIDTH(MEM_BADDR_WIDTH),
    .MEM_DQ_WIDTH(MEM_DQ_WIDTH),
    .H_NUM(12'd800),
    .V_NUM(12'd480),
    .PIX_WIDTH(16),
    .LINE_ADDR_WIDTH(19)
) u_fram_buf_4ch_direct_f14c (
    .ddr_clk(core_clk),
    .ddr_rstn(ddr_init_done),
    .ch0_gmii_clk(p0_clk), .ch0_gmii_rstn(p0_rstn & sys_rst_n), .ch0_gmii_rxd(p0_rxd), .ch0_gmii_dv(p0_dv), .ch0_gmii_er(p0_er),
    .ch1_gmii_clk(p1_clk), .ch1_gmii_rstn(p1_rstn & sys_rst_n), .ch1_gmii_rxd(p1_rxd), .ch1_gmii_dv(p1_dv), .ch1_gmii_er(p1_er),
    .ch2_gmii_clk(p2_clk), .ch2_gmii_rstn(p2_rstn & sys_rst_n), .ch2_gmii_rxd(p2_rxd), .ch2_gmii_dv(p2_dv), .ch2_gmii_er(p2_er),
    .ch3_gmii_clk(p3_clk), .ch3_gmii_rstn(p3_rstn & sys_rst_n), .ch3_gmii_rxd(p3_rxd), .ch3_gmii_dv(p3_dv), .ch3_gmii_er(p3_er),
    .init_done(fb_init_done), .frame_done_seen(fb_frame_done_seen),
    .ch0_frame_done_count(fb_done_cnt0), .ch1_frame_done_count(fb_done_cnt1), .ch2_frame_done_count(fb_done_cnt2), .ch3_frame_done_count(fb_done_cnt3),
    .ch0_overflow_count(ch0_overflow_count), .ch1_overflow_count(ch1_overflow_count), .ch2_overflow_count(ch2_overflow_count), .ch3_overflow_count(ch3_overflow_count),
    .vout_clk(pix_clk), .rd_fsync(vs_o), .rd_en_ch0(rd_en_ch0), .rd_en_ch1(rd_en_ch1), .rd_en_ch2(rd_en_ch2), .rd_en_ch3(rd_en_ch3),
    .vout_de_ch0(fb_de0), .vout_de_ch1(fb_de1), .vout_de_ch2(fb_de2), .vout_de_ch3(fb_de3),
    .vout_data_ch0(fb_rgb0), .vout_data_ch1(fb_rgb1), .vout_data_ch2(fb_rgb2), .vout_data_ch3(fb_rgb3),
    .axi_awaddr(axi_awaddr), .axi_awid(axi_awuser_id), .axi_awlen(axi_awlen), .axi_awsize(), .axi_awburst(), .axi_awready(axi_awready), .axi_awvalid(axi_awvalid),
    .axi_wdata(axi_wdata), .axi_wstrb(axi_wstrb), .axi_wlast(axi_wusero_last), .axi_wvalid(), .axi_wready(axi_wready), .axi_bid(4'd0),
    .axi_araddr(axi_araddr), .axi_arid(axi_aruser_id), .axi_arlen(axi_arlen), .axi_arsize(), .axi_arburst(), .axi_arvalid(axi_arvalid), .axi_arready(axi_arready),
    .axi_rready(), .axi_rdata(axi_rdata), .axi_rvalid(axi_rvalid), .axi_rlast(axi_rlast), .axi_rid(axi_rid)
);

sync_vg #(
    .V_TOTAL(12'd1125), .V_FP(12'd4), .V_BP(12'd36), .V_SYNC(12'd5), .V_ACT(12'd1080),
    .H_TOTAL(12'd2200), .H_FP(12'd88), .H_BP(12'd148), .H_SYNC(12'd44), .H_ACT(12'd1920), .HV_OFFSET(12'd0)
) u_sync_vg_1080p (
    .clk    (pix_clk),
    .rstn   (rstn_out & init_over_tx & ddr_init_done),
    .vs_out (vs_o),
    .hs_out (hs_o),
    .de_out (vg_de_o),
    .de_re  (de_re),
    .x_act  (vg_x),
    .y_act  (vg_y)
);

wire [15:0] test_rgb565 =
    (vg_x < 12'd274)  ? 16'hF800 :
    (vg_x < 12'd548)  ? 16'hFFE0 :
    (vg_x < 12'd822)  ? 16'h07E0 :
    (vg_x < 12'd1096) ? 16'h07FF :
    (vg_x < 12'd1370) ? 16'h001F :
    (vg_x < 12'd1644) ? 16'hF81F :
                         16'hFFFF;

reg [2:0] any_init_pix_sync;
always @(posedge pix_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)
        any_init_pix_sync <= 3'b000;
    else
        any_init_pix_sync <= {any_init_pix_sync[1:0], |fb_init_done};
end
wire video_show_pix = any_init_pix_sync[2];

wire in_ch0_now = y_top && x_left_now;
wire in_ch1_now = y_top && x_right_now;
wire in_ch2_now = y_bot && x_left_now;
wire in_ch3_now = y_bot && x_right_now;

wire [15:0] quad_rgb565 =
    (in_ch0_now && fb_init_done[0]) ? (fb_de0 ? fb_rgb0 : 16'h0000) :
    (in_ch1_now && fb_init_done[1]) ? (fb_de1 ? fb_rgb1 : 16'h0000) :
    (in_ch2_now && fb_init_done[2]) ? (fb_de2 ? fb_rgb2 : 16'h0000) :
    (in_ch3_now && fb_init_done[3]) ? (fb_de3 ? fb_rgb3 : 16'h0000) :
                                      16'h0000;

wire [15:0] hdmi_rgb565 = video_show_pix ? quad_rgb565 : (ddr_init_done ? 16'h0000 : test_rgb565);

always @(posedge pix_clk) begin
    vs_out <= vs_o;
    hs_out <= hs_o;
    de_out <= vg_de_o;
    if(vg_de_o) begin
        r_out <= {hdmi_rgb565[15:11], 3'b000};
        g_out <= {hdmi_rgb565[10:5],  2'b00};
        b_out <= {hdmi_rgb565[4:0],   3'b000};
    end else begin
        r_out <= 8'h00;
        g_out <= 8'h00;
        b_out <= 8'h00;
    end
end

DDR3_50H u_DDR3_50H (
    .ref_clk(sys_clk),
    .resetn(rstn_out),
    .ddr_init_done(ddr_init_done),
    .ddrphy_clkin(core_clk),
    .pll_lock(pll_lock),
    .axi_awaddr(axi_awaddr),
    .axi_awuser_ap(1'b0),
    .axi_awuser_id(axi_awuser_id),
    .axi_awlen(axi_awlen),
    .axi_awready(axi_awready),
    .axi_awvalid(axi_awvalid),
    .axi_wdata(axi_wdata),
    .axi_wstrb(axi_wstrb),
    .axi_wready(axi_wready),
    .axi_wusero_id(),
    .axi_wusero_last(axi_wusero_last),
    .axi_araddr(axi_araddr),
    .axi_aruser_ap(1'b0),
    .axi_aruser_id(axi_aruser_id),
    .axi_arlen(axi_arlen),
    .axi_arready(axi_arready),
    .axi_arvalid(axi_arvalid),
    .axi_rdata(axi_rdata),
    .axi_rid(axi_rid),
    .axi_rlast(axi_rlast),
    .axi_rvalid(axi_rvalid),
    .apb_clk(1'b0), .apb_rst_n(1'b1), .apb_sel(1'b0), .apb_enable(1'b0), .apb_addr(8'b0), .apb_write(1'b0), .apb_ready(), .apb_wdata(16'b0), .apb_rdata(), .apb_int(),
    .mem_rst_n(mem_rst_n), .mem_ck(mem_ck), .mem_ck_n(mem_ck_n), .mem_cke(mem_cke), .mem_cs_n(mem_cs_n), .mem_ras_n(mem_ras_n), .mem_cas_n(mem_cas_n), .mem_we_n(mem_we_n), .mem_odt(mem_odt),
    .mem_a(mem_a), .mem_ba(mem_ba), .mem_dqs(mem_dqs), .mem_dqs_n(mem_dqs_n), .mem_dq(mem_dq), .mem_dm(mem_dm),
    .debug_data(), .debug_slice_state(), .debug_calib_ctrl(), .ck_dly_set_bin(), .force_ck_dly_en(1'b0), .force_ck_dly_set_bin(8'h05), .dll_step(), .dll_lock(),
    .init_read_clk_ctrl(2'b0), .init_slip_step(4'b0), .force_read_clk_ctrl(1'b0), .ddrphy_gate_update_en(1'b0), .update_com_val_err_flag(), .rd_fake_stop(1'b0)
);

always @(posedge core_clk) begin
    if(!ddr_init_done)
        cnt <= 27'd0;
    else if(cnt >= TH_1S)
        cnt <= 27'd0;
    else
        cnt <= cnt + 27'd1;
end

always @(posedge core_clk) begin
    if(!ddr_init_done)
        heart_beat_led <= 1'b1;
    else if(cnt >= TH_1S)
        heart_beat_led <= ~heart_beat_led;
end

assign led[0] = heart_beat_led;
assign led[1] = init_over_tx;
assign led[2] = sfp0_pcs_synced;
assign led[3] = ddr_init_done;
assign led[4] = |sfp_udp5000_seen;
assign led[5] = |sfp_fpgv_seen;
assign led[6] = |fb_frame_done_seen;
assign led[7] = video_show_pix;

endmodule
