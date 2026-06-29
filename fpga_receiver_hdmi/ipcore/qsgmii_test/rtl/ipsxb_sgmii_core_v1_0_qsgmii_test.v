

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
module  ipsxb_sgmii_core_v1_0_qsgmii_test #(
    parameter MANAGEMENT_INTERFACE ="TRUE",
    parameter AUTO_NEGOTIATION     ="TRUE",
    parameter CLOCKING_LOGIC       ="TRUE",
    parameter CLOCKEN              ="TRUE"
)(
    input  wire         external_rstn           ,
    input  wire         cfg_soft_rstn           ,
//Management Rregister
    input  wire         mdc                     ,
    input  wire         mdi                     ,
    output wire         mdo                     ,
    output wire         mdo_en                  ,
    input  wire [4:0]   phy_addr                ,
    output wire         mm_rst_n                ,
// APB
    output wire         cfg_rstn                ,
    input  wire         pclk                    ,
    input  wire [18:0]  paddr                   ,
    input  wire         pwrite                  ,
    input  wire         psel                    ,
    input  wire         penable                 ,
    input  wire [31:0]  pwdata                  ,
    output wire [31:0]  prdata                  ,
    output wire         pready                  ,
    output wire [15:0]  o_p_cfg_addr            ,
    output wire         o_p_cfg_write           ,
    output wire         o_p_cfg_psel            ,
    output wire         o_p_cfg_enable          ,
    output wire [7:0]   o_p_cfg_wdata           ,
    input  wire [7:0]   i_p_cfg_rdata           ,
    input  wire         i_p_cfg_ready           ,
//Status vectors
    output wire [15:0]  status_vector           ,
//SGMII Control bits
    input  wire         pin_cfg_en              ,
    input  wire         phy_link                , //Link: 1=link up, 0=link down
    input  wire         phy_duplex              , //Duplex mode: 1=full duplex, 0=half duplex
    input  wire [1:0]   phy_speed               , //11 = Reserved 10=1000Mbps; 01=100Mbps; 00=10Mbps defined by SGMII SPEC
    input  wire [1:0]   phy_remote_fault        ,
    input  wire [1:0]   phy_pause               ,
    input  wire         unidir_en               ,
    input  wire         an_restart              ,
    input  wire         an_enable               ,
    input  wire         loopback                ,

//AN link_timer configure
    input  wire [20:0]  link_timer_value        , //set link timer 10ms or 1.6ms
// SGMII Clock/Clock Enable for Client MAC
    output wire         tx_clken                ,
    output wire         sgmii_clk               ,
    output wire         tx_rstn_sync            ,

    output wire         rx_rstn_sync            ,
//pcs rx
    output wire [7:0]   gmii_rxd                ,
    output wire         gmii_rx_dv              ,
    output wire         gmii_rx_er              ,
    output wire         receiving               ,
//pcs tx
    input  wire [7:0]   gmii_txd                ,
    input  wire         gmii_tx_en              ,
    input  wire         gmii_tx_er              ,
    output wire         transmitting            ,
//HSSTLP Signals
    input  wire         i_txlane_done_0         ,
    input  wire         i_rxlane_done_0         ,
    input  wire         i_rxk_0                 ,
    input  wire [7:0]   i_rxd_0                 ,
    input  wire         i_rdisper_0             ,
    input  wire         i_rdecer_0              ,
    input  wire         i_p_pcs_lsm_synced_0    ,
    input  wire         i_p_clk2core_rx_0       ,
    input  wire         i_p_clk2core_tx_0       ,
    output wire         o_p_tx0_clk_fr_core     ,
    output wire         o_p_rx0_clk_fr_core     ,
    output wire         o_txk_0                 ,
    output wire [7:0]   o_txd_0                 ,
    output wire         o_tdispctrl_0           ,
    output wire         o_tdispsel_0            ,
    output wire [2:0]   o_loop_dbg_0            ,
//debug
    output wire [3:0]   AN_CS                   ,
    output wire [3:0]   AN_NS                   ,
    output wire [4:0]   TS_CS                   ,
    output wire [4:0]   TS_NS                   ,
    output wire [4:0]   RS_CS                   ,
    output wire [4:0]   RS_NS                   ,
    output wire [1:0]   xmit                    ,
    output wire [1:0]   rx_unitdata_indicate    ,
    output wire         pcs0_rdispdec_er
);

//****************************************************************************//
//                      Parameter and Define                                  //
//****************************************************************************//
// SGMII Parameter

localparam L0_GE_ONLY              = "FALSE"; //@IPC bool

localparam PCS_CH0_BYPASS_CTC      = "TRUE"; //@IPC bool

//****************************************************************************//
//                      Internal Signal                                       //
//****************************************************************************//
wire         pcs0_clk                ;
wire         pcs0_rx_clk             ;
wire         pcs0_tx_clk             ;

wire         mr_loopback             ;
wire         mr_loopback_sync        ;
wire         loopback_rstn_sync      ;

wire         tx_rstn                 ;
wire         rx_rstn                 ;
wire         mm_rstn                 ;

wire [4:0]   core0_paddr             ;
wire         core0_pwrite            ;
wire         core0_psel              ;
wire         core0_penable           ;
wire [15:0]  core0_pwdata            ;
wire [15:0]  core0_prdata            ;

wire         sgmii_phy_en            ;
wire         sgmii_mac_en            ;
wire         sgmii_mode              ;
wire         sgmii_phy_mode          ;

wire         ge_or_sgmii             ;

wire [3:0]   mr_rstfsm_lsm_force     ;
wire [3:0]   mr_rstfsm_cdr_force     ;
wire [3:0]   mr_rstfsm_los_force     ;
wire         mr_rstfsm_lsm_force_sync;
wire         mr_rstfsm_cdr_force_sync;
wire         mr_rstfsm_los_force_sync;


//SGMII Mode                    //@IPC show SGMII_EN
assign ge_or_sgmii = 1'b1;   //@IPC show SGMII_EN

//SGMII MAC Side
assign sgmii_phy_mode =  1'b0 ;

assign pcs0_rdispdec_er   = i_rdisper_0 | i_rdecer_0;

assign sgmii_phy_en = ge_or_sgmii & sgmii_phy_mode;
assign sgmii_mac_en = ge_or_sgmii & (~sgmii_phy_mode);
assign sgmii_mode   = ge_or_sgmii;

assign o_p_rx0_clk_fr_core = ((L0_GE_ONLY == "TRUE") && (PCS_CH0_BYPASS_CTC == "FALSE")) ? pcs0_clk : pcs0_rx_clk;


assign pcs0_clk = i_p_clk2core_tx_0;
assign pcs0_rx_clk = i_p_clk2core_rx_0;
assign tx_rstn = i_txlane_done_0;
assign o_p_tx0_clk_fr_core = pcs0_clk;
assign o_loop_dbg_0 = {mr_rstfsm_lsm_force_sync,mr_rstfsm_cdr_force_sync,~mr_rstfsm_los_force_sync};

ips2l_sgmii_apb_union_v1_0 #(
    .MANAGEMENT_INTERFACE    (MANAGEMENT_INTERFACE)
)u_apb_union(
    .pclk                    (pclk                   ),
    .rst_n                   (cfg_rstn               ),
    .paddr                   (paddr                  ),
    .pwrite                  (pwrite                 ),
    .psel                    (psel                   ),
    .penable                 (penable                ),
    .pwdata                  (pwdata                 ),
    .prdata                  (prdata                 ),
    .pready                  (pready                 ),

    .core_paddr              (core0_paddr            ),
    .core_pwrite             (core0_pwrite           ),
    .core_psel               (core0_psel             ),
    .core_penable            (core0_penable          ),
    .core_pwdata             (core0_pwdata           ),
    .core_prdata             (core0_prdata           ),

    .hsst_addr               (o_p_cfg_addr           ),
    .hsst_write              (o_p_cfg_write          ),
    .hsst_psel               (o_p_cfg_psel           ),
    .hsst_enable             (o_p_cfg_enable         ),
    .hsst_wdata              (o_p_cfg_wdata          ),
    .hsst_rdata              (i_p_cfg_rdata          ),
    .hsst_ready              (i_p_cfg_ready          )
);


ipsxb_sgmii_ge_pcs_core_v1_0_qsgmii_test
#(
    .MANAGEMENT_INTERFACE    (MANAGEMENT_INTERFACE),
    .AUTO_NEGOTIATION        (AUTO_NEGOTIATION    ),
    .CLOCKING_LOGIC          (CLOCKING_LOGIC      ),
    .CLOCKEN                 (CLOCKEN             )
) u_sgmii_lane0(
    .clk_tx                  (pcs0_clk               ),

    .clk_rx                  (pcs0_clk               ),

    .rx_rst_n                (rx_rstn_sync        ),
    .tx_rst_n                (tx_rstn_sync        ),
    .mm_rst_n                (mm_rst_n            ),
    //Management Rregister
    .mdc                     (mdc                 ),
    .mdi                     (mdi                 ),
    .mdo                     (mdo                 ),
    .mdo_en                  (mdo_en              ),
    .phy_addr                (phy_addr            ),

    .status_vector           (status_vector       ),

    .pclk                    (pclk                   ),
    .paddr                   (core0_paddr            ),
    .pwrite                  (core0_pwrite           ),
    .psel                    (core0_psel             ),
    .penable                 (core0_penable          ),
    .pwdata                  (core0_pwdata           ),
    .prdata                  (core0_prdata           ),

    .sgmii_phy_en            (sgmii_phy_en           ),
    .phy_link                (phy_link               ),
    .phy_duplex              (phy_duplex             ),
    .phy_speed               (phy_speed              ),
    .phy_remote_fault        (phy_remote_fault       ),
    .phy_pause               (phy_pause              ),
    .unidir_en               (unidir_en              ),
    .an_restart              (an_restart             ),
    .an_enable               (an_enable              ),
    .loopback                (loopback               ),
    .sgmii_mac_en            (sgmii_mac_en           ), //enable MAC SIDE
    .sgmii_mode              (sgmii_mode             ),
    .pin_cfg_en              (pin_cfg_en             ),
    .link_timer_value        (link_timer_value       ),

    .sgmii_clk               (sgmii_clk              ),
    .tx_clken                (tx_clken               ),

    .mr_loopback             (mr_loopback            ),
    //pcs rx
    .gmii_rxd                (gmii_rxd               ),
    .gmii_rx_dv              (gmii_rx_dv             ),
    .gmii_rx_er              (gmii_rx_er             ),
    .receiving               (receiving              ),
    .pcs_rxk                 (i_rxk_0                ),
    .pcs_rdisp_er            (i_rdisper_0            ),
    .pcs_rdec_er             (i_rdecer_0             ),
    .pcs_rxd                 (i_rxd_0                ),
    .pcs_rx_clk              (pcs0_rx_clk            ),
    .pcs_lsm_synced          (i_p_pcs_lsm_synced_0   ),
    //pcs tx
    .gmii_txd                (gmii_txd               ),
    .gmii_tx_en              (gmii_tx_en             ),
    .gmii_tx_er              (gmii_tx_er             ),
    .transmitting            (transmitting           ),
    .pcs_tx_clk              (pcs0_tx_clk            ),
    .pcs_txk                 (o_txk_0                ),
    .pcs_tx_dispctrl         (o_tdispctrl_0          ),
    .pcs_tx_dispsel          (o_tdispsel_0           ),
    .pcs_txd                 (o_txd_0                ),
    //HSST loopback
    .mr_rstfsm_lsm_force     (mr_rstfsm_lsm_force    ),
    .mr_rstfsm_cdr_force     (mr_rstfsm_cdr_force    ),
    .mr_rstfsm_los_force     (mr_rstfsm_los_force    ),

    // just for debug
    .AN_CS                   (AN_CS                  ),
    .AN_NS                   (AN_NS                  ),
    .RS_CS                   (RS_CS                  ),
    .RS_NS                   (RS_NS                  ),
    .TS_CS                   (TS_CS                  ),
    .TS_NS                   (TS_NS                  ),
    .xmit                    (xmit                   ),
    .rx_unitdata_indicate    (rx_unitdata_indicate   )  //rx_unitdata_indicate  ge_pcs_rx_sm  01:RUDI(INVALID) 10:RUDI(/C/) 11:RUDI(/I/)

);

ips_sgmii_sync_v1_0  tx_rstn_syn       (.clk(pcs0_clk), .rst_n(tx_rstn     ), .sig_async(1'b1      ), .sig_synced(tx_rstn_sync      ));

assign mm_rstn = external_rstn & cfg_soft_rstn;

ips_sgmii_sync_v1_0  mm_rstn_sync      (.clk(pclk    ), .rst_n(mm_rstn  ), .sig_async(1'b1      ), .sig_synced(mm_rst_n          ));     //@IPC show MDIO

ips_sgmii_sync_v1_0  loopback_rstn_syn (.clk(pcs0_clk), .rst_n(external_rstn  ), .sig_async(1'b1      ), .sig_synced(loopback_rstn_sync));
ips_sgmii_sync_v1_0  loopback_sync  (.clk(pcs0_clk), .rst_n(loopback_rstn_sync), .sig_async(mr_loopback), .sig_synced(mr_loopback_sync) );

assign rx_rstn = mr_loopback_sync ? tx_rstn : i_rxlane_done_0;

ips_sgmii_sync_v1_0  rx_rstn_syn (.clk(pcs0_clk), .rst_n(rx_rstn), .sig_async(1'b1), .sig_synced(rx_rstn_sync) );

ips_sgmii_sync_v1_0  lsm_force_sync (.clk(pclk), .rst_n(cfg_rstn), .sig_async(mr_rstfsm_lsm_force[0]), .sig_synced(mr_rstfsm_lsm_force_sync) );
ips_sgmii_sync_v1_0  cdr_force_sync (.clk(pclk), .rst_n(cfg_rstn), .sig_async(mr_rstfsm_cdr_force[0]), .sig_synced(mr_rstfsm_cdr_force_sync) );
ips_sgmii_sync_v1_0  los_force_sync (.clk(pclk), .rst_n(cfg_rstn), .sig_async(mr_rstfsm_los_force[0]), .sig_synced(mr_rstfsm_los_force_sync) );

ips_sgmii_sync_v1_0  hsst_cfg_rstn_sync (.clk(pclk), .rst_n(mm_rstn), .sig_async(1'b1), .sig_synced(cfg_rstn) );

endmodule
