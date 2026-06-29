
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

module ipsxb_qsgmii_pcs_core_v1_0_qsgmii_test #(
    parameter MANAGEMENT_INTERFACE ="TRUE",
    parameter AUTO_NEGOTIATION     ="TRUE",
    parameter CLOCKING_LOGIC       ="TRUE",
    parameter CLOCKEN              ="TRUE"
)(
    input  wire            external_rstn        ,
    input  wire            p0_soft_rstn         ,
    input  wire            p1_soft_rstn         ,
    input  wire            p2_soft_rstn         ,
    input  wire            p3_soft_rstn         ,
    output wire            qsgmii_tx_rstn       ,
    output wire            qsgmii_rx_rstn       ,
    input  wire            i_tx_lane_done       ,//tx reset signal
    input  wire            i_rx_lane_done       ,//rx reset signal
    input  wire            hsst_cfg_soft_rstn   ,
    input  wire            pcs_clk              ,
    input  wire            pcs_rx_clk           ,
//Port0
    output wire            p0_mm_rst_n          ,
    output wire            p0_cfg_rst_n         ,
    output wire            p0_tx_rstn_sync      ,
    output wire            p0_rx_rstn_sync      ,

    input  wire            p0_pclk              ,
    output wire            p0_sgmii_clk         ,
    output wire            p0_tx_clken          ,//Clock Enable for Client MAC

    //MDIO Interface
    input  wire            p0_mdc               ,
    input  wire            p0_mdi               ,
    output wire            p0_mdo               ,
    output wire            p0_mdo_en            ,
    input  wire [4:0]      p0_phy_addr          ,
    //APB Interface
    input  wire [18:0]     p0_paddr             ,
    input  wire            p0_pwrite            ,
    input  wire            p0_psel              ,
    input  wire            p0_penable           ,
    input  wire [31:0]     p0_pwdata            ,
    output wire [31:0]     p0_prdata            ,
    output wire            p0_pready            ,
    //Status vectors
    output wire [15:0]     p0_status_vector     ,
    //QSGMII Control Bits
    input  wire            p0_pin_cfg_en        ,
    input  wire            p0_phy_link          ,//Link: 1=link up, 0=link down
    input  wire            p0_phy_duplex        ,//Duplex mode: 1=full duplex, 0=half duplex
    input  wire [1:0]      p0_phy_speed         ,//11 = Reserved 10=1000Mbps; 01=100Mbps; 00=10Mbps
    input  wire            p0_unidir_en         ,
    input  wire            p0_an_restart        ,
    input  wire            p0_an_enable         ,
    input  wire            p0_loopback          ,
    //GMII RX
    output wire [7:0]      p0_gmii_rxd          ,
    output wire            p0_gmii_rx_dv        ,
    output wire            p0_gmii_rx_er        ,
    output wire            p0_receiving         ,
    //GMII TX
    input  wire [7:0]      p0_gmii_txd          ,
    input  wire            p0_gmii_tx_en        ,
    input  wire            p0_gmii_tx_er        ,
    output wire            p0_transmitting      ,
//Port1
    output wire            p1_mm_rst_n          ,
    output wire            p1_cfg_rst_n         ,
    output wire            p1_tx_rstn_sync      ,
    output wire            p1_rx_rstn_sync      ,

    input  wire            p1_pclk              ,
    output wire            p1_sgmii_clk         ,
    output wire            p1_tx_clken          ,//Clock Enable for Client MAC

    //MDIO Interface
    input  wire            p1_mdc               ,
    input  wire            p1_mdi               ,
    output wire            p1_mdo               ,
    output wire            p1_mdo_en            ,
    input  wire [4:0]      p1_phy_addr          ,
    //APB Interface
    input  wire [18:0]     p1_paddr             ,
    input  wire            p1_pwrite            ,
    input  wire            p1_psel              ,
    input  wire            p1_penable           ,
    input  wire [31:0]     p1_pwdata            ,
    output wire [31:0]     p1_prdata            ,
    output wire            p1_pready            ,
    //Status vectors
    output wire [15:0]     p1_status_vector     ,
    //QSGMII Control Bits
    input  wire            p1_pin_cfg_en        ,
    input  wire            p1_phy_link          ,//Link: 1=link up, 0=link down
    input  wire            p1_phy_duplex        ,//Duplex mode: 1=full duplex, 0=half duplex
    input  wire [1:0]      p1_phy_speed         ,//11 = Reserved 10=1000Mbps; 01=100Mbps; 00=10Mbps
    input  wire            p1_unidir_en         ,
    input  wire            p1_an_restart        ,
    input  wire            p1_an_enable         ,
    input  wire            p1_loopback          ,
    //GMII RX
    output wire [7:0]      p1_gmii_rxd          ,
    output wire            p1_gmii_rx_dv        ,
    output wire            p1_gmii_rx_er        ,
    output wire            p1_receiving         ,
    //GMII TX
    input  wire [7:0]      p1_gmii_txd          ,
    input  wire            p1_gmii_tx_en        ,
    input  wire            p1_gmii_tx_er        ,
    output wire            p1_transmitting      ,
//Port2
    output wire            p2_mm_rst_n          ,
    output wire            p2_cfg_rst_n         ,
    output wire            p2_tx_rstn_sync      ,
    output wire            p2_rx_rstn_sync      ,

    input  wire            p2_pclk              ,
    output wire            p2_sgmii_clk         ,
    output wire            p2_tx_clken          ,//Clock Enable for Client MAC

    //MDIO Interface
    input  wire            p2_mdc               ,
    input  wire            p2_mdi               ,
    output wire            p2_mdo               ,
    output wire            p2_mdo_en            ,
    input  wire [4:0]      p2_phy_addr          ,
    //APB Interface
    input  wire [18:0]     p2_paddr             ,
    input  wire            p2_pwrite            ,
    input  wire            p2_psel              ,
    input  wire            p2_penable           ,
    input  wire [31:0]     p2_pwdata            ,
    output wire [31:0]     p2_prdata            ,
    output wire            p2_pready            ,
    //Status vectors
    output wire [15:0]     p2_status_vector     ,
    //QSGMII Control Bits
    input  wire            p2_pin_cfg_en        ,
    input  wire            p2_phy_link          ,//Link: 1=link up, 0=link down
    input  wire            p2_phy_duplex        ,//Duplex mode: 1=full duplex, 0=half duplex
    input  wire [1:0]      p2_phy_speed         ,//11 = Reserved 10=1000Mbps; 01=100Mbps; 00=10Mbps
    input  wire            p2_unidir_en         ,
    input  wire            p2_an_restart        ,
    input  wire            p2_an_enable         ,
    input  wire            p2_loopback          ,
    //GMII RX
    output wire [7:0]      p2_gmii_rxd          ,
    output wire            p2_gmii_rx_dv        ,
    output wire            p2_gmii_rx_er        ,
    output wire            p2_receiving         ,
    //GMII TX
    input  wire [7:0]      p2_gmii_txd          ,
    input  wire            p2_gmii_tx_en        ,
    input  wire            p2_gmii_tx_er        ,
    output wire            p2_transmitting      ,
//Port3
    output wire            p3_mm_rst_n          ,
    output wire            p3_cfg_rst_n         ,
    output wire            p3_tx_rstn_sync      ,
    output wire            p3_rx_rstn_sync      ,

    input  wire            p3_pclk              ,
    output wire            p3_sgmii_clk         ,
    output wire            p3_tx_clken          ,//Clock Enable for Client MAC

    //MDIO Interface
    input  wire            p3_mdc               ,
    input  wire            p3_mdi               ,
    output wire            p3_mdo               ,
    output wire            p3_mdo_en            ,
    input  wire [4:0]      p3_phy_addr          ,
    //APB Interface
    input  wire [18:0]     p3_paddr             ,
    input  wire            p3_pwrite            ,
    input  wire            p3_psel              ,
    input  wire            p3_penable           ,
    input  wire [31:0]     p3_pwdata            ,
    output wire [31:0]     p3_prdata            ,
    output wire            p3_pready            ,
    //Status vectors
    output wire [15:0]     p3_status_vector     ,
    //QSGMII Control Bits
    input  wire            p3_pin_cfg_en        ,
    input  wire            p3_phy_link          ,//Link: 1=link up, 0=link down
    input  wire            p3_phy_duplex        ,//Duplex mode: 1=full duplex, 0=half duplex
    input  wire [1:0]      p3_phy_speed         ,//11 = Reserved 10=1000Mbps; 01=100Mbps; 00=10Mbps
    input  wire            p3_unidir_en         ,
    input  wire            p3_an_restart        ,
    input  wire            p3_an_enable         ,
    input  wire            p3_loopback          ,
    //GMII RX
    output wire [7:0]      p3_gmii_rxd          ,
    output wire            p3_gmii_rx_dv        ,
    output wire            p3_gmii_rx_er        ,
    output wire            p3_receiving         ,
    //GMII TX
    input  wire [7:0]      p3_gmii_txd          ,
    input  wire            p3_gmii_tx_en        ,
    input  wire            p3_gmii_tx_er        ,
    output wire            p3_transmitting      ,
    //HSSTLP Signals
    input  wire [3:0]      i_rxk_0              ,
    input  wire [31:0]     i_rxd_0              ,
    input  wire [3:0]      i_rdisper_0          ,
    input  wire [3:0]      i_rdecer_0           ,
    input  wire            i_p_pcs_lsm_synced_0 ,
    output wire [3:0]      o_txk_0              ,
    output wire [31:0]     o_txd_0              ,
    output wire [3:0]      i_tdispctrl_0        ,
    output wire [3:0]      i_tdispsel_0         ,
    output wire [2:0]      i_loop_dbg_0         ,
    output wire [15:0]     o_p_cfg_addr         ,
    output wire            o_p_cfg_write        ,
    output wire            o_p_cfg_psel         ,
    output wire            o_p_cfg_enable       ,
    output wire [7:0]      o_p_cfg_wdata        ,
    input  wire [7:0]      i_p_cfg_rdata        ,
    input  wire            i_p_cfg_ready        ,
    //debug
    output wire [3:0]      p0_AN_CS             ,
    output wire [3:0]      p0_AN_NS             ,
    output wire [4:0]      p0_TS_CS             ,
    output wire [4:0]      p0_TS_NS             ,
    output wire [4:0]      p0_RS_CS             ,
    output wire [4:0]      p0_RS_NS             ,
    output wire [1:0]      p0_xmit              ,
    output wire [1:0]      p0_rx_unitdata_indicate,
    output wire [3:0]      p1_AN_CS             ,
    output wire [3:0]      p1_AN_NS             ,
    output wire [4:0]      p1_TS_CS             ,
    output wire [4:0]      p1_TS_NS             ,
    output wire [4:0]      p1_RS_CS             ,
    output wire [4:0]      p1_RS_NS             ,
    output wire [1:0]      p1_xmit              ,
    output wire [1:0]      p1_rx_unitdata_indicate,
    output wire [3:0]      p2_AN_CS             ,
    output wire [3:0]      p2_AN_NS             ,
    output wire [4:0]      p2_TS_CS             ,
    output wire [4:0]      p2_TS_NS             ,
    output wire [4:0]      p2_RS_CS             ,
    output wire [4:0]      p2_RS_NS             ,
    output wire [1:0]      p2_xmit              ,
    output wire [1:0]      p2_rx_unitdata_indicate,
    output wire [3:0]      p3_AN_CS             ,
    output wire [3:0]      p3_AN_NS             ,
    output wire [4:0]      p3_TS_CS             ,
    output wire [4:0]      p3_TS_NS             ,
    output wire [4:0]      p3_RS_CS             ,
    output wire [4:0]      p3_RS_NS             ,
    output wire [1:0]      p3_xmit              ,
    output wire [1:0]      p3_rx_unitdata_indicate,
    output wire            l0_pcs_rdispdec_er

);

//****************************************************************************//
//                      Internal Signal                                       //
//****************************************************************************//
wire         rdisper             ;
wire         rdecer              ;
wire [7:0]   p0_pcs_txd          ;
wire         p0_pcs_txk          ;
wire [7:0]   p1_pcs_txd          ;
wire         p1_pcs_txk          ;
wire [7:0]   p2_pcs_txd          ;
wire         p2_pcs_txk          ;
wire [7:0]   p3_pcs_txd          ;
wire         p3_pcs_txk          ;
wire [7:0]   p0_pcs_rxd          ;
wire         p0_pcs_rxk          ;
wire [7:0]   p1_pcs_rxd          ;
wire         p1_pcs_rxk          ;
wire [7:0]   p2_pcs_rxd          ;
wire         p2_pcs_rxk          ;
wire [7:0]   p3_pcs_rxd          ;
wire         p3_pcs_rxk          ;
wire         p0_cfg_rstn         ;
wire         p1_cfg_rstn         ;
wire         p2_cfg_rstn         ;
wire         p3_cfg_rstn         ;
wire         p0_tx_rstn          ;
wire         p1_tx_rstn          ;
wire         p2_tx_rstn          ;
wire         p3_tx_rstn          ;
wire         p0_rx_rstn          ;
wire         p1_rx_rstn          ;
wire         p2_rx_rstn          ;
wire         p3_rx_rstn          ;
wire [20:0]  link_timer_value    ;

wire [3:0]   cfg_rstn            ;
wire [3:0]   tx_rstn             ;
wire [3:0]   rx_rstn             ;
wire [3:0]   pcs_rxk             ;
wire [3:0]   pcs_txk             ;
wire [31:0]  pcs_rxd             ;
wire [31:0]  pcs_txd             ;

wire [3:0]   mdo                 ;
wire [3:0]   mdo_en              ;
wire [3:0]   mm_rst_n            ;
wire [3:0]   cfg_rst_n           ;
wire [3:0]   pclk                ;
wire [75:0]  paddr               ;
wire [3:0]   pwrite              ;
wire [3:0]   psel                ;
wire [3:0]   penable             ;
wire [127:0] pwdata              ;
wire [127:0] prdata              ;
wire [3:0]   pready              ;
wire [3:0]   p_cfg_psel          ;
wire [3:0]   p_cfg_enable        ;
wire [3:0]   p_cfg_write         ;
wire [63:0]  p_cfg_addr          ;
wire [31:0]  p_cfg_wdata         ;
wire [31:0]  p_cfg_rdata         ;
wire [3:0]   p_cfg_ready         ;
wire [63:0]  status_vector       ;
wire [3:0]   pin_cfg_en          ;
wire [3:0]   phy_link            ;
wire [3:0]   phy_duplex          ;
wire [7:0]   phy_speed           ;
wire [3:0]   unidir_en           ;
wire [3:0]   an_restart          ;
wire [3:0]   an_enable           ;
wire [3:0]   loopback            ;
wire [3:0]   sgmii_clk           ;
wire [3:0]   tx_clken            ;
wire [3:0]   tx_rstn_sync        ;
wire [3:0]   rx_rstn_sync        ;

wire [31:0]  gmii_rxd            ;
wire [3:0]   gmii_rx_dv          ;
wire [3:0]   gmii_rx_er          ;
wire [3:0]   receiving           ;
wire [31:0]  gmii_txd            ;
wire [3:0]   gmii_tx_en          ;
wire [3:0]   gmii_tx_er          ;
wire [3:0]   transmitting        ;
wire [11:0]  loop_dbg            ;

wire [15:0]  AN_CS               ;
wire [15:0]  AN_NS               ;
wire [19:0]  TS_CS               ;
wire [19:0]  TS_NS               ;
wire [19:0]  RS_CS               ;
wire [19:0]  RS_NS               ;
wire [7:0]   xmit                ;
wire [7:0]   rx_unitdata_indicate;




assign  rdisper = | i_rdisper_0;
assign  rdecer  = | i_rdecer_0;
assign  l0_pcs_rdispdec_er = rdisper || rdecer  ;

//link timer
`ifdef IPS_QSGMII_SPEEDUP_SIM
assign link_timer_value = 21'd249;
`else
assign link_timer_value = 21'd199999; //1.6 ms
`endif


ipsxb_qsgmii_pcs_reset_gen_v1_0    U_qsgmii_reset_gen(

    .pcs_clk              (pcs_clk            ),
    .pcs_rx_clk           (pcs_rx_clk         ),
    .i_tx_lane_done       (i_tx_lane_done     ),
    .i_rx_lane_done       (i_rx_lane_done     ),
    .hsst_cfg_soft_rstn   (hsst_cfg_soft_rstn ),
    .p0_soft_rstn         (p0_soft_rstn       ),
    .p1_soft_rstn         (p1_soft_rstn       ),
    .p2_soft_rstn         (p2_soft_rstn       ),
    .p3_soft_rstn         (p3_soft_rstn       ),
    .qsgmii_tx_rstn       (qsgmii_tx_rstn     ),
    .qsgmii_rx_rstn       (qsgmii_rx_rstn     ),
    .p0_cfg_rstn          (p0_cfg_rstn        ),
    .p1_cfg_rstn          (p1_cfg_rstn        ),
    .p2_cfg_rstn          (p2_cfg_rstn        ),
    .p3_cfg_rstn          (p3_cfg_rstn        ),
    .p0_tx_rstn           (p0_tx_rstn         ),
    .p1_tx_rstn           (p1_tx_rstn         ),
    .p2_tx_rstn           (p2_tx_rstn         ),
    .p3_tx_rstn           (p3_tx_rstn         ),
    .p0_rx_rstn           (p0_rx_rstn         ),
    .p1_rx_rstn           (p1_rx_rstn         ),
    .p2_rx_rstn           (p2_rx_rstn         ),
    .p3_rx_rstn           (p3_rx_rstn         )

);

ipsxb_qsgmii_pcs_tx_v1_0    U_qsgmii_tx(

    .clk                  (pcs_clk            ),
    .rstn                 (qsgmii_tx_rstn     ),
    .p0_pcs_txd           (p0_pcs_txd         ),
    .p0_pcs_txk           (p0_pcs_txk         ),
    .p1_pcs_txd           (p1_pcs_txd         ),
    .p1_pcs_txk           (p1_pcs_txk         ),
    .p2_pcs_txd           (p2_pcs_txd         ),
    .p2_pcs_txk           (p2_pcs_txk         ),
    .p3_pcs_txd           (p3_pcs_txd         ),
    .p3_pcs_txk           (p3_pcs_txk         ),
    .pcs_txd_out          (o_txd_0            ),
    .pcs_txk_out          (o_txk_0            )

);

ipsxb_qsgmii_pcs_rx_v1_0    U_qsgmii_rx(

    .clk                  (pcs_rx_clk         ),
    .rstn                 (qsgmii_rx_rstn     ),
    .pcs_rxd              (i_rxd_0            ),
    .pcs_rxk              (i_rxk_0            ),
    .p0_pcs_rxd_out       (p0_pcs_rxd         ),
    .p0_pcs_rxk_out       (p0_pcs_rxk         ),
    .p1_pcs_rxd_out       (p1_pcs_rxd         ),
    .p1_pcs_rxk_out       (p1_pcs_rxk         ),
    .p2_pcs_rxd_out       (p2_pcs_rxd         ),
    .p2_pcs_rxk_out       (p2_pcs_rxk         ),
    .p3_pcs_rxd_out       (p3_pcs_rxd         ),
    .p3_pcs_rxk_out       (p3_pcs_rxk         )

);

generate

genvar i;
    for(i = 0; i < 4; i = i +1)
    begin:port
ipsxb_sgmii_core_v1_0_qsgmii_test
#(
    .MANAGEMENT_INTERFACE       (MANAGEMENT_INTERFACE              ),
    .AUTO_NEGOTIATION           (AUTO_NEGOTIATION                  ),
    .CLOCKING_LOGIC             (CLOCKING_LOGIC                    ),
    .CLOCKEN                    (CLOCKEN                           )
) U_qsgmii_port(
    .external_rstn              (external_rstn                     ),
    .cfg_soft_rstn              (cfg_rstn[i]                       ),
//Management Rregister

    .mdc                        (1'b1                              ),
    .mdi                        (1'b0                              ),
    .mdo                        (mdo[i]                            ),
    .mdo_en                     (mdo_en[i]                         ),
    .phy_addr                   (5'b0                              ),
    .mm_rst_n                   (mm_rst_n[i]                       ),

// APB
    .cfg_rstn                   (cfg_rst_n[i]                      ),
    .pclk                       (pclk[i]                           ),
    .paddr                      (paddr[(19*i+18):19*i]             ),
    .pwrite                     (pwrite[i]                         ),
    .psel                       (psel[i]                           ),
    .penable                    (penable[i]                        ),
    .pwdata                     (pwdata[(32*i+31):32*i]            ),
    .prdata                     (prdata[(32*i+31):32*i]            ),
    .pready                     (pready[i]                         ),
    .o_p_cfg_addr               (p_cfg_addr[(16*i+15):16*i]        ),
    .o_p_cfg_write              (p_cfg_write[i]                    ),
    .o_p_cfg_psel               (p_cfg_psel[i]                     ),
    .o_p_cfg_enable             (p_cfg_enable[i]                   ),
    .o_p_cfg_wdata              (p_cfg_wdata[(8*i+7):8*i]          ),
    .i_p_cfg_rdata              (p_cfg_rdata[(8*i+7):8*i]          ),
    .i_p_cfg_ready              (p_cfg_ready[i]                    ),
//Status vectors
    .status_vector              (status_vector[(16*i+15):16*i]     ),
//SGMII Control bits
    .pin_cfg_en                 (pin_cfg_en[i]                     ),
    .phy_link                   (phy_link[i]                       ), //Link: 1=link up, 0=link down
    .phy_duplex                 (phy_duplex[i]                     ), //Duplex mode: 1=full duplex, 0=half duplex
    .phy_speed                  (phy_speed[(2*i+1):2*i]            ), //11 = Reserved 10=1000Mbps; 01=100Mbps; 00=10Mbps
    .phy_remote_fault           (2'b00                             ),
    .phy_pause                  (2'b11                             ),
    .unidir_en                  (unidir_en[i]                      ),
    .an_restart                 (an_restart[i]                     ),
    .an_enable                  (an_enable[i]                      ),
    .loopback                   (loopback[i]                       ),

//AN link_timer configure
    .link_timer_value           (link_timer_value                  ), //set link timer 1.6ms
// SGMII Clock/Clock Enable for Client MAC
    .tx_clken                   (tx_clken[i]                       ),
    .sgmii_clk                  (sgmii_clk[i]                      ),
    .tx_rstn_sync               (tx_rstn_sync[i]                   ),

    .rx_rstn_sync               (rx_rstn_sync[i]                   ),
//pcs rx
    .gmii_rxd                   (gmii_rxd[(8*i+7):8*i]             ),
    .gmii_rx_dv                 (gmii_rx_dv[i]                     ),
    .gmii_rx_er                 (gmii_rx_er[i]                     ),
    .receiving                  (receiving[i]                      ),
//pcs tx
    .gmii_txd                   (gmii_txd[(8*i+7):8*i]             ),
    .gmii_tx_en                 (gmii_tx_en[i]                     ),
    .gmii_tx_er                 (gmii_tx_er[i]                     ),
    .transmitting               (transmitting[i]                   ),
//HSSTLP Signals
    .i_txlane_done_0            (tx_rstn[i]                        ),
    .i_rxlane_done_0            (rx_rstn[i]                        ),
    .i_rxk_0                    (pcs_rxk[i]                        ),
    .i_rxd_0                    (pcs_rxd[(8*i+7):8*i]              ),
    .i_rdisper_0                (rdisper                           ),
    .i_rdecer_0                 (rdecer                            ),
    .i_p_pcs_lsm_synced_0       (i_p_pcs_lsm_synced_0              ),
    .i_p_clk2core_rx_0          (pcs_rx_clk                        ),
    .i_p_clk2core_tx_0          (pcs_clk                           ),
    .o_p_tx0_clk_fr_core        (                                  ),
    .o_p_rx0_clk_fr_core        (                                  ),
    .o_txk_0                    (pcs_txk[i]                        ),
    .o_txd_0                    (pcs_txd[(8*i+7):8*i]              ),
    .o_tdispctrl_0              (i_tdispctrl_0[i]                  ),
    .o_tdispsel_0               (i_tdispsel_0[i]                   ),
    .o_loop_dbg_0               (loop_dbg[(3*i+2):3*i]             ),
//debug
    .AN_CS                      (AN_CS[(4*i+3):4*i]                ),
    .AN_NS                      (AN_NS[(4*i+3):4*i]                ),
    .TS_CS                      (TS_CS[(5*i+4):5*i]                ),
    .TS_NS                      (TS_NS[(5*i+4):5*i]                ),
    .RS_CS                      (RS_CS[(5*i+4):5*i]                ),
    .RS_NS                      (RS_NS[(5*i+4):5*i]                ),
    .xmit                       (xmit[(2*i+1):2*i]                 ),
    .rx_unitdata_indicate       (rx_unitdata_indicate[(2*i+1):2*i] ),
    .pcs0_rdispdec_er           (                                  )

);

end
endgenerate

assign cfg_rstn = {p3_cfg_rstn,p2_cfg_rstn,p1_cfg_rstn,p0_cfg_rstn};
//MDIO

assign {p3_mdo,p2_mdo,p1_mdo,p0_mdo} = mdo;
assign {p3_mdo_en,p2_mdo_en,p1_mdo_en,p0_mdo_en} = mdo_en;
assign {p3_mm_rst_n,p2_mm_rst_n,p1_mm_rst_n,p0_mm_rst_n} = mm_rst_n;
//Status Vector
assign {p3_status_vector,p2_status_vector,p1_status_vector,p0_status_vector} = status_vector;
//QSGMII Control Bits
assign pin_cfg_en = {p3_pin_cfg_en,p2_pin_cfg_en,p1_pin_cfg_en,p0_pin_cfg_en};
assign phy_link = {p3_phy_link,p2_phy_link,p1_phy_link,p0_phy_link};
assign phy_duplex = {p3_phy_duplex,p2_phy_duplex,p1_phy_duplex,p0_phy_duplex};
assign phy_speed = {p3_phy_speed,p2_phy_speed,p1_phy_speed,p0_phy_speed};
assign unidir_en = {p3_unidir_en,p2_unidir_en,p1_unidir_en,p0_unidir_en};
assign an_restart = {p3_an_restart,p2_an_restart,p1_an_restart,p0_an_restart};
assign an_enable = {p3_an_enable,p2_an_enable,p1_an_enable,p0_an_enable};
assign loopback = {p3_loopback,p2_loopback,p1_loopback,p0_loopback};
//APB
assign {p3_cfg_rst_n,p2_cfg_rst_n,p1_cfg_rst_n,p0_cfg_rst_n} = cfg_rst_n;
assign pclk = {p3_pclk,p2_pclk,p1_pclk,p0_pclk};
assign paddr = {p3_paddr,p2_paddr,p1_paddr,p0_paddr};
assign pwrite = {p3_pwrite,p2_pwrite,p1_pwrite,p0_pwrite};
assign psel = {p3_psel,p2_psel,p1_psel,p0_psel};
assign penable = {p3_penable,p2_penable,p1_penable,p0_penable};
assign pwdata = {p3_pwdata,p2_pwdata,p1_pwdata,p0_pwdata};
assign {p3_prdata,p2_prdata,p1_prdata,p0_prdata} = prdata;
assign {p3_pready,p2_pready,p1_pready,p0_pready} = pready;
assign o_p_cfg_addr = p_cfg_addr[15:0];
assign o_p_cfg_write = p_cfg_write[0];
assign o_p_cfg_psel = p_cfg_psel[0];
assign o_p_cfg_enable = p_cfg_enable[0];
assign o_p_cfg_wdata = p_cfg_wdata[7:0];
assign p_cfg_rdata = {24'b0,i_p_cfg_rdata};
assign p_cfg_ready = {3'b0,i_p_cfg_ready};
//Clock and Clock Enable
assign {p3_tx_clken,p2_tx_clken,p1_tx_clken,p0_tx_clken} = tx_clken;
assign {p3_sgmii_clk,p2_sgmii_clk,p1_sgmii_clk,p0_sgmii_clk} = sgmii_clk;
assign {p3_tx_rstn_sync,p2_tx_rstn_sync,p1_tx_rstn_sync,p0_tx_rstn_sync} = tx_rstn_sync;

assign {p3_rx_rstn_sync,p2_rx_rstn_sync,p1_rx_rstn_sync,p0_rx_rstn_sync} = rx_rstn_sync;
//GMII RX
assign {p3_gmii_rxd,p2_gmii_rxd,p1_gmii_rxd,p0_gmii_rxd} = gmii_rxd;
assign {p3_gmii_rx_dv,p2_gmii_rx_dv,p1_gmii_rx_dv,p0_gmii_rx_dv} = gmii_rx_dv;
assign {p3_gmii_rx_er,p2_gmii_rx_er,p1_gmii_rx_er,p0_gmii_rx_er} = gmii_rx_er;
assign {p3_receiving,p2_receiving,p1_receiving,p0_receiving} = receiving;
//GMII TX
assign gmii_txd = {p3_gmii_txd,p2_gmii_txd,p1_gmii_txd,p0_gmii_txd};
assign gmii_tx_en = {p3_gmii_tx_en,p2_gmii_tx_en,p1_gmii_tx_en,p0_gmii_tx_en};
assign gmii_tx_er = {p3_gmii_tx_er,p2_gmii_tx_er,p1_gmii_tx_er,p0_gmii_tx_er};
assign {p3_transmitting,p2_transmitting,p1_transmitting,p0_transmitting} = transmitting;
//HSSTLP
assign tx_rstn = {p3_tx_rstn,p2_tx_rstn,p1_tx_rstn,p0_tx_rstn};
assign rx_rstn = {p3_rx_rstn,p2_rx_rstn,p1_rx_rstn,p0_rx_rstn};
assign pcs_rxk = {p3_pcs_rxk,p2_pcs_rxk,p1_pcs_rxk,p0_pcs_rxk};
assign pcs_rxd = {p3_pcs_rxd,p2_pcs_rxd,p1_pcs_rxd,p0_pcs_rxd};
assign {p3_pcs_txk,p2_pcs_txk,p1_pcs_txk,p0_pcs_txk} = pcs_txk;
assign {p3_pcs_txd,p2_pcs_txd,p1_pcs_txd,p0_pcs_txd} = pcs_txd;
assign i_loop_dbg_0 = loop_dbg[2:0];
//Debug
assign {p3_AN_CS,p2_AN_CS,p1_AN_CS,p0_AN_CS} = AN_CS;
assign {p3_AN_NS,p2_AN_NS,p1_AN_NS,p0_AN_NS} = AN_NS;
assign {p3_TS_CS,p2_TS_CS,p1_TS_CS,p0_TS_CS} = TS_CS;
assign {p3_TS_NS,p2_TS_NS,p1_TS_NS,p0_TS_NS} = TS_NS;
assign {p3_RS_CS,p2_RS_CS,p1_RS_CS,p0_RS_CS} = RS_CS;
assign {p3_RS_NS,p2_RS_NS,p1_RS_NS,p0_RS_NS} = RS_NS;
assign {p3_xmit,p2_xmit,p1_xmit,p0_xmit} = xmit;
assign {p3_rx_unitdata_indicate,p2_rx_unitdata_indicate,p1_rx_unitdata_indicate,p0_rx_unitdata_indicate} = rx_unitdata_indicate;

endmodule
