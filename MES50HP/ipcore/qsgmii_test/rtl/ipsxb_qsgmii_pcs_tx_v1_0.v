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
// Functional description:QSGMII TX
// Submodule list:
`timescale 1ns/1ps
module ipsxb_qsgmii_pcs_tx_v1_0(

    input  wire        clk           ,
    input  wire        rstn          ,
    input  wire [7:0]  p0_pcs_txd    ,
    input  wire        p0_pcs_txk    ,
    input  wire [7:0]  p1_pcs_txd    ,
    input  wire        p1_pcs_txk    ,
    input  wire [7:0]  p2_pcs_txd    ,
    input  wire        p2_pcs_txk    ,
    input  wire [7:0]  p3_pcs_txd    ,
    input  wire        p3_pcs_txk    ,
    output wire [31:0] pcs_txd_out   ,
    output wire [3:0]  pcs_txk_out

);

wire  [7:0]    p0_pcs_txd_w  ;
wire           p0_pcs_txk_w  ;
wire  [7:0]    p1_pcs_txd_w  ;
wire           p1_pcs_txk_w  ;
wire  [7:0]    p2_pcs_txd_w  ;
wire           p2_pcs_txk_w  ;
wire  [7:0]    p3_pcs_txd_w  ;
wire           p3_pcs_txk_w  ;

ipsxb_qsgmii_pcs_tx_adapt_v1_0  U_qsgmii_tx_adapt(

    .clk             (clk             ),
    .rst_n           (rstn            ),
    .p0_pcs_txd_in   (p0_pcs_txd      ),
    .p0_pcs_txk_in   (p0_pcs_txk      ),
    .p1_pcs_txd_in   (p1_pcs_txd      ),
    .p1_pcs_txk_in   (p1_pcs_txk      ),
    .p2_pcs_txd_in   (p2_pcs_txd      ),
    .p2_pcs_txk_in   (p2_pcs_txk      ),
    .p3_pcs_txd_in   (p3_pcs_txd      ),
    .p3_pcs_txk_in   (p3_pcs_txk      ),
    .p0_pcs_txd_out  (p0_pcs_txd_w    ),
    .p0_pcs_txk_out  (p0_pcs_txk_w    ),
    .p1_pcs_txd_out  (p1_pcs_txd_w    ),
    .p1_pcs_txk_out  (p1_pcs_txk_w    ),
    .p2_pcs_txd_out  (p2_pcs_txd_w    ),
    .p2_pcs_txk_out  (p2_pcs_txk_w    ),
    .p3_pcs_txd_out  (p3_pcs_txd_w    ),
    .p3_pcs_txk_out  (p3_pcs_txk_w    )

);

ipsxb_qsgmii_pcs_tx_sw_v1_0  U_qsgmii_tx_sw(

    .clk             (clk             ),
    .rst_n           (rstn            ),
    .p0_pcs_txd      (p0_pcs_txd_w    ),
    .p0_pcs_txk      (p0_pcs_txk_w    ),
    .p1_pcs_txd      (p1_pcs_txd_w    ),
    .p1_pcs_txk      (p1_pcs_txk_w    ),
    .p2_pcs_txd      (p2_pcs_txd_w    ),
    .p2_pcs_txk      (p2_pcs_txk_w    ),
    .p3_pcs_txd      (p3_pcs_txd_w    ),
    .p3_pcs_txk      (p3_pcs_txk_w    ),
    .pcs_txd_out     (pcs_txd_out     ),
    .pcs_txk_out     (pcs_txk_out     )

);

endmodule
