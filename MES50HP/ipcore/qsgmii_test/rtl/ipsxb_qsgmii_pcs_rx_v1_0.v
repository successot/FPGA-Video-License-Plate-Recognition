//////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2014 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
//
// THE SOURCE CODE CONTAINED HEREIN IS PROPRIETARY TO PANGO MICROSYSTEMS, INC.
// IT SHALL NOT BE REPRODUCED OR DISCLOSED IN WHOLE OR IN PART OR USED BY
// PARTIES WITHOUT WRITTEN AUTHORIZATION FROM THE OWNER.
//
//////////////////////////////////////////////////////////////////////////////
// Functional description: QSGMII RX
// Submodule list:
`timescale 1ns/1ps
module ipsxb_qsgmii_pcs_rx_v1_0(

    input  wire          clk           ,
    input  wire          rstn          ,
    input  wire  [31:0]  pcs_rxd       ,
    input  wire  [3:0]   pcs_rxk       ,
    output wire  [7:0]   p0_pcs_rxd_out,
    output wire          p0_pcs_rxk_out,
    output wire  [7:0]   p1_pcs_rxd_out,
    output wire          p1_pcs_rxk_out,
    output wire  [7:0]   p2_pcs_rxd_out,
    output wire          p2_pcs_rxk_out,
    output wire  [7:0]   p3_pcs_rxd_out,
    output wire          p3_pcs_rxk_out

);

wire  [7:0]  p0_pcs_rxd_w  ;
wire         p0_pcs_rxk_w  ;
wire  [7:0]  p1_pcs_rxd_w  ;
wire         p1_pcs_rxk_w  ;
wire  [7:0]  p2_pcs_rxd_w  ;
wire         p2_pcs_rxk_w  ;
wire  [7:0]  p3_pcs_rxd_w  ;
wire         p3_pcs_rxk_w  ;

ipsxb_qsgmii_pcs_rx_sw_v1_0    U_qsgmii_rx_sw(

    .clk           (clk            ),
    .rst_n         (rstn           ),
    .pcs_rxd       (pcs_rxd        ),
    .pcs_rxk       (pcs_rxk        ),
    .p0_pcs_rxd_out(p0_pcs_rxd_w   ),
    .p0_pcs_rxk_out(p0_pcs_rxk_w   ),
    .p1_pcs_rxd_out(p1_pcs_rxd_w   ),
    .p1_pcs_rxk_out(p1_pcs_rxk_w   ),
    .p2_pcs_rxd_out(p2_pcs_rxd_w   ),
    .p2_pcs_rxk_out(p2_pcs_rxk_w   ),
    .p3_pcs_rxd_out(p3_pcs_rxd_w   ),
    .p3_pcs_rxk_out(p3_pcs_rxk_w   )

);

ipsxb_qsgmii_pcs_rx_adapt_v1_0  U_qsgmii_rx_adapt(

    .clk           (clk            ),
    .rst_n         (rstn           ),
    .p0_pcs_rxd_in (p0_pcs_rxd_w   ),
    .p0_pcs_rxk_in (p0_pcs_rxk_w   ),
    .p1_pcs_rxd_in (p1_pcs_rxd_w   ),
    .p1_pcs_rxk_in (p1_pcs_rxk_w   ),
    .p2_pcs_rxd_in (p2_pcs_rxd_w   ),
    .p2_pcs_rxk_in (p2_pcs_rxk_w   ),
    .p3_pcs_rxd_in (p3_pcs_rxd_w   ),
    .p3_pcs_rxk_in (p3_pcs_rxk_w   ),
    .p0_pcs_rxd_out(p0_pcs_rxd_out ),
    .p0_pcs_rxk_out(p0_pcs_rxk_out ),
    .p1_pcs_rxd_out(p1_pcs_rxd_out ),
    .p1_pcs_rxk_out(p1_pcs_rxk_out ),
    .p2_pcs_rxd_out(p2_pcs_rxd_out ),
    .p2_pcs_rxk_out(p2_pcs_rxk_out ),
    .p3_pcs_rxd_out(p3_pcs_rxd_out ),
    .p3_pcs_rxk_out(p3_pcs_rxk_out )

);

endmodule
