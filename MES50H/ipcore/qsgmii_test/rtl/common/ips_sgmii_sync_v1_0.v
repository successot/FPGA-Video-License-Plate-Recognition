
/////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2014 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
//
// THE SOURCE CODE CONTAINED HEREIN IS PROPRIETARY TO PANGO MICROSYSTEMS, INC.
// IT SHALL NOT BE REPRODUCED OR DISCLOSED IN WHOLE OR IN PART OR USED BY
// PARTIES WITHOUT WRITTEN AUTHORIZATION FROM THE OWNER.
//
////////////////////////////////////////////////////////////////////////////
//Functional description: ips_sgmii_sync_v1_0

`timescale 1ns/1ps
module ips_sgmii_sync_v1_0 #
    (
    parameter DATA_WIDTH = 1 //
    )
    (
     input   wire                   clk,
     input   wire                   rst_n,
     input   wire  [DATA_WIDTH-1:0] sig_async,
     output  wire  [DATA_WIDTH-1:0] sig_synced
    );

reg     [DATA_WIDTH-1:0]  sig_async_r1;
reg     [DATA_WIDTH-1:0]  sig_async_r2;

always@(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        sig_async_r1 <= {DATA_WIDTH{1'b0}};
        sig_async_r2 <= {DATA_WIDTH{1'b0}};
    end
    else
    begin
        sig_async_r1 <= sig_async;
        sig_async_r2 <= sig_async_r1;
    end
end

assign sig_synced = sig_async_r2;

endmodule
