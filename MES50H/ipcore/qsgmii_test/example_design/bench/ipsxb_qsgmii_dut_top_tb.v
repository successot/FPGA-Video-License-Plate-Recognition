
/////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2014 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
//
// THE SOURCE CODE CONTAINED HEREIN IS PROPRIETARY TO PANGO MICROSYSTEMS, INC.
// IT SHALL NOT BE REPRODUCED OR DISCLOSED IN WHOLE OR IN PART OR USED BY
// PARTIES WITHOUT WRITTEN AUTHORIZATION FROM THE OWNER.
//
//////////////////////////////////////////////////////////////////////////////
// Functional description: pango_qsgmii_top_tb

`timescale 1ps/100fs

module ipsxb_qsgmii_dut_top_tb();

ipsxb_qsgmii_dut_sim_top U_inst_tb (
);

reg                     u1_P_REFCKN            ;
reg                     u1_P_REFCKP            ;

wire                    u1_P_L0TXN             ;
wire                    u1_P_L0TXP             ;
wire                    u1_P_L0RXN             ;
wire                    u1_P_L0RXP             ;

reg                     u2_P_REFCKN            ;
reg                     u2_P_REFCKP            ;

wire                    u2_P_L0TXN             ;
wire                    u2_P_L0TXP             ;
wire                    u2_P_L0RXN             ;
wire                    u2_P_L0RXP             ;

reg                     u1_free_clk            ;
reg                     u1_external_rstn       ;
wire                    u1_p0_soft_rstn        ;
wire                    u1_p1_soft_rstn        ;
wire                    u1_p2_soft_rstn        ;
wire                    u1_p3_soft_rstn        ;
wire                    u2_p0_soft_rstn        ;
wire                    u2_p1_soft_rstn        ;
wire                    u2_p2_soft_rstn        ;
wire                    u2_p3_soft_rstn        ;
reg                     u2_free_clk            ;
reg                     u2_external_rstn       ;
wire                    u1_mm_rst_n            ;
wire                    u2_mm_rst_n            ;
wire    [4:0]           u1_p0_phy_addr         ;
wire    [4:0]           u1_p1_phy_addr         ;
wire    [4:0]           u1_p2_phy_addr         ;
wire    [4:0]           u1_p3_phy_addr         ;
wire    [4:0]           u2_p0_phy_addr         ;
wire    [4:0]           u2_p1_phy_addr         ;
wire    [4:0]           u2_p2_phy_addr         ;
wire    [4:0]           u2_p3_phy_addr         ;
wire                    u1_mdio_done           ;
wire    [1:0]           u1_op                  ;
wire    [4:0]           u1_regad               ;
wire    [15:0]          u1_data0               ;
wire                    u1_mdio_load           ;
wire                    u2_mdio_done           ;
wire    [1:0]           u2_op                  ;
wire    [4:0]           u2_regad               ;
wire    [15:0]          u2_data0               ;
wire                    u2_mdio_load           ;
reg                     mdc                    ;
wire                    u1_mdi                 ;
wire                    u2_mdi                 ;
wire                    u1_mdo                 ;
wire                    u1_mdo_en              ;
wire    [15:0]          u1_mdio_rd_shift       ;
wire                    u2_mdo                 ;
wire                    u2_mdo_en              ;
wire    [15:0]          u2_mdio_rd_shift       ;
wire                    u1_clk_tx              ;
wire                    u1_clk_rx              ;
wire                    u2_clk_tx              ;
wire                    u2_clk_rx              ;
reg                     u1_pin_cfg_en          ;
reg  [1:0]              u1_phy_speed           ;
wire [4:0]              u1_phy_addr            ;
wire                    u1_phy_duplex          ;
wire                    u1_phy_link            ;
wire                    u1_unidir_en           ;
wire                    u1_an_restart          ;
wire                    u1_an_enable           ;
wire                    u1_loopback            ;
wire [3:0]              u1_pma_nearend_sloop   ;
wire [3:0]              u1_pma_nearend_ploop   ;
wire [3:0]              u1_pcs_farend_loop     ;
wire [3:0]              u1_pcs_nearend_loop    ;
wire                    u1_rg_start_test       ;
wire                    u1_rg_length_cfg_en    ;
wire [18:0]             u1_rg_length_num       ;
wire                    u1_rg_pld_max_sel      ;
wire                    u1_rg_ipg_max_sel      ;
wire                    u1_rg_pre_max_sel      ;
wire                    u1_rg_pre_cfg_en       ;
wire [3:0]              u1_rg_pre_num          ;
wire                    u1_rg_ipg_cfg_en       ;
wire [7:0]              u1_rg_ipg_num          ;
wire                    u1_rg_wtchdg_sof_clr   ;
wire [3:0]              u1_rg_rx_lane_sof_rst_n;
wire [3:0]              u1_rg_tx_lane_sof_rst_n;
wire                    u1_rg_tx_pll_sof_rst_n ;
reg                     u1_rg_hsst_cfg_soft_rstn;
wire                    u1_rg_pkg_send_clr     ;
wire [3:0]              u1_rg_pkg_chk_clr      ;
wire [31:0]             u1_pkg_gen_cnt         ;
wire [31:0]             u1_p0_crc_ok_cnt       ;
wire [31:0]             u1_p1_crc_ok_cnt       ;
wire [31:0]             u1_p2_crc_ok_cnt       ;
wire [31:0]             u1_p3_crc_ok_cnt       ;
wire [31:0]             u1_p0_crc_err_cnt      ;
wire [31:0]             u1_p1_crc_err_cnt      ;
wire [31:0]             u1_p2_crc_err_cnt      ;
wire [31:0]             u1_p3_crc_err_cnt      ;
wire [31:0]             u1_p0_rcving_cnt       ;
wire [31:0]             u1_p1_rcving_cnt       ;
wire [31:0]             u1_p2_rcving_cnt       ;
wire [31:0]             u1_p3_rcving_cnt       ;
wire [15:0]             u1_p0_status_vector    ;
wire [15:0]             u1_p1_status_vector    ;
wire [15:0]             u1_p2_status_vector    ;
wire [15:0]             u1_p3_status_vector    ;
wire                    u1_rdispdec_er         ;
wire                    u1_signal_loss         ;
wire                    u1_cdr_align           ;
wire                    u1_tx_pll_lock         ;
wire                    u1_lsm_synced          ;
reg                     u2_pin_cfg_en          ;
wire [4:0]              u2_phy_addr            ;
reg  [1:0]              u2_phy_speed           ;
wire                    u2_phy_duplex          ;
wire                    u2_phy_link            ;
wire                    u2_unidir_en           ;
wire                    u2_an_restart          ;
wire                    u2_an_enable           ;
wire                    u2_loopback            ;
wire [20:0]             u2_link_timer_value    ;
wire [3:0]              u2_pma_nearend_sloop   ;
wire [3:0]              u2_pma_nearend_ploop   ;
wire [3:0]              u2_pcs_farend_loop     ;
wire [3:0]              u2_pcs_nearend_loop    ;
wire                    u2_rg_start_test       ;
wire                    u2_rg_length_cfg_en    ;
wire [18:0]             u2_rg_length_num       ;
wire                    u2_rg_pld_max_sel      ;
wire                    u2_rg_ipg_max_sel      ;
wire                    u2_rg_pre_max_sel      ;
wire                    u2_rg_pre_cfg_en       ;
wire [3:0]              u2_rg_pre_num          ;
wire                    u2_rg_ipg_cfg_en       ;
wire [7:0]              u2_rg_ipg_num          ;
wire                    u2_rg_wtchdg_sof_clr   ;
wire [3:0]              u2_rg_rx_lane_sof_rst_n;
wire [3:0]              u2_rg_tx_lane_sof_rst_n;
wire                    u2_rg_tx_pll_sof_rst_n ;
reg                     u2_rg_hsst_cfg_soft_rstn;
wire                    u2_rg_pkg_send_clr     ;
wire [3:0]              u2_rg_pkg_chk_clr      ;
wire [31:0]             u2_pkg_gen_cnt         ;
wire [31:0]             u2_p0_crc_ok_cnt       ;
wire [31:0]             u2_p1_crc_ok_cnt       ;
wire [31:0]             u2_p2_crc_ok_cnt       ;
wire [31:0]             u2_p3_crc_ok_cnt       ;
wire [31:0]             u2_p0_crc_err_cnt      ;
wire [31:0]             u2_p1_crc_err_cnt      ;
wire [31:0]             u2_p2_crc_err_cnt      ;
wire [31:0]             u2_p3_crc_err_cnt      ;
wire [31:0]             u2_p0_rcving_cnt       ;
wire [31:0]             u2_p1_rcving_cnt       ;
wire [31:0]             u2_p2_rcving_cnt       ;
wire [31:0]             u2_p3_rcving_cnt       ;
wire [15:0]             u2_p0_status_vector    ;
wire [15:0]             u2_p1_status_vector    ;
wire [15:0]             u2_p2_status_vector    ;
wire [15:0]             u2_p3_status_vector    ;
wire                    u2_rdispdec_er         ;
wire                    u2_signal_loss         ;
wire                    u2_cdr_align           ;
wire                    u2_tx_pll_lock         ;
wire                    u2_lsm_synced          ;

wire                    u1_p0_gmii_dv          ;
wire                    u1_p1_gmii_dv          ;
wire                    u1_p2_gmii_dv          ;
wire                    u1_p3_gmii_dv          ;
wire                    u2_p0_gmii_dv          ;
wire                    u2_p1_gmii_dv          ;
wire                    u2_p2_gmii_dv          ;
wire                    u2_p3_gmii_dv          ;
wire                    u1_p0_clk_en           ;
reg                     u1_p0_clk_en_d1        ;
wire                    u1_p1_clk_en           ;
reg                     u1_p1_clk_en_d1        ;
wire                    u1_p2_clk_en           ;
reg                     u1_p2_clk_en_d1        ;
wire                    u1_p3_clk_en           ;
reg                     u1_p3_clk_en_d1        ;
wire                    u2_p0_clk_en           ;
reg                     u2_p0_clk_en_d1        ;
wire                    u2_p1_clk_en           ;
reg                     u2_p1_clk_en_d1        ;
wire                    u2_p2_clk_en           ;
reg                     u2_p2_clk_en_d1        ;
wire                    u2_p3_clk_en           ;
reg                     u2_p3_clk_en_d1        ;
reg  [1:0]              u1_p0_gmii_dv_ff       ;
reg  [1:0]              u1_p1_gmii_dv_ff       ;
reg  [1:0]              u1_p2_gmii_dv_ff       ;
reg  [1:0]              u1_p3_gmii_dv_ff       ;
reg  [1:0]              u2_p0_gmii_dv_ff       ;
reg  [1:0]              u2_p1_gmii_dv_ff       ;
reg  [1:0]              u2_p2_gmii_dv_ff       ;
reg  [1:0]              u2_p3_gmii_dv_ff       ;
wire                    u1_p0_rcving_data_pulse;
reg                     u1_p0_rcving_data_pulse_d1;
wire                    u1_p1_rcving_data_pulse;
reg                     u1_p1_rcving_data_pulse_d1;
wire                    u1_p2_rcving_data_pulse;
reg                     u1_p2_rcving_data_pulse_d1;
wire                    u1_p3_rcving_data_pulse;
reg                     u1_p3_rcving_data_pulse_d1;
wire                    u2_p0_rcving_data_pulse;
reg                     u2_p0_rcving_data_pulse_d1;
wire                    u2_p1_rcving_data_pulse;
reg                     u2_p1_rcving_data_pulse_d1;
wire                    u2_p2_rcving_data_pulse;
reg                     u2_p2_rcving_data_pulse_d1;
wire                    u2_p3_rcving_data_pulse;
reg                     u2_p3_rcving_data_pulse_d1;
wire                    u1_check_valid         ;
wire                    u2_check_valid         ;
wire                    u1_rx_ok               ;
wire                    u2_rx_ok               ;
reg                     u1_p0_rx_ok            ;
reg                     u1_p1_rx_ok            ;
reg                     u1_p2_rx_ok            ;
reg                     u1_p3_rx_ok            ;
reg                     u2_p0_rx_ok            ;
reg                     u2_p1_rx_ok            ;
reg                     u2_p2_rx_ok            ;
reg                     u2_p3_rx_ok            ;
reg                     u1_check_result        ;
reg                     u2_check_result        ;
reg                     u1_lh_signal_loss      ;
reg                     u1_ll_cdr_align        ;
reg                     u1_ll_tx_pll_lock      ;
reg                     u1_ll_lsm_synced       ;
reg                     u2_lh_signal_loss      ;
reg                     u2_ll_cdr_align        ;
reg                     u2_ll_tx_pll_lock      ;
reg                     u2_ll_lsm_synced       ;
wire                    chk_rst_n              ;
reg                     clk_chk                ;

initial
begin
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_p0_phy_addr             = 5'd0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_p1_phy_addr             = 5'd1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_p2_phy_addr             = 5'd2    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_p3_phy_addr             = 5'd3    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_phy_duplex              = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_phy_link                = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_unidir_en               = 1'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_an_restart              = 1'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_an_enable               = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_loopback                = 1'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_pma_nearend_sloop       = 4'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_pma_nearend_ploop       = 4'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_pcs_farend_loop         = 4'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_pcs_nearend_loop        = 4'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_rg_length_cfg_en        = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_rg_length_num           = 19'd512 ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_rg_pld_max_sel          = 1'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_rg_ipg_max_sel          = 1'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_rg_pre_max_sel          = 1'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_rg_pre_cfg_en           = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_rg_pre_num              = 4'd6    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_rg_ipg_cfg_en           = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_rg_ipg_num              = 8'd11   ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_rg_wtchdg_sof_clr       = 1'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_rg_rx_lane_sof_rst_n    = 4'b1111 ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_rg_tx_lane_sof_rst_n    = 4'b1111 ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_rg_tx_pll_sof_rst_n     = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_rg_pkg_chk_clr          = 4'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_rg_pkg_send_clr         = 1'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_p0_soft_rstn            = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_p1_soft_rstn            = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_p2_soft_rstn            = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_p3_soft_rstn            = 1'b1    ;


    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_p0_phy_addr             = 5'd0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_p1_phy_addr             = 5'd1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_p2_phy_addr             = 5'd2    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_p3_phy_addr             = 5'd3    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_phy_duplex              = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_phy_link                = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_unidir_en               = 1'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_an_restart              = 1'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_an_enable               = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_loopback                = 1'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_pma_nearend_sloop       = 4'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_pma_nearend_ploop       = 4'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_pcs_farend_loop         = 4'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_pcs_nearend_loop        = 4'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_rg_length_cfg_en        = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_rg_length_num           = 19'd512 ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_rg_pld_max_sel          = 1'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_rg_ipg_max_sel          = 1'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_rg_pre_max_sel          = 1'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_rg_pre_cfg_en           = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_rg_pre_num              = 4'd6    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_rg_ipg_cfg_en           = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_rg_ipg_num              = 8'd11   ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_rg_wtchdg_sof_clr       = 1'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_rg_rx_lane_sof_rst_n    = 4'b1111 ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_rg_tx_lane_sof_rst_n    = 4'b1111 ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_rg_tx_pll_sof_rst_n     = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_rg_pkg_chk_clr          = 4'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_rg_pkg_send_clr         = 1'b0    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_p0_soft_rstn            = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_p1_soft_rstn            = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_p2_soft_rstn            = 1'b1    ;
    force ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_p3_soft_rstn            = 1'b1    ;
end

assign ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_pin_cfg_en         = u1_pin_cfg_en   ;
assign ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_phy_speed          = u1_phy_speed    ;
assign ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_external_rstn      = u1_external_rstn;
assign ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_pin_cfg_en         = u2_pin_cfg_en   ;
assign ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_phy_speed          = u2_phy_speed    ;
assign ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_external_rstn      = u2_external_rstn;



assign u1_rx_clk = ipsxb_qsgmii_dut_top_tb.U_inst_tb.u1_clk_rx;
assign u2_rx_clk = ipsxb_qsgmii_dut_top_tb.U_inst_tb.u2_clk_rx;

assign u1_check_valid = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.U_qsgmii_test.hsst_ch_ready[0];
assign u2_check_valid = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.U_qsgmii_test.hsst_ch_ready[0];

assign u1_p0_gmii_dv = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.p0_pkg_chk.rx_dv;
assign u1_p0_clk_en = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.p0_pkg_chk.clk_en;
assign u1_p0_crc_ok_cnt = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.p0_crc_ok_cnt;
assign u1_p0_rcving_cnt = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.p0_rcving_cnt;

assign u2_p0_gmii_dv = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.p0_pkg_chk.rx_dv;
assign u2_p0_clk_en = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.p0_pkg_chk.clk_en;
assign u2_p0_crc_ok_cnt = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.p0_crc_ok_cnt;
assign u2_p0_rcving_cnt = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.p0_rcving_cnt;

assign u1_p1_gmii_dv = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.p1_pkg_chk.rx_dv;
assign u1_p1_clk_en = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.p1_pkg_chk.clk_en;
assign u1_p1_crc_ok_cnt = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.p1_crc_ok_cnt;
assign u1_p1_rcving_cnt = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.p1_rcving_cnt;

assign u2_p1_gmii_dv = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.p1_pkg_chk.rx_dv;
assign u2_p1_clk_en = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.p1_pkg_chk.clk_en;
assign u2_p1_crc_ok_cnt = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.p1_crc_ok_cnt;
assign u2_p1_rcving_cnt = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.p1_rcving_cnt;

assign u1_p2_gmii_dv = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.p2_pkg_chk.rx_dv;
assign u1_p2_clk_en = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.p2_pkg_chk.clk_en;
assign u1_p2_crc_ok_cnt = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.p2_crc_ok_cnt;
assign u1_p2_rcving_cnt = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.p2_rcving_cnt;

assign u2_p2_gmii_dv = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.p2_pkg_chk.rx_dv;
assign u2_p2_clk_en = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.p2_pkg_chk.clk_en;
assign u2_p2_crc_ok_cnt = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.p2_crc_ok_cnt;
assign u2_p2_rcving_cnt = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.p2_rcving_cnt;

assign u1_p3_gmii_dv = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.p3_pkg_chk.rx_dv;
assign u1_p3_clk_en = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.p3_pkg_chk.clk_en;
assign u1_p3_crc_ok_cnt = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.p3_crc_ok_cnt;
assign u1_p3_rcving_cnt = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.p3_rcving_cnt;

assign u2_p3_gmii_dv = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.p3_pkg_chk.rx_dv;
assign u2_p3_clk_en = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.p3_pkg_chk.clk_en;
assign u2_p3_crc_ok_cnt = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.p3_crc_ok_cnt;
assign u2_p3_rcving_cnt = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.p3_rcving_cnt;

assign u1_signal_loss = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.signal_loss;
assign u1_cdr_align = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.cdr_align;
assign u1_tx_pll_lock = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.tx_pll_lock;
assign u1_lsm_synced = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U1_ipsxb_qsgmii_dut.lsm_synced;

assign u2_signal_loss = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.signal_loss;
assign u2_cdr_align = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.cdr_align;
assign u2_tx_pll_lock = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.tx_pll_lock;
assign u2_lsm_synced = ipsxb_qsgmii_dut_top_tb.U_inst_tb.U2_ipsxb_qsgmii_dut.lsm_synced;

assign u1_p0_rcving_data_pulse = ~u1_p0_gmii_dv_ff[0] & u1_p0_gmii_dv_ff[1];
assign u1_p1_rcving_data_pulse = ~u1_p1_gmii_dv_ff[0] & u1_p1_gmii_dv_ff[1];
assign u1_p2_rcving_data_pulse = ~u1_p2_gmii_dv_ff[0] & u1_p2_gmii_dv_ff[1];
assign u1_p3_rcving_data_pulse = ~u1_p3_gmii_dv_ff[0] & u1_p3_gmii_dv_ff[1];
assign u2_p0_rcving_data_pulse = ~u2_p0_gmii_dv_ff[0] & u2_p0_gmii_dv_ff[1];
assign u2_p1_rcving_data_pulse = ~u2_p1_gmii_dv_ff[0] & u2_p1_gmii_dv_ff[1];
assign u2_p2_rcving_data_pulse = ~u2_p2_gmii_dv_ff[0] & u2_p2_gmii_dv_ff[1];
assign u2_p3_rcving_data_pulse = ~u2_p3_gmii_dv_ff[0] & u2_p3_gmii_dv_ff[1];

//check clock
initial
begin
    clk_chk = 0;
    forever #1.0 clk_chk = ~clk_chk;
end

assign chk_rst_n = u1_check_valid & u2_check_valid;

always @(posedge u1_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n == 1'b0)begin
        u1_p0_gmii_dv_ff <= 2'b0;
    end
    else if(u1_p0_clk_en)begin
        u1_p0_gmii_dv_ff <= {u1_p0_gmii_dv_ff[0],u1_p0_gmii_dv};
    end
end

always @(posedge u1_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n == 1'b0)begin
        u1_p1_gmii_dv_ff <= 2'b0;
    end
    else if(u1_p1_clk_en)begin
        u1_p1_gmii_dv_ff <= {u1_p1_gmii_dv_ff[0],u1_p1_gmii_dv};
    end
end

always @(posedge u1_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n == 1'b0)begin
        u1_p2_gmii_dv_ff <= 2'b0;
    end
    else if(u1_p2_clk_en)begin
        u1_p2_gmii_dv_ff <= {u1_p2_gmii_dv_ff[0],u1_p2_gmii_dv};
    end
end

always @(posedge u1_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n == 1'b0)begin
        u1_p3_gmii_dv_ff <= 2'b0;
    end
    else if(u1_p3_clk_en)begin
        u1_p3_gmii_dv_ff <= {u1_p3_gmii_dv_ff[0],u1_p3_gmii_dv};
    end
end

always @(posedge u2_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n == 1'b0)begin
        u2_p0_gmii_dv_ff <= 2'b0;
    end
    else if(u2_p0_clk_en)begin
        u2_p0_gmii_dv_ff <= {u2_p0_gmii_dv_ff[0],u2_p0_gmii_dv};
    end
end

always @(posedge u2_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n == 1'b0)begin
        u2_p1_gmii_dv_ff <= 2'b0;
    end
    else if(u2_p1_clk_en)begin
        u2_p1_gmii_dv_ff <= {u2_p1_gmii_dv_ff[0],u2_p1_gmii_dv};
    end
end

always @(posedge u2_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n == 1'b0)begin
        u2_p2_gmii_dv_ff <= 2'b0;
    end
    else if(u2_p2_clk_en)begin
        u2_p2_gmii_dv_ff <= {u2_p2_gmii_dv_ff[0],u2_p2_gmii_dv};
    end
end

always @(posedge u2_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n == 1'b0)begin
        u2_p3_gmii_dv_ff <= 2'b0;
    end
    else if(u2_p3_clk_en)begin
        u2_p3_gmii_dv_ff <= {u2_p3_gmii_dv_ff[0],u2_p3_gmii_dv};
    end
end

always @(posedge u1_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n == 1'b0)begin
        u1_p0_rcving_data_pulse_d1 <= 1'b0;
        u1_p0_clk_en_d1 <= 1'b0;
    end
    else begin
        u1_p0_rcving_data_pulse_d1 <= u1_p0_rcving_data_pulse;
        u1_p0_clk_en_d1 <= u1_p0_clk_en;
    end
end

always @(posedge u1_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n == 1'b0)begin
        u1_p1_rcving_data_pulse_d1 <= 1'b0;
        u1_p1_clk_en_d1 <= 1'b0;
    end
    else begin
        u1_p1_rcving_data_pulse_d1 <= u1_p1_rcving_data_pulse;
        u1_p1_clk_en_d1 <= u1_p1_clk_en;
    end
end

always @(posedge u1_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n == 1'b0)begin
        u1_p2_rcving_data_pulse_d1 <= 1'b0;
        u1_p2_clk_en_d1 <= 1'b0;
    end
    else begin
        u1_p2_rcving_data_pulse_d1 <= u1_p2_rcving_data_pulse;
        u1_p2_clk_en_d1 <= u1_p2_clk_en;
    end
end

always @(posedge u1_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n == 1'b0)begin
        u1_p3_rcving_data_pulse_d1 <= 1'b0;
        u1_p3_clk_en_d1 <= 1'b0;
    end
    else begin
        u1_p3_rcving_data_pulse_d1 <= u1_p3_rcving_data_pulse;
        u1_p3_clk_en_d1 <= u1_p3_clk_en;
    end
end

always @(posedge u2_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n == 1'b0)begin
        u2_p0_rcving_data_pulse_d1 <= 1'b0;
        u2_p0_clk_en_d1 <= 1'b0;
    end
    else begin
        u2_p0_rcving_data_pulse_d1 <= u2_p0_rcving_data_pulse;
        u2_p0_clk_en_d1 <= u2_p0_clk_en;
    end
end

always @(posedge u2_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n == 1'b0)begin
        u2_p1_rcving_data_pulse_d1 <= 1'b0;
        u2_p1_clk_en_d1 <= 1'b0;
    end
    else begin
        u2_p1_rcving_data_pulse_d1 <= u2_p1_rcving_data_pulse;
        u2_p1_clk_en_d1 <= u2_p1_clk_en;
    end
end

always @(posedge u2_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n == 1'b0)begin
        u2_p2_rcving_data_pulse_d1 <= 1'b0;
        u2_p2_clk_en_d1 <= 1'b0;
    end
    else begin
        u2_p2_rcving_data_pulse_d1 <= u2_p2_rcving_data_pulse;
        u2_p2_clk_en_d1 <= u2_p2_clk_en;
    end
end

always @(posedge u2_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n == 1'b0)begin
        u2_p3_rcving_data_pulse_d1 <= 1'b0;
        u2_p3_clk_en_d1 <= 1'b0;
    end
    else begin
        u2_p3_rcving_data_pulse_d1 <= u2_p3_rcving_data_pulse;
        u2_p3_clk_en_d1 <= u2_p3_clk_en;
    end
end

//************************DUT1***********************************//
always @(posedge u1_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n ==1'b0)begin
        u1_p0_rx_ok <= 1'b1;
    end
    else if(u1_p0_rcving_data_pulse_d1 == 1'b1 & u1_p0_clk_en_d1)begin
        if(u1_p0_crc_ok_cnt != u1_p0_rcving_cnt)begin
            u1_p0_rx_ok <= 1'b0;
        end
        else;
    end
    else begin
        u1_p0_rx_ok <= u1_p0_rx_ok;
    end
end

always @(posedge u1_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n ==1'b0)begin
        u1_p1_rx_ok <= 1'b1;
    end
    else if(u1_p1_rcving_data_pulse_d1 == 1'b1 & u1_p1_clk_en_d1)begin
        if(u1_p1_crc_ok_cnt != u1_p1_rcving_cnt)begin
            u1_p1_rx_ok <= 1'b0;
        end
        else;
    end
    else begin
        u1_p1_rx_ok <= u1_p1_rx_ok;
    end
end

always @(posedge u1_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n ==1'b0)begin
        u1_p2_rx_ok <= 1'b1;
    end
    else if(u1_p2_rcving_data_pulse_d1 == 1'b1 & u1_p2_clk_en_d1)begin
        if(u1_p2_crc_ok_cnt != u1_p2_rcving_cnt)begin
            u1_p2_rx_ok <= 1'b0;
        end
        else;
    end
    else begin
        u1_p2_rx_ok <= u1_p2_rx_ok;
    end
end

always @(posedge u1_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n ==1'b0)begin
        u1_p3_rx_ok <= 1'b1;
    end
    else if(u1_p3_rcving_data_pulse_d1 == 1'b1 & u1_p3_clk_en_d1)begin
        if(u1_p3_crc_ok_cnt != u1_p3_rcving_cnt)begin
            u1_p3_rx_ok <= 1'b0;
        end
        else;
    end
    else begin
        u1_p3_rx_ok <= u1_p3_rx_ok;
    end
end

assign u1_rx_ok = u1_p0_rx_ok & u1_p1_rx_ok & u1_p2_rx_ok & u1_p3_rx_ok;

always @(posedge clk_chk)
begin
    if(chk_rst_n == 1'b0)begin
        u1_lh_signal_loss <= 1'b0;
    end
    else if(u1_signal_loss ==1'b1)begin
        u1_lh_signal_loss <= 1'b1;
    end
end

always @(posedge clk_chk)
begin
    if(chk_rst_n == 1'b0)begin
        u1_ll_cdr_align <= 1'b1;
    end
    else if(u1_cdr_align == 1'b0)begin
        u1_ll_cdr_align <= 1'b0;
    end
end

always @(posedge clk_chk)
begin
    if(chk_rst_n == 1'b0)begin
        u1_ll_tx_pll_lock <= 1'b1;
    end
    else if(u1_tx_pll_lock == 1'b0)begin
        u1_ll_tx_pll_lock <= 1'b0;
    end
end

always @(posedge clk_chk)
begin
    if(chk_rst_n == 1'b0)begin
        u1_ll_lsm_synced <= 1'b1;
    end
    else if(u1_lsm_synced == 1'b0)begin
        u1_ll_lsm_synced <= 1'b0;
    end
end

//************************DUT2**********************//

always @(posedge u2_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n ==1'b0)begin
        u2_p0_rx_ok <= 1'b1;
    end
    else if(u2_p0_rcving_data_pulse_d1 == 1'b1 & u2_p0_clk_en_d1)begin
        if(u2_p0_crc_ok_cnt != u2_p0_rcving_cnt)begin
            u2_p0_rx_ok <= 1'b0;
        end
        else;
    end
    else begin
        u2_p0_rx_ok <= u2_p0_rx_ok;
    end
end

always @(posedge u2_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n ==1'b0)begin
        u2_p1_rx_ok <= 1'b1;
    end
    else if(u2_p1_rcving_data_pulse_d1 == 1'b1 & u2_p1_clk_en_d1)begin
        if(u2_p1_crc_ok_cnt != u2_p1_rcving_cnt)begin
            u2_p1_rx_ok <= 1'b0;
        end
        else;
    end
    else begin
        u2_p1_rx_ok <= u2_p1_rx_ok;
    end
end

always @(posedge u2_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n ==1'b0)begin
        u2_p2_rx_ok <= 1'b1;
    end
    else if(u2_p2_rcving_data_pulse_d1 == 1'b1 & u2_p2_clk_en_d1)begin
        if(u2_p2_crc_ok_cnt != u2_p2_rcving_cnt)begin
            u2_p2_rx_ok <= 1'b0;
        end
        else;
    end
    else begin
        u2_p2_rx_ok <= u2_p2_rx_ok;
    end
end

always @(posedge u2_rx_clk or negedge chk_rst_n)
begin
    if(chk_rst_n ==1'b0)begin
        u2_p3_rx_ok <= 1'b1;
    end
    else if(u2_p3_rcving_data_pulse_d1 == 1'b1 & u2_p3_clk_en_d1)begin
        if(u2_p3_crc_ok_cnt != u2_p3_rcving_cnt)begin
            u2_p3_rx_ok <= 1'b0;
        end
        else;
    end
    else begin
        u2_p3_rx_ok <= u2_p3_rx_ok;
    end
end

assign u2_rx_ok = u2_p0_rx_ok & u2_p1_rx_ok & u2_p2_rx_ok & u2_p3_rx_ok;

always @(posedge clk_chk)
begin
    if(chk_rst_n == 1'b0)begin
        u2_lh_signal_loss <= 1'b0;
    end
    else if(u2_signal_loss == 1'b1)begin
        u2_lh_signal_loss <= 1'b1;
    end
end

always @(posedge clk_chk)
begin
    if(chk_rst_n == 1'b0)begin
        u2_ll_cdr_align <= 1'b1;
    end
    else if(u2_cdr_align == 1'b0)begin
        u2_ll_cdr_align <= 1'b0;
    end
end

always @(posedge clk_chk)
begin
    if(chk_rst_n == 1'b0)begin
        u2_ll_tx_pll_lock <= 1'b1;
    end
    else if(u2_tx_pll_lock == 1'b0)begin
        u2_ll_tx_pll_lock <= 1'b0;
    end
end

always @(posedge clk_chk)
begin
    if(chk_rst_n == 1'b0)begin
        u2_ll_lsm_synced <= 1'b1;
    end
    else if(u2_lsm_synced == 1'b0)begin
        u2_ll_lsm_synced <= 1'b0;
    end
end

//Check Rseult

always @(posedge clk_chk)
begin
    if(chk_rst_n == 1'b0)begin
        u1_check_result <= 1'b1;
    end
    else begin
        u1_check_result <= {(u1_rx_ok ==1'b1) &
                            (u1_lh_signal_loss == 1'b0) &
                            (u1_ll_cdr_align == 1'b1) &
                            (u1_ll_tx_pll_lock == 1'b1) &
                            (u1_ll_lsm_synced == 1'b1)};
    end
end

always @(posedge clk_chk)
begin
    if(chk_rst_n == 1'b0)begin
        u2_check_result <= 1'b1;
    end
    else begin
        u2_check_result <= {(u2_rx_ok ==1'b1) &
                            (u2_lh_signal_loss == 1'b0) &
                            (u2_ll_cdr_align == 1'b1) &
                            (u2_ll_tx_pll_lock == 1'b1) &
                            (u2_ll_lsm_synced == 1'b1)};
    end
end


integer handle;
initial
begin

        test1;              //QSGMII 10M
        $display("\n QSGMII Mac Mode Simulation Finished!");
        $finish;
        
end

task test1;         //QSGMII 10M
begin
    #5;
    u1_external_rstn = 1'b0;
    #5;
    u2_external_rstn = 1'b0;
    #40;
    u1_external_rstn = 1'b1;
    #40;
    u2_external_rstn = 1'b1;
    $display("\n %t :QSGMII Mac Mode 10Mbps Simulation Started!",$time);
    u1_phy_speed[1]  = 0;     //Speed Control {ctrl1,ctrl0} 10: 1000Mbps, 01: 100Mbps, 00: 10Mbps
    u1_phy_speed[0]  = 0;     //QSGMII Mode Depend on {ctrl1,ctrl0}
    u2_phy_speed[1]  = 0;
    u2_phy_speed[0]  = 0;
    #4500000;
    u1_pin_cfg_en    = 1;     //pin_cfg_en  0:pin configure invalid  1:pin configure valid
    u2_pin_cfg_en    = 1;
    #8000000;
    u1_pin_cfg_en    = 0;
    u2_pin_cfg_en    = 0;

wait((u1_check_result == 1'b0) || (u2_check_result == 1'b0) || ((U_inst_tb.U1_ipsxb_qsgmii_dut.p0_pkg_chk.crc_ok_cnt[2:0] >= 3'd3) & (U_inst_tb.U1_ipsxb_qsgmii_dut.p1_pkg_chk.crc_ok_cnt[2:0] >= 3'd3) & (U_inst_tb.U1_ipsxb_qsgmii_dut.p2_pkg_chk.crc_ok_cnt[2:0] >= 3'd3) & (U_inst_tb.U1_ipsxb_qsgmii_dut.p3_pkg_chk.crc_ok_cnt[2:0] >= 3'd3)))
    handle = $fopen ("vsim_ipsxb_qsgmii_dut_tb.log","a");
    $fdisplay(handle,"u1_rx_ok          = 1'b%b"    ,u1_rx_ok           );
    $fdisplay(handle,"u1_lh_signal_loss = 1'b%b"    ,u1_lh_signal_loss  );
    $fdisplay(handle,"u1_ll_cdr_align   = 1'b%b"    ,u1_ll_cdr_align    );
    $fdisplay(handle,"u1_ll_lsm_synced  = 1'b%b"    ,u1_ll_lsm_synced   );
    $fdisplay(handle,"u2_rx_ok          = 1'b%b"    ,u2_rx_ok           );
    $fdisplay(handle,"u2_lh_signal_loss = 1'b%b"    ,u2_lh_signal_loss  );
    $fdisplay(handle,"u2_ll_cdr_align   = 1'b%b"    ,u2_ll_cdr_align    );
    $fdisplay(handle,"u2_ll_lsm_synced  = 1'b%b"    ,u2_ll_lsm_synced   );
    if (u1_check_result==1'b0 || u2_check_result== 1'b0) begin
        $fdisplay(handle,"QSGMII Mac Mode 10Mbps Simulation Failed!");
        $display("Simulation Failed.") ;
        $finish;
    end
    else begin
        $fdisplay(handle,"QSGMII Mac Mode 10Mbps Simulation Success!");
        $display("Simulation Success.") ;
    end
    $fclose (handle);

    #50000;
    $display("\n %t :QSGMII Mac Mode 10Mbps Simulation Finished!",$time);
end
endtask
        
endmodule
