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
//----------------------------------------------------------------------------
// File Name:    apb_union.v
// Module Name:  apb_union
//----------------------------------------------------------------------------
// Description:
// Combine the HSST APB and CORE APB,
//
//----------------------------------------------------------------------------
// Edited Record:
//
//
//
//
//----------------------------------------------------------------------------

`timescale  1ns/1ps
module ips2l_sgmii_apb_union_v1_0 #(
    parameter MANAGEMENT_INTERFACE ="TRUE"
)(

    input               pclk        ,
    input  wire         rst_n       ,
    input        [18:0] paddr       ,
    input               pwrite      ,
    input               psel        ,
    input               penable     ,
    input        [31:0] pwdata      ,
    output  wire [31:0] prdata      ,
    output  wire        pready      ,

    output  wire [4:0]  core_paddr  ,
    output  wire        core_pwrite ,
    output  wire        core_psel   ,
    output  wire        core_penable,
    output  wire [15:0] core_pwdata ,
    input        [15:0] core_prdata ,

    output  wire [15:0] hsst_addr   ,
    output  wire        hsst_write  ,
    output  wire        hsst_psel   ,
    output  wire        hsst_enable ,
    output  wire [7:0]  hsst_wdata  ,
    input        [7:0]  hsst_rdata  ,
    input               hsst_ready
);

  reg            core_ready          ;
  reg  [3:0]     core_enable_cnt     ;

assign core_paddr   = (MANAGEMENT_INTERFACE =="TRUE") ? 5'b0
                                                     : (paddr[18] == 1'b1) ? paddr[6:2]
                                                     : 5'b0 ;
assign core_pwrite  = (MANAGEMENT_INTERFACE =="TRUE") ? 1'b0
                                                     : (paddr[18] == 1'b1) ? pwrite
                                                     : 1'b0 ;
assign core_psel    = (MANAGEMENT_INTERFACE =="TRUE") ? 1'b0
                                                     : (paddr[18] == 1'b1) ? psel
                                                     : 1'b0;
assign core_penable = (MANAGEMENT_INTERFACE =="TRUE") ? 1'b0
                                                     : (paddr[18] == 1'b1) ? penable
                                                     : 1'b0;
assign core_pwdata  = (MANAGEMENT_INTERFACE =="TRUE") ? 1'b0
                                                     : (paddr[18] == 1'b1) ? pwdata[15:0]
                                                     : 16'b0;
assign prdata[31:16] = 16'b0;

assign prdata[15:8] = (MANAGEMENT_INTERFACE =="TRUE") ? 8'b0
                                                     : (paddr[18] == 1'b1) ? core_prdata[15:8]
                                                     : 8'b0;
assign prdata[7:0]  = (MANAGEMENT_INTERFACE =="TRUE") ? hsst_rdata
                                                     : (paddr[18] == 1'b1) ? core_prdata[7:0]
                                                     : hsst_rdata;
assign pready       = (MANAGEMENT_INTERFACE =="TRUE") ? hsst_ready
                                                     : (paddr[18] == 1'b1) ? core_ready
                                                     : hsst_ready;
assign hsst_psel   = (MANAGEMENT_INTERFACE =="TRUE") ? psel
                                                    : (paddr[18] == 1'b1) ? 1'b0
                                                    : psel;
assign hsst_addr   = (MANAGEMENT_INTERFACE =="TRUE") ? paddr[17:2]
                                                    : (paddr[18] == 1'b1) ? 16'b0
                                                    : paddr[17:2];
assign hsst_write  = (MANAGEMENT_INTERFACE =="TRUE") ? pwrite
                                                    : (paddr[18] == 1'b1) ? 1'b0
                                                    : pwrite;
assign hsst_enable = (MANAGEMENT_INTERFACE =="TRUE") ? penable
                                                    : (paddr[18] == 1'b1) ? 1'b0
                                                    : penable;
assign hsst_wdata  = (MANAGEMENT_INTERFACE =="TRUE") ? pwdata[7:0]
                                                    : (paddr[18] == 1'b1) ? 8'b0
                                                    : pwdata[7:0];



always @ (posedge pclk or negedge rst_n)
begin
  if(!rst_n)
    core_enable_cnt <= 4'b0;
  else if(MANAGEMENT_INTERFACE =="TRUE")
    core_enable_cnt <= 4'b0;
  else if(paddr[18] == 1'b1 && penable && psel)
    core_enable_cnt <= core_enable_cnt + 4'b1;
  else
    core_enable_cnt <= 4'b0;
end

always @ (posedge pclk or negedge rst_n)
begin
  if(!rst_n)
    core_ready <= 1'b0;
  else if(penable==1'b1)
  begin
    if(pwrite == 1'b1)
      core_ready <= 1'b1;
    else if(core_enable_cnt == 2'd2)
      core_ready <= 1'b1;
    else
      core_ready <= 1'b0;
  end
  else
    core_ready <= 1'b0;
end

endmodule