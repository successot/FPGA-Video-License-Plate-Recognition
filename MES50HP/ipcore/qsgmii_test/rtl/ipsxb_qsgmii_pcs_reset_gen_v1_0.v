

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
module ipsxb_qsgmii_pcs_reset_gen_v1_0(

    input  wire         pcs_clk           ,
    input  wire         pcs_rx_clk        ,
    input  wire         i_tx_lane_done    ,
    input  wire         i_rx_lane_done    ,
    input  wire         hsst_cfg_soft_rstn,
    input  wire         p0_soft_rstn      ,
    input  wire         p1_soft_rstn      ,
    input  wire         p2_soft_rstn      ,
    input  wire         p3_soft_rstn      ,
    output wire         qsgmii_tx_rstn    ,
    output wire         qsgmii_rx_rstn    ,
    output wire         p0_cfg_rstn       ,
    output wire         p1_cfg_rstn       ,
    output wire         p2_cfg_rstn       ,
    output wire         p3_cfg_rstn       ,
    output wire         p0_tx_rstn        ,
    output wire         p1_tx_rstn        ,
    output wire         p2_tx_rstn        ,
    output wire         p3_tx_rstn        ,
    output wire         p0_rx_rstn        ,
    output wire         p1_rx_rstn        ,
    output wire         p2_rx_rstn        ,
    output wire         p3_rx_rstn

);


wire        p0_rx_rst_n;
wire        p1_rx_rst_n;
wire        p2_rx_rst_n;
wire        p3_rx_rst_n;


//QSGMII TX RX reset
ips_sgmii_sync_v1_0 qsgmii_tx_rstn_syn    (.clk(pcs_clk   ),  .rst_n(i_tx_lane_done),  .sig_async(1'b1  ),  .sig_synced(qsgmii_tx_rstn)    );

ips_sgmii_sync_v1_0 qsgmii_rx_rstn_syn    (.clk(pcs_rx_clk),  .rst_n(i_rx_lane_done),  .sig_async(1'b1  ),  .sig_synced(qsgmii_rx_rstn)    );


//cfg_rstn gen
assign p0_cfg_rstn = hsst_cfg_soft_rstn & p0_soft_rstn  ;
assign p1_cfg_rstn = hsst_cfg_soft_rstn & p1_soft_rstn  ;
assign p2_cfg_rstn = hsst_cfg_soft_rstn & p2_soft_rstn  ;
assign p3_cfg_rstn = hsst_cfg_soft_rstn & p3_soft_rstn  ;

//QSGMII Ports tx_rstn gen
assign p0_tx_rstn  = i_tx_lane_done & p0_soft_rstn  ;
assign p1_tx_rstn  = i_tx_lane_done & p1_soft_rstn  ;
assign p2_tx_rstn  = i_tx_lane_done & p2_soft_rstn  ;
assign p3_tx_rstn  = i_tx_lane_done & p3_soft_rstn  ;


//QSGMII Ports rx_rstn gen

assign p0_rx_rst_n  = i_rx_lane_done & p0_soft_rstn  ;
assign p1_rx_rst_n  = i_rx_lane_done & p1_soft_rstn  ;
assign p2_rx_rst_n  = i_rx_lane_done & p2_soft_rstn  ;
assign p3_rx_rst_n  = i_rx_lane_done & p3_soft_rstn  ;

assign p0_rx_rstn  = p0_tx_rstn & p0_rx_rst_n  ;
assign p1_rx_rstn  = p1_tx_rstn & p1_rx_rst_n  ;
assign p2_rx_rstn  = p2_tx_rstn & p2_rx_rst_n  ;
assign p3_rx_rstn  = p3_tx_rstn & p3_rx_rst_n  ;


endmodule
