`timescale 1ns / 1ps
`default_nettype wire
// Small asynchronous FIFO with single write and single read point.
module async_fifo_gray #(
    parameter DSIZE = 72,
    parameter ASIZE = 3
)(
    input                  wclk,
    input                  wrst_n,
    input                  winc,
    input      [DSIZE-1:0] wdata,
    output                 wfull,
    input                  rclk,
    input                  rrst_n,
    input                  rinc,
    output     [DSIZE-1:0] rdata,
    output                 rempty
);
    localparam DEPTH = (1 << ASIZE);

    reg [DSIZE-1:0] mem [0:DEPTH-1];

    reg [ASIZE:0] wbin, wptr;
    reg [ASIZE:0] rbin, rptr;
    reg [ASIZE:0] wq1_rptr, wq2_rptr;
    reg [ASIZE:0] rq1_wptr, rq2_wptr;

    wire [ASIZE:0] wbin_next = wbin + ((winc && !wfull) ? 1'b1 : 1'b0);
    wire [ASIZE:0] rbin_next = rbin + ((rinc && !rempty) ? 1'b1 : 1'b0);
    wire [ASIZE:0] wgray_next = (wbin_next >> 1) ^ wbin_next;
    wire [ASIZE:0] rgray_next = (rbin_next >> 1) ^ rbin_next;

    always @(posedge wclk or negedge wrst_n) begin
        if(!wrst_n) begin
            wbin <= {ASIZE+1{1'b0}};
            wptr <= {ASIZE+1{1'b0}};
        end else begin
            if(winc && !wfull)
                mem[wbin[ASIZE-1:0]] <= wdata;
            wbin <= wbin_next;
            wptr <= wgray_next;
        end
    end

    always @(posedge rclk or negedge rrst_n) begin
        if(!rrst_n) begin
            rbin <= {ASIZE+1{1'b0}};
            rptr <= {ASIZE+1{1'b0}};
        end else begin
            rbin <= rbin_next;
            rptr <= rgray_next;
        end
    end

    always @(posedge wclk or negedge wrst_n) begin
        if(!wrst_n) begin
            wq1_rptr <= {ASIZE+1{1'b0}};
            wq2_rptr <= {ASIZE+1{1'b0}};
        end else begin
            wq1_rptr <= rptr;
            wq2_rptr <= wq1_rptr;
        end
    end

    always @(posedge rclk or negedge rrst_n) begin
        if(!rrst_n) begin
            rq1_wptr <= {ASIZE+1{1'b0}};
            rq2_wptr <= {ASIZE+1{1'b0}};
        end else begin
            rq1_wptr <= wptr;
            rq2_wptr <= rq1_wptr;
        end
    end

    assign rdata  = mem[rbin[ASIZE-1:0]];
    assign rempty = (rptr == rq2_wptr);
    assign wfull  = (wgray_next == {~wq2_rptr[ASIZE:ASIZE-1], wq2_rptr[ASIZE-2:0]});
endmodule
