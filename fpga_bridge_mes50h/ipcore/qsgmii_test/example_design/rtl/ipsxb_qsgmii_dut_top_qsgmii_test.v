
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
`timescale 1ns/1ps

module ipsxb_qsgmii_dut_top_qsgmii_test(

    input  wire        P_REFCKN                ,
    input  wire        P_REFCKP                ,
    output wire        P_L0TXN                 ,
    output wire        P_L0TXP                 ,
    input  wire        P_L0RXN                 ,
    input  wire        P_L0RXP                 ,
//CLK AND Restt
    input  wire        free_clk                ,
    input  wire        external_rstn           ,
    input  wire        p0_soft_rstn            ,
    input  wire        p1_soft_rstn            ,
    input  wire        p2_soft_rstn            ,
    input  wire        p3_soft_rstn            ,
    output wire        clk_tx                  ,
    output wire        clk_rx                  ,
    output wire        tx_rst_n                ,
    output wire        rx_rst_n                ,
//Debug LED
    output wire        ok_led                  ,
    output wire        cdr_align               ,
    output wire        tx_pll_lock             ,
    output wire        lsm_synced              ,
    output wire        an_status               ,

    output wire        cfg_rstn                ,
    input  wire        p0_pin_cfg_en           ,
    input  wire        p0_phy_link             ,
    input  wire        p0_phy_duplex           ,
    input  wire [1:0]  p0_phy_speed            ,
    input  wire        p0_unidir_en            ,
    input  wire        p0_an_restart           ,
    input  wire        p0_an_enable            ,
    input  wire        p0_loopback             ,
    input  wire        p1_pin_cfg_en           ,
    input  wire        p1_phy_link             ,
    input  wire        p1_phy_duplex           ,
    input  wire [1:0]  p1_phy_speed            ,
    input  wire        p1_unidir_en            ,
    input  wire        p1_an_restart           ,
    input  wire        p1_an_enable            ,
    input  wire        p1_loopback             ,
    input  wire        p2_pin_cfg_en           ,
    input  wire        p2_phy_link             ,
    input  wire        p2_phy_duplex           ,
    input  wire [1:0]  p2_phy_speed            ,
    input  wire        p2_unidir_en            ,
    input  wire        p2_an_restart           ,
    input  wire        p2_an_enable            ,
    input  wire        p2_loopback             ,
    input  wire        p3_pin_cfg_en           ,
    input  wire        p3_phy_link             ,
    input  wire        p3_phy_duplex           ,
    input  wire [1:0]  p3_phy_speed            ,
    input  wire        p3_unidir_en            ,
    input  wire        p3_an_restart           ,
    input  wire        p3_an_enable            ,
    input  wire        p3_loopback             ,
    input  wire [3:0]  pma_nearend_sloop       ,
    input  wire [3:0]  pma_nearend_ploop       ,
    input  wire [3:0]  pcs_farend_loop         ,
    input  wire [3:0]  pcs_nearend_loop        ,
    input  wire        rg_wtchdg_sof_clr       ,
    input  wire [3:0]  rg_rx_lane_sof_rst_n    ,
    input  wire [3:0]  rg_tx_lane_sof_rst_n    ,
    input  wire        rg_tx_pll_sof_rst_n     ,
    input  wire        rg_hsst_cfg_soft_rstn   ,
    input  wire        p0_rg_start_test        ,
    input  wire        p0_rg_length_cfg_en     ,
    input  wire [18:0] p0_rg_length_num        ,
    input  wire        p0_rg_pld_max_sel       ,
    input  wire        p0_rg_ipg_max_sel       ,
    input  wire        p0_rg_pre_max_sel       ,
    input  wire        p0_rg_burst_tx_en       ,
    input  wire        p0_rg_pre_cfg_en        ,
    input  wire [3:0]  p0_rg_pre_num           ,
    input  wire        p0_rg_ipg_cfg_en        ,
    input  wire [7:0]  p0_rg_ipg_num           ,
    input  wire [3:0]  p0_rg_pkg_chk_clr       ,
    input  wire        p0_rg_pkg_send_clr      ,
    output wire [31:0] p0_pkg_gen_cnt          ,
    output wire [31:0] p0_crc_ok_cnt           ,
    output wire [31:0] p0_crc_err_cnt          ,
    output wire [31:0] p0_rcving_cnt           ,
    output wire [31:0] p0_byte_cnt             ,
    output wire [15:0] p0_status_vector        ,
    input  wire        p1_rg_start_test        ,
    input  wire        p1_rg_length_cfg_en     ,
    input  wire [18:0] p1_rg_length_num        ,
    input  wire        p1_rg_pld_max_sel       ,
    input  wire        p1_rg_ipg_max_sel       ,
    input  wire        p1_rg_pre_max_sel       ,
    input  wire        p1_rg_burst_tx_en       ,
    input  wire        p1_rg_pre_cfg_en        ,
    input  wire [3:0]  p1_rg_pre_num           ,
    input  wire        p1_rg_ipg_cfg_en        ,
    input  wire [7:0]  p1_rg_ipg_num           ,
    input  wire [3:0]  p1_rg_pkg_chk_clr       ,
    input  wire        p1_rg_pkg_send_clr      ,
    output wire [31:0] p1_pkg_gen_cnt          ,
    output wire [31:0] p1_crc_ok_cnt           ,
    output wire [31:0] p1_crc_err_cnt          ,
    output wire [31:0] p1_rcving_cnt           ,
    output wire [31:0] p1_byte_cnt             ,
    output wire [15:0] p1_status_vector        ,
    input  wire        p2_rg_start_test        ,
    input  wire        p2_rg_length_cfg_en     ,
    input  wire [18:0] p2_rg_length_num        ,
    input  wire        p2_rg_pld_max_sel       ,
    input  wire        p2_rg_ipg_max_sel       ,
    input  wire        p2_rg_pre_max_sel       ,
    input  wire        p2_rg_burst_tx_en       ,
    input  wire        p2_rg_pre_cfg_en        ,
    input  wire [3:0]  p2_rg_pre_num           ,
    input  wire        p2_rg_ipg_cfg_en        ,
    input  wire [7:0]  p2_rg_ipg_num           ,
    input  wire [3:0]  p2_rg_pkg_chk_clr       ,
    input  wire        p2_rg_pkg_send_clr      ,
    output wire [31:0] p2_pkg_gen_cnt          ,
    output wire [31:0] p2_crc_ok_cnt           ,
    output wire [31:0] p2_crc_err_cnt          ,
    output wire [31:0] p2_rcving_cnt           ,
    output wire [31:0] p2_byte_cnt             ,
    output wire [15:0] p2_status_vector        ,
    input  wire        p3_rg_start_test        ,
    input  wire        p3_rg_length_cfg_en     ,
    input  wire [18:0] p3_rg_length_num        ,
    input  wire        p3_rg_pld_max_sel       ,
    input  wire        p3_rg_ipg_max_sel       ,
    input  wire        p3_rg_pre_max_sel       ,
    input  wire        p3_rg_burst_tx_en       ,
    input  wire        p3_rg_pre_cfg_en        ,
    input  wire [3:0]  p3_rg_pre_num           ,
    input  wire        p3_rg_ipg_cfg_en        ,
    input  wire [7:0]  p3_rg_ipg_num           ,
    input  wire [3:0]  p3_rg_pkg_chk_clr       ,
    input  wire        p3_rg_pkg_send_clr      ,
    output wire [31:0] p3_pkg_gen_cnt          ,
    output wire [31:0] p3_crc_ok_cnt           ,
    output wire [31:0] p3_crc_err_cnt          ,
    output wire [31:0] p3_rcving_cnt           ,
    output wire [31:0] p3_byte_cnt             ,
    output wire [15:0] p3_status_vector        ,
    output wire        rdispdec_er             ,
    output wire        signal_loss             ,

//APB
    input  wire        pclk                    ,
    input  wire [20:0] paddr                   ,
    input  wire        pwrite                  ,
    input  wire        psel                    ,
    input  wire        penable                 ,
    input  wire [31:0] pwdata                  ,
    output wire [31:0] prdata                  ,
    output wire        pready                  ,
//Debug
    output wire [3:0]  l0_pcs_txk              ,
    output wire [31:0] l0_pcs_txd              ,
    output wire        l0_pcs_rx_clk           ,
    output wire [3:0]  l0_pcs_rxk              ,
    output wire [31:0] l0_pcs_rxd

);

wire    [3:0]        hsst_ch_ready          ;
wire                 l0_pcs_rdispdec_er     ;
wire    [3:0]        l0_pcs_tx_dispctrl     ;
wire    [3:0]        l0_pcs_tx_dispsel      ;
wire    [3:0]        p0_AN_CS               ;
wire    [3:0]        p0_AN_NS               ;
wire    [4:0]        p0_RS_CS               ;
wire    [4:0]        p0_RS_NS               ;
wire    [4:0]        p0_TS_CS               ;
wire    [4:0]        p0_TS_NS               ;
wire    [1:0]        p0_rx_unitdata_indicate;
wire    [1:0]        p0_xmit                ;
wire                 p0_crc_ok              ;
wire                 p0_sgmii_clk           ;
wire                 p0_tx_clken            ;
wire                 p0_tx_rstn             ;
wire    [7:0]        p0_gmii_txd            ;
wire                 p0_gmii_tx_en          ;
wire                 p0_gmii_tx_er          ;
wire    [7:0]        p0_gmii_rxd            ;
wire                 p0_gmii_rx_dv          ;
wire                 p0_gmii_rx_er          ;
wire                 p0_rx_clken            ;
wire                 p0_sgmii_rx_clk        ;
wire                 p0_rx_rstn             ;
wire [1:0]           p0_sgmii_speed_sync    ;
wire                 p0_ok_led              ;
wire                 p0_an_status           ;
wire                 p0_cfg_rst_n           ;
wire [18:0]          p0_paddr               ;
wire                 p0_pwrite              ;
wire                 p0_psel                ;
wire                 p0_penable             ;
wire [31:0]          p0_pwdata              ;
wire [31:0]          p0_prdata              ;
wire                 p0_pready              ;

wire    [3:0]        p1_AN_CS               ;
wire    [3:0]        p1_AN_NS               ;
wire    [4:0]        p1_RS_CS               ;
wire    [4:0]        p1_RS_NS               ;
wire    [4:0]        p1_TS_CS               ;
wire    [4:0]        p1_TS_NS               ;
wire    [1:0]        p1_rx_unitdata_indicate;
wire    [1:0]        p1_xmit                ;
wire                 p1_crc_ok              ;
wire                 p1_sgmii_clk           ;
wire                 p1_tx_clken            ;
wire                 p1_tx_rstn             ;
wire    [7:0]        p1_gmii_txd            ;
wire                 p1_gmii_tx_en          ;
wire                 p1_gmii_tx_er          ;
wire    [7:0]        p1_gmii_rxd            ;
wire                 p1_gmii_rx_dv          ;
wire                 p1_gmii_rx_er          ;
wire                 p1_rx_clken            ;
wire                 p1_sgmii_rx_clk        ;
wire                 p1_rx_rstn             ;
wire [1:0]           p1_sgmii_speed_sync    ;
wire                 p1_ok_led              ;
wire                 p1_an_status           ;
wire                 p1_cfg_rst_n           ;
wire [18:0]          p1_paddr               ;
wire                 p1_pwrite              ;
wire                 p1_psel                ;
wire                 p1_penable             ;
wire [31:0]          p1_pwdata              ;
wire [31:0]          p1_prdata              ;
wire                 p1_pready              ;

wire    [3:0]        p2_AN_CS               ;
wire    [3:0]        p2_AN_NS               ;
wire    [4:0]        p2_RS_CS               ;
wire    [4:0]        p2_RS_NS               ;
wire    [4:0]        p2_TS_CS               ;
wire    [4:0]        p2_TS_NS               ;
wire    [1:0]        p2_rx_unitdata_indicate;
wire    [1:0]        p2_xmit                ;
wire                 p2_crc_ok              ;
wire                 p2_sgmii_clk           ;
wire                 p2_tx_clken            ;
wire                 p2_tx_rstn             ;
wire    [7:0]        p2_gmii_txd            ;
wire                 p2_gmii_tx_en          ;
wire                 p2_gmii_tx_er          ;
wire    [7:0]        p2_gmii_rxd            ;
wire                 p2_gmii_rx_dv          ;
wire                 p2_gmii_rx_er          ;
wire                 p2_rx_clken            ;
wire                 p2_sgmii_rx_clk        ;
wire                 p2_rx_rstn             ;
wire [1:0]           p2_sgmii_speed_sync    ;
wire                 p2_ok_led              ;
wire                 p2_an_status           ;
wire                 p2_cfg_rst_n           ;
wire [18:0]          p2_paddr               ;
wire                 p2_pwrite              ;
wire                 p2_psel                ;
wire                 p2_penable             ;
wire [31:0]          p2_pwdata              ;
wire [31:0]          p2_prdata              ;
wire                 p2_pready              ;

wire    [3:0]        p3_AN_CS               ;
wire    [3:0]        p3_AN_NS               ;
wire    [4:0]        p3_RS_CS               ;
wire    [4:0]        p3_RS_NS               ;
wire    [4:0]        p3_TS_CS               ;
wire    [4:0]        p3_TS_NS               ;
wire    [1:0]        p3_rx_unitdata_indicate;
wire    [1:0]        p3_xmit                ;
wire                 p3_crc_ok              ;
wire                 p3_sgmii_clk           ;
wire                 p3_tx_clken            ;
wire                 p3_tx_rstn             ;
wire    [7:0]        p3_gmii_txd            ;
wire                 p3_gmii_tx_en          ;
wire                 p3_gmii_tx_er          ;
wire    [7:0]        p3_gmii_rxd            ;
wire                 p3_gmii_rx_dv          ;
wire                 p3_gmii_rx_er          ;
wire                 p3_rx_clken            ;
wire                 p3_sgmii_rx_clk        ;
wire                 p3_rx_rstn             ;
wire [1:0]           p3_sgmii_speed_sync    ;
wire                 p3_ok_led              ;
wire                 p3_an_status           ;
wire                 p3_cfg_rst_n           ;
wire [18:0]          p3_paddr               ;
wire                 p3_pwrite              ;
wire                 p3_psel                ;
wire                 p3_penable             ;
wire [31:0]          p3_pwdata              ;
wire [31:0]          p3_prdata              ;
wire                 p3_pready              ;

wire                 qsgmii_tx_rstn         ;
wire                 qsgmii_rx_rstn         ;
wire                 l0_pcs_clk             ;


assign rdispdec_er  = l0_pcs_rdispdec_er;
assign p0_an_status = p0_status_vector[0];
assign p1_an_status = p1_status_vector[0];
assign p2_an_status = p2_status_vector[0];
assign p3_an_status = p3_status_vector[0];
assign an_status = p0_an_status & p1_an_status & p2_an_status & p3_an_status;
assign ok_led = p0_ok_led & p1_ok_led & p2_ok_led & p3_ok_led;
assign clk_tx = l0_pcs_clk;
assign tx_rst_n = qsgmii_tx_rstn;
assign rx_rst_n = qsgmii_rx_rstn;
assign cfg_rstn = p0_cfg_rst_n | p1_cfg_rst_n | p2_cfg_rst_n | p3_cfg_rst_n;

assign clk_rx = l0_pcs_clk;

ips_sgmii_handshake_sync_v1_0 #(.DATA_WIDTH(2), .DFT_VALUE(2'b10))
    p0_sgmii_speed_pkgsync (.src_clk(pclk), .src_rstn(p0_cfg_rst_n), .src_data(p0_status_vector[4:3]), .des_clk(p0_sgmii_clk), .des_rstn(p0_tx_rstn), .des_data(p0_sgmii_speed_sync));
ips_sgmii_handshake_sync_v1_0 #(.DATA_WIDTH(2), .DFT_VALUE(2'b10))
    p1_sgmii_speed_pkgsync (.src_clk(pclk), .src_rstn(p1_cfg_rst_n), .src_data(p1_status_vector[4:3]), .des_clk(p1_sgmii_clk), .des_rstn(p1_tx_rstn), .des_data(p1_sgmii_speed_sync));
ips_sgmii_handshake_sync_v1_0 #(.DATA_WIDTH(2), .DFT_VALUE(2'b10))
    p2_sgmii_speed_pkgsync (.src_clk(pclk), .src_rstn(p2_cfg_rst_n), .src_data(p2_status_vector[4:3]), .des_clk(p2_sgmii_clk), .des_rstn(p2_tx_rstn), .des_data(p2_sgmii_speed_sync));
ips_sgmii_handshake_sync_v1_0 #(.DATA_WIDTH(2), .DFT_VALUE(2'b10))
    p3_sgmii_speed_pkgsync (.src_clk(pclk), .src_rstn(p3_cfg_rst_n), .src_data(p3_status_vector[4:3]), .des_clk(p3_sgmii_clk), .des_rstn(p3_tx_rstn), .des_data(p3_sgmii_speed_sync));

pkg_gen p0_pkg_gen(
    .clk              (p0_sgmii_clk        ),
    .rst_n            (p0_tx_rstn          ),
    .mode             (1'b0                ),
    .rg_start_test    (p0_rg_start_test    ),
    .rg_pkg_send_clr  (p0_rg_pkg_send_clr  ),
    .rg_length_cfg_en (p0_rg_length_cfg_en ),
    .rg_length_num    (p0_rg_length_num    ),
    .rg_ipg_cfg_en    (p0_rg_ipg_cfg_en    ),
    .rg_ipg_num       (p0_rg_ipg_num       ),
    .rg_pre_cfg_en    (p0_rg_pre_cfg_en    ),
    .rg_pre_num       (p0_rg_pre_num       ),
    .rg_pld_max_sel   (p0_rg_pld_max_sel   ),
    .rg_ipg_max_sel   (p0_rg_ipg_max_sel   ),
    .rg_pre_max_sel   (p0_rg_pre_max_sel   ),
    .rg_burst_tx_en   (p0_rg_burst_tx_en   ),
    .phy_speed        (p0_sgmii_speed_sync ),
    .pkg_cnt          (p0_pkg_gen_cnt      ),
    .tx_clken         (p0_tx_clken         ),
    .txd              (p0_gmii_txd         ),
    .tx_en            (p0_gmii_tx_en       ),
    .tx_er            (p0_gmii_tx_er       ),
    .tx_cnt           (                    )
);

pkg_gen p1_pkg_gen(
    .clk              (p1_sgmii_clk        ),
    .rst_n            (p1_tx_rstn          ),
    .mode             (1'b0                ),
    .rg_start_test    (p1_rg_start_test    ),
    .rg_pkg_send_clr  (p1_rg_pkg_send_clr  ),
    .rg_length_cfg_en (p1_rg_length_cfg_en ),
    .rg_length_num    (p1_rg_length_num    ),
    .rg_ipg_cfg_en    (p1_rg_ipg_cfg_en    ),
    .rg_ipg_num       (p1_rg_ipg_num       ),
    .rg_pre_cfg_en    (p1_rg_pre_cfg_en    ),
    .rg_pre_num       (p1_rg_pre_num       ),
    .rg_pld_max_sel   (p1_rg_pld_max_sel   ),
    .rg_ipg_max_sel   (p1_rg_ipg_max_sel   ),
    .rg_pre_max_sel   (p1_rg_pre_max_sel   ),
    .rg_burst_tx_en   (p1_rg_burst_tx_en   ),
    .phy_speed        (p1_sgmii_speed_sync ),
    .pkg_cnt          (p1_pkg_gen_cnt      ),
    .tx_clken         (p1_tx_clken         ),
    .txd              (p1_gmii_txd         ),
    .tx_en            (p1_gmii_tx_en       ),
    .tx_er            (p1_gmii_tx_er       ),
    .tx_cnt           (                    )
);

pkg_gen p2_pkg_gen(
    .clk              (p2_sgmii_clk        ),
    .rst_n            (p2_tx_rstn          ),
    .mode             (1'b0                ),
    .rg_start_test    (p2_rg_start_test    ),
    .rg_pkg_send_clr  (p2_rg_pkg_send_clr  ),
    .rg_length_cfg_en (p2_rg_length_cfg_en ),
    .rg_length_num    (p2_rg_length_num    ),
    .rg_ipg_cfg_en    (p2_rg_ipg_cfg_en    ),
    .rg_ipg_num       (p2_rg_ipg_num       ),
    .rg_pre_cfg_en    (p2_rg_pre_cfg_en    ),
    .rg_pre_num       (p2_rg_pre_num       ),
    .rg_pld_max_sel   (p2_rg_pld_max_sel   ),
    .rg_ipg_max_sel   (p2_rg_ipg_max_sel   ),
    .rg_pre_max_sel   (p2_rg_pre_max_sel   ),
    .rg_burst_tx_en   (p2_rg_burst_tx_en   ),
    .phy_speed        (p2_sgmii_speed_sync ),
    .pkg_cnt          (p2_pkg_gen_cnt      ),
    .tx_clken         (p2_tx_clken         ),
    .txd              (p2_gmii_txd         ),
    .tx_en            (p2_gmii_tx_en       ),
    .tx_er            (p2_gmii_tx_er       ),
    .tx_cnt           (                    )
);

pkg_gen p3_pkg_gen(
    .clk              (p3_sgmii_clk        ),
    .rst_n            (p3_tx_rstn          ),
    .mode             (1'b0                ),
    .rg_start_test    (p3_rg_start_test    ),
    .rg_pkg_send_clr  (p3_rg_pkg_send_clr  ),
    .rg_length_cfg_en (p3_rg_length_cfg_en ),
    .rg_length_num    (p3_rg_length_num    ),
    .rg_ipg_cfg_en    (p3_rg_ipg_cfg_en    ),
    .rg_ipg_num       (p3_rg_ipg_num       ),
    .rg_pre_cfg_en    (p3_rg_pre_cfg_en    ),
    .rg_pre_num       (p3_rg_pre_num       ),
    .rg_pld_max_sel   (p3_rg_pld_max_sel   ),
    .rg_ipg_max_sel   (p3_rg_ipg_max_sel   ),
    .rg_pre_max_sel   (p3_rg_pre_max_sel   ),
    .rg_burst_tx_en   (p3_rg_burst_tx_en   ),
    .phy_speed        (p3_sgmii_speed_sync ),
    .pkg_cnt          (p3_pkg_gen_cnt      ),
    .tx_clken         (p3_tx_clken         ),
    .txd              (p3_gmii_txd         ),
    .tx_en            (p3_gmii_tx_en       ),
    .tx_er            (p3_gmii_tx_er       ),
    .tx_cnt           (                    )
);


ipsxb_bus_allocator  #(
    .AW               (20                  )
) U_bus_allocator(
    .paddr            (paddr               ),
    .pwrite           (pwrite              ),
    .psel             (psel                ),
    .penable          (penable             ),
    .pwdata           (pwdata              ),
    .prdata           (prdata              ),
    .pready           (pready              ),
//Port 0
    .paddr_0          (p0_paddr            ),
    .pwrite_0         (p0_pwrite           ),
    .psel_0           (p0_psel             ),
    .penable_0        (p0_penable          ),
    .pwdata_0         (p0_pwdata           ),
    .prdata_0         (p0_prdata           ),
    .pready_0         (p0_pready           ),
//Port 1
    .paddr_1          (p1_paddr            ),
    .pwrite_1         (p1_pwrite           ),
    .psel_1           (p1_psel             ),
    .penable_1        (p1_penable          ),
    .pwdata_1         (p1_pwdata           ),
    .prdata_1         (p1_prdata           ),
    .pready_1         (p1_pready           ),
//Port 2
    .paddr_2          (p2_paddr            ),
    .pwrite_2         (p2_pwrite           ),
    .psel_2           (p2_psel             ),
    .penable_2        (p2_penable          ),
    .pwdata_2         (p2_pwdata           ),
    .prdata_2         (p2_prdata           ),
    .pready_2         (p2_pready           ),
//Port 3
    .paddr_3          (p3_paddr            ),
    .pwrite_3         (p3_pwrite           ),
    .psel_3           (p3_psel             ),
    .penable_3        (p3_penable          ),
    .pwdata_3         (p3_pwdata           ),
    .prdata_3         (p3_prdata           ),
    .pready_3         (p3_pready           ),
//MDIO

    .mdo_0            (                    ),
    .mdo_en_0         (                    ),
    .mdo_1            (                    ),
    .mdo_en_1         (                    ),
    .mdo_2            (                    ),
    .mdo_en_2         (                    ),
    .mdo_3            (                    ),
    .mdo_en_3         (                    ),
    .mdo              (                    ),
    .mdo_en           (                    )

);

qsgmii_test    U_qsgmii_test(
//Port0
//MDIO

//APB
    .p0_cfg_rst_n               (p0_cfg_rst_n               ),
    .p0_pclk                    (pclk                       ),
    .p0_paddr                   (p0_paddr                   ),
    .p0_pwrite                  (p0_pwrite                  ),
    .p0_psel                    (p0_psel                    ),
    .p0_penable                 (p0_penable                 ),
    .p0_pwdata                  (p0_pwdata                  ),
    .p0_prdata                  (p0_prdata                  ),
    .p0_pready                  (p0_pready                  ),
//QSGMII Clock/Clock Enable for client MAC
    .p0_sgmii_clk               (p0_sgmii_clk               ),
    .p0_tx_clken                (p0_tx_clken                ),
    .p0_tx_rstn_sync            (p0_tx_rstn                 ),
    .p0_rx_rstn_sync            (p0_rx_rstn                 ),

//Status Vectors
    .p0_status_vector           (p0_status_vector           ),
//QSGMII Control Bits
    .p0_pin_cfg_en              (p0_pin_cfg_en              ),
    .p0_phy_link                (p0_phy_link                ),
    .p0_phy_duplex              (p0_phy_duplex              ),
    .p0_phy_speed               (p0_phy_speed               ),
    .p0_unidir_en               (p0_unidir_en               ),
    .p0_an_restart              (p0_an_restart              ),
    .p0_an_enable               (p0_an_enable               ),
    .p0_loopback                (p0_loopback                ),
//GMII RX
    .p0_gmii_rxd                (p0_gmii_rxd                ),
    .p0_gmii_rx_dv              (p0_gmii_rx_dv              ),
    .p0_gmii_rx_er              (p0_gmii_rx_er              ),
    .p0_receiving               (p0_receiving               ),
//GMII TX
    .p0_gmii_txd                (p0_gmii_txd                ),
    .p0_gmii_tx_en              (p0_gmii_tx_en              ),
    .p0_gmii_tx_er              (p0_gmii_tx_er              ),
    .p0_transmitting            (p0_transmitting            ),
//Port1
//MDIO

//APB
    .p1_cfg_rst_n               (p1_cfg_rst_n               ),
    .p1_pclk                    (pclk                       ),
    .p1_paddr                   (p1_paddr                   ),
    .p1_pwrite                  (p1_pwrite                  ),
    .p1_psel                    (p1_psel                    ),
    .p1_penable                 (p1_penable                 ),
    .p1_pwdata                  (p1_pwdata                  ),
    .p1_prdata                  (p1_prdata                  ),
    .p1_pready                  (p1_pready                  ),
//QSGMII Clock/Clock Enable for client MAC
    .p1_sgmii_clk               (p1_sgmii_clk               ),
    .p1_tx_clken                (p1_tx_clken                ),
    .p1_tx_rstn_sync            (p1_tx_rstn                 ),
    .p1_rx_rstn_sync            (p1_rx_rstn                 ),

//Status Vectors
    .p1_status_vector           (p1_status_vector           ),
//QSGMII Control Bits
    .p1_pin_cfg_en              (p1_pin_cfg_en              ),
    .p1_phy_link                (p1_phy_link                ),
    .p1_phy_duplex              (p1_phy_duplex              ),
    .p1_phy_speed               (p1_phy_speed               ),
    .p1_unidir_en               (p1_unidir_en               ),
    .p1_an_restart              (p1_an_restart              ),
    .p1_an_enable               (p1_an_enable               ),
    .p1_loopback                (p1_loopback                ),
//GMII RX
    .p1_gmii_rxd                (p1_gmii_rxd                ),
    .p1_gmii_rx_dv              (p1_gmii_rx_dv              ),
    .p1_gmii_rx_er              (p1_gmii_rx_er              ),
    .p1_receiving               (p1_receiving               ),
//GMII TX
    .p1_gmii_txd                (p1_gmii_txd                ),
    .p1_gmii_tx_en              (p1_gmii_tx_en              ),
    .p1_gmii_tx_er              (p1_gmii_tx_er              ),
    .p1_transmitting            (p1_transmitting            ),
//Port2
//MDIO

//APB
    .p2_cfg_rst_n               (p2_cfg_rst_n               ),
    .p2_pclk                    (pclk                       ),
    .p2_paddr                   (p2_paddr                   ),
    .p2_pwrite                  (p2_pwrite                  ),
    .p2_psel                    (p2_psel                    ),
    .p2_penable                 (p2_penable                 ),
    .p2_pwdata                  (p2_pwdata                  ),
    .p2_prdata                  (p2_prdata                  ),
    .p2_pready                  (p2_pready                  ),
//QSGMII Clock/Clock Enable for client MAC
    .p2_sgmii_clk               (p2_sgmii_clk               ),
    .p2_tx_clken                (p2_tx_clken                ),
    .p2_tx_rstn_sync            (p2_tx_rstn                 ),
    .p2_rx_rstn_sync            (p2_rx_rstn                 ),

//Status Vectors
    .p2_status_vector           (p2_status_vector           ),
//QSGMII Control Bits
    .p2_pin_cfg_en              (p2_pin_cfg_en              ),
    .p2_phy_link                (p2_phy_link                ),
    .p2_phy_duplex              (p2_phy_duplex              ),
    .p2_phy_speed               (p2_phy_speed               ),
    .p2_unidir_en               (p2_unidir_en               ),
    .p2_an_restart              (p2_an_restart              ),
    .p2_an_enable               (p2_an_enable               ),
    .p2_loopback                (p2_loopback                ),
//GMII RX
    .p2_gmii_rxd                (p2_gmii_rxd                ),
    .p2_gmii_rx_dv              (p2_gmii_rx_dv              ),
    .p2_gmii_rx_er              (p2_gmii_rx_er              ),
    .p2_receiving               (p2_receiving               ),
//GMII TX
    .p2_gmii_txd                (p2_gmii_txd                ),
    .p2_gmii_tx_en              (p2_gmii_tx_en              ),
    .p2_gmii_tx_er              (p2_gmii_tx_er              ),
    .p2_transmitting            (p2_transmitting            ),
//Port3
//MDIO

//APB
    .p3_cfg_rst_n               (p3_cfg_rst_n               ),
    .p3_pclk                    (pclk                       ),
    .p3_paddr                   (p3_paddr                   ),
    .p3_pwrite                  (p3_pwrite                  ),
    .p3_psel                    (p3_psel                    ),
    .p3_penable                 (p3_penable                 ),
    .p3_pwdata                  (p3_pwdata                  ),
    .p3_prdata                  (p3_prdata                  ),
    .p3_pready                  (p3_pready                  ),
//QSGMII Clock/Clock Enable for client MAC
    .p3_sgmii_clk               (p3_sgmii_clk               ),
    .p3_tx_clken                (p3_tx_clken                ),
    .p3_tx_rstn_sync            (p3_tx_rstn                 ),
    .p3_rx_rstn_sync            (p3_rx_rstn                 ),

//Status Vectors
    .p3_status_vector           (p3_status_vector           ),
//QSGMII Control Bits
    .p3_pin_cfg_en              (p3_pin_cfg_en              ),
    .p3_phy_link                (p3_phy_link                ),
    .p3_phy_duplex              (p3_phy_duplex              ),
    .p3_phy_speed               (p3_phy_speed               ),
    .p3_unidir_en               (p3_unidir_en               ),
    .p3_an_restart              (p3_an_restart              ),
    .p3_an_enable               (p3_an_enable               ),
    .p3_loopback                (p3_loopback                ),
//GMII RX
    .p3_gmii_rxd                (p3_gmii_rxd                ),
    .p3_gmii_rx_dv              (p3_gmii_rx_dv              ),
    .p3_gmii_rx_er              (p3_gmii_rx_er              ),
    .p3_receiving               (p3_receiving               ),
//GMII TX
    .p3_gmii_txd                (p3_gmii_txd                ),
    .p3_gmii_tx_en              (p3_gmii_tx_en              ),
    .p3_gmii_tx_er              (p3_gmii_tx_er              ),
    .p3_transmitting            (p3_transmitting            ),
// SerDes output
    .P_L0TXN                    (P_L0TXN                    ),
    .P_L0TXP                    (P_L0TXP                    ),
    .P_L0RXN                    (P_L0RXN                    ),
    .P_L0RXP                    (P_L0RXP                    ),
// HSST Reference Clock
    .P_REFCKN                   (P_REFCKN                   ),
    .P_REFCKP                   (P_REFCKP                   ),
// HSST Status indicators
    .l0_signal_loss             (signal_loss                ),
    .l0_cdr_align               (cdr_align                  ),
    .l0_tx_pll_lock             (tx_pll_lock                ),
    .l0_lsm_synced              (lsm_synced                 ),
//HSST Resets and HSST Ready
    .hsst_ch_ready              (hsst_ch_ready              ),
    .txpll_sof_rst_n            (rg_tx_pll_sof_rst_n        ),
    .hsst_cfg_soft_rstn         (rg_hsst_cfg_soft_rstn      ),
    .txlane_sof_rst_n           (rg_tx_lane_sof_rst_n[0]    ),
    .rxlane_sof_rst_n           (rg_rx_lane_sof_rst_n       ),
    .wtchdg_clr                 (rg_wtchdg_sof_clr          ),
//External reset and free run clk
    .external_rstn              (external_rstn              ),
    .p0_soft_rstn               (p0_soft_rstn               ),
    .p1_soft_rstn               (p1_soft_rstn               ),
    .p2_soft_rstn               (p2_soft_rstn               ),
    .p3_soft_rstn               (p3_soft_rstn               ),
    .free_clk                   (free_clk                   ),
    .qsgmii_tx_rstn             (qsgmii_tx_rstn             ),
    .qsgmii_rx_rstn             (qsgmii_rx_rstn             ),
//Just for debug
    .l0_pcs_nearend_loop        (pcs_nearend_loop[0]        ),
    .l0_pcs_farend_loop         (pcs_farend_loop[0]         ),
    .l0_pma_nearend_ploop       (pma_nearend_ploop[0]       ),
    .l0_pma_nearend_sloop       (pma_nearend_sloop[0]       ),
    .p0_AN_CS                   (p0_AN_CS                   ),
    .p0_AN_NS                   (p0_AN_NS                   ),
    .p0_TS_CS                   (p0_TS_CS                   ),
    .p0_TS_NS                   (p0_TS_NS                   ),
    .p0_RS_CS                   (p0_RS_CS                   ),
    .p0_RS_NS                   (p0_RS_NS                   ),
    .p0_xmit                    (p0_xmit                    ),
    .p0_rx_unitdata_indicate    (p0_rx_unitdata_indicate    ),
    .p1_AN_CS                   (p1_AN_CS                   ),
    .p1_AN_NS                   (p1_AN_NS                   ),
    .p1_TS_CS                   (p1_TS_CS                   ),
    .p1_TS_NS                   (p1_TS_NS                   ),
    .p1_RS_CS                   (p1_RS_CS                   ),
    .p1_RS_NS                   (p1_RS_NS                   ),
    .p1_xmit                    (p1_xmit                    ),
    .p1_rx_unitdata_indicate    (p1_rx_unitdata_indicate    ),
    .p2_AN_CS                   (p2_AN_CS                   ),
    .p2_AN_NS                   (p2_AN_NS                   ),
    .p2_TS_CS                   (p2_TS_CS                   ),
    .p2_TS_NS                   (p2_TS_NS                   ),
    .p2_RS_CS                   (p2_RS_CS                   ),
    .p2_RS_NS                   (p2_RS_NS                   ),
    .p2_xmit                    (p2_xmit                    ),
    .p2_rx_unitdata_indicate    (p2_rx_unitdata_indicate    ),
    .p3_AN_CS                   (p3_AN_CS                   ),
    .p3_AN_NS                   (p3_AN_NS                   ),
    .p3_TS_CS                   (p3_TS_CS                   ),
    .p3_TS_NS                   (p3_TS_NS                   ),
    .p3_RS_CS                   (p3_RS_CS                   ),
    .p3_RS_NS                   (p3_RS_NS                   ),
    .p3_xmit                    (p3_xmit                    ),
    .p3_rx_unitdata_indicate    (p3_rx_unitdata_indicate    ),
    .l0_pcs_rdispdec_er         (l0_pcs_rdispdec_er         ),
    .l0_pcs_clk                 (l0_pcs_clk                 ),
    .l0_pcs_rx_clk              (l0_pcs_rx_clk              ),
    .l0_pcs_rxk                 (l0_pcs_rxk                 ),
    .l0_pcs_rxd                 (l0_pcs_rxd                 ),
    .l0_pcs_txk                 (l0_pcs_txk                 ),
    .l0_pcs_txd                 (l0_pcs_txd                 ),
    .l0_pcs_tx_dispctrl         (l0_pcs_tx_dispctrl         ),
    .l0_pcs_tx_dispsel          (l0_pcs_tx_dispsel          )

);

pkg_chk  p0_pkg_chk(
    .rst_n            (p0_rx_rstn          ),

    .clk              (p0_sgmii_clk        ),
    .clk_en           (p0_tx_clken         ),

    .rg_pkg_chk_clr   (p0_rg_pkg_chk_clr   ),
    .speed            (p0_sgmii_speed_sync ),
    .mode             (1'b0                ),

    .mr_complete      (p0_status_vector[0] ),

    .rxd              (p0_gmii_rxd         ),
    .rx_dv            (p0_gmii_rx_dv       ),
    .rx_er            (p0_gmii_rx_er       ),
    .burst_en         (p0_rg_burst_tx_en   ),
    .buffer_err       (p0_status_vector[6] ),
    .byte_cnt         (p0_byte_cnt         ),
    .ok_led           (p0_ok_led           ),
    .crc_ok           (p0_crc_ok           ),
    .crc_ok_cnt       (p0_crc_ok_cnt       ),
    .crc_err_cnt      (p0_crc_err_cnt      ),
    .rcving_cnt       (p0_rcving_cnt       )
);

pkg_chk  p1_pkg_chk(
    .rst_n            (p1_rx_rstn          ),

    .clk              (p1_sgmii_clk        ),
    .clk_en           (p1_tx_clken         ),

    .rg_pkg_chk_clr   (p1_rg_pkg_chk_clr   ),
    .speed            (p1_sgmii_speed_sync ),
    .mode             (1'b0                ),

    .mr_complete      (p1_status_vector[0] ),

    .rxd              (p1_gmii_rxd         ),
    .rx_dv            (p1_gmii_rx_dv       ),
    .rx_er            (p1_gmii_rx_er       ),
    .burst_en         (p1_rg_burst_tx_en   ),
    .buffer_err       (p1_status_vector[6] ),
    .byte_cnt         (p1_byte_cnt         ),
    .ok_led           (p1_ok_led           ),
    .crc_ok           (p1_crc_ok           ),
    .crc_ok_cnt       (p1_crc_ok_cnt       ),
    .crc_err_cnt      (p1_crc_err_cnt      ),
    .rcving_cnt       (p1_rcving_cnt       )
);

pkg_chk  p2_pkg_chk(
    .rst_n            (p2_rx_rstn          ),

    .clk              (p2_sgmii_clk        ),
    .clk_en           (p2_tx_clken         ),

    .rg_pkg_chk_clr   (p2_rg_pkg_chk_clr   ),
    .speed            (p2_sgmii_speed_sync ),
    .mode             (1'b0                ),

    .mr_complete      (p2_status_vector[0] ),

    .rxd              (p2_gmii_rxd         ),
    .rx_dv            (p2_gmii_rx_dv       ),
    .rx_er            (p2_gmii_rx_er       ),
    .burst_en         (p2_rg_burst_tx_en   ),
    .buffer_err       (p2_status_vector[6] ),
    .byte_cnt         (p2_byte_cnt         ),
    .ok_led           (p2_ok_led           ),
    .crc_ok           (p2_crc_ok           ),
    .crc_ok_cnt       (p2_crc_ok_cnt       ),
    .crc_err_cnt      (p2_crc_err_cnt      ),
    .rcving_cnt       (p2_rcving_cnt       )
);

pkg_chk  p3_pkg_chk(
    .rst_n            (p3_rx_rstn          ),

    .clk              (p3_sgmii_clk        ),
    .clk_en           (p3_tx_clken         ),

    .rg_pkg_chk_clr   (p3_rg_pkg_chk_clr   ),
    .speed            (p3_sgmii_speed_sync ),
    .mode             (1'b0                ),

    .mr_complete      (p3_status_vector[0] ),

    .rxd              (p3_gmii_rxd         ),
    .rx_dv            (p3_gmii_rx_dv       ),
    .rx_er            (p3_gmii_rx_er       ),
    .burst_en         (p3_rg_burst_tx_en   ),
    .buffer_err       (p3_status_vector[6] ),
    .byte_cnt         (p3_byte_cnt         ),
    .ok_led           (p3_ok_led           ),
    .crc_ok           (p3_crc_ok           ),
    .crc_ok_cnt       (p3_crc_ok_cnt       ),
    .crc_err_cnt      (p3_crc_err_cnt      ),
    .rcving_cnt       (p3_rcving_cnt       )
);
endmodule
