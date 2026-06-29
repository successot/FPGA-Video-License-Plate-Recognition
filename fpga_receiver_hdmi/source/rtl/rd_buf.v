`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Meyesemi
// Engineer: Nill
// 
// Create Date: 15/03/23 15:02:21
// Design Name: 
// Module Name: rd_buf
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`define UD #1
module rd_buf #(
    parameter                     ADDR_WIDTH      = 6'd27,
    parameter                     ADDR_OFFSET     = 32'h0000_0000,
    parameter                     H_NUM           = 12'd1920,
    parameter                     V_NUM           = 12'd1080,
    parameter                     DQ_WIDTH        = 12'd32,
    parameter                     LEN_WIDTH       = 12'd16,
    parameter                     PIX_WIDTH       = 12'd24,
    parameter                     LINE_ADDR_WIDTH = 16'd19,
    parameter                     FRAME_CNT_WIDTH = 16'd8
)  (
    input                         ddr_clk,
    input                         ddr_rstn,
    
    input                         vout_clk,
    input                         rd_fsync,
    input                         rd_en,
    // F14F: separate one-line-ahead DDR prefetch request in vout_clk domain.
    input                         rd_line_req,
    output                        vout_de,
    output [PIX_WIDTH- 1'b1 : 0]  vout_data,
    
    
    // Stage7F12: read only the last completed DDR frame bank.
    input                         frame_sel,
    input                         frame_sel_toggle,
input                         init_done,
    
    output                        ddr_rreq,
    output [ADDR_WIDTH- 1'b1 : 0] ddr_raddr,
    output [LEN_WIDTH- 1'b1 : 0]  ddr_rd_len,
    input                         ddr_rrdy,
    input                         ddr_rdone,
    
    input [8*DQ_WIDTH- 1'b1 : 0]  ddr_rdata,
    input                         ddr_rdata_en 
);
    localparam SIM            = 1'b0;
    localparam RAM_WIDTH      = 16'd32;
    localparam DDR_DATA_WIDTH = DQ_WIDTH * 8;
    localparam WR_LINE_NUM    = H_NUM * PIX_WIDTH/RAM_WIDTH;
    localparam RD_LINE_NUM    = WR_LINE_NUM * RAM_WIDTH/DDR_DATA_WIDTH;
    localparam DDR_ADDR_OFFSET= RD_LINE_NUM*DDR_DATA_WIDTH/DQ_WIDTH; 
    
    //===========================================================================
    reg       rd_fsync_1d;
    reg       rd_en_1d,rd_en_2d;
    wire      rd_rst;
    reg       ddr_rstn_1d,ddr_rstn_2d;
    always @(posedge vout_clk)
    begin
        rd_fsync_1d <= rd_fsync;
        rd_en_1d <= rd_en; 
        rd_en_2d <= rd_en_1d;
        ddr_rstn_1d <= ddr_rstn;
        ddr_rstn_2d <= ddr_rstn_1d;
    end 
    assign rd_rst = ~rd_fsync_1d &rd_fsync;
    //===========================================================================
    // F14F CDC fix:
    // The previous rd_buf sampled rd_fsync/rd_en directly in ddr_clk. The F14E
    // P&R report showed cross-clock hold violations on these paths. Use toggle
    // synchronizers and request each DDR line one HDMI line before visible output.
    reg rd_line_req_d;
    reg frame_req_toggle_vout;
    reg line_req_toggle_vout;

    always @(posedge vout_clk)
    begin
        if(!ddr_rstn_2d) begin
            rd_line_req_d         <= 1'b0;
            frame_req_toggle_vout <= 1'b0;
            line_req_toggle_vout  <= 1'b0;
        end else begin
            rd_line_req_d <= rd_line_req;
            if(rd_rst)
                frame_req_toggle_vout <= ~frame_req_toggle_vout;
            if(rd_line_req && !rd_line_req_d)
                line_req_toggle_vout <= ~line_req_toggle_vout;
        end
    end

    reg [2:0] frame_req_sync_ddr;
    reg [2:0] line_req_sync_ddr;
    wire      wr_rst;
    wire      wr_trig;
    reg [11:0] wr_line;

    always @(posedge ddr_clk)
    begin
        if(!ddr_rstn) begin
            frame_req_sync_ddr <= 3'b000;
            line_req_sync_ddr  <= 3'b000;
        end else begin
            frame_req_sync_ddr <= {frame_req_sync_ddr[1:0], frame_req_toggle_vout};
            line_req_sync_ddr  <= {line_req_sync_ddr[1:0],  line_req_toggle_vout};
        end
    end

    assign wr_rst  = frame_req_sync_ddr[2] ^ frame_req_sync_ddr[1];
    assign wr_trig = (line_req_sync_ddr[2] ^ line_req_sync_ddr[1]) && (wr_line < V_NUM);

    always @(posedge ddr_clk)
    begin
        if(wr_rst || (~ddr_rstn))
            wr_line <= 12'd0;
        else if(wr_trig)
            wr_line <= wr_line + 12'd1;
    end
    
    //==========================================================================
    reg [FRAME_CNT_WIDTH - 1'b1 :0] wr_frame_cnt=0;
    always @(posedge ddr_clk)
    begin 
        if(wr_rst)
            wr_frame_cnt <= wr_frame_cnt + 1'b1;
        else
            wr_frame_cnt <= wr_frame_cnt;
    end

    // F14E: synchronize completed-bank notification, but do NOT switch the DDR
    // read bank immediately.  Immediate switching can make one HDMI frame read
    // top lines from bank A and bottom lines from bank B, which appears as fine
    // horizontal tearing.  Latch the pending bank and commit it only at rd_fsync
    // rising edge in ddr_clk domain.
    reg [2:0] frame_sel_toggle_sync;
    reg [1:0] frame_sel_sync;
    reg       read_frame_bank;
    reg       pending_frame_bank;
    reg       pending_frame_valid;
    wire      frame_sel_update = frame_sel_toggle_sync[2] ^ frame_sel_toggle_sync[1];

    always @(posedge ddr_clk)
    begin
        if(!ddr_rstn) begin
            frame_sel_toggle_sync <= 3'b000;
            frame_sel_sync        <= 2'b00;
            read_frame_bank       <= 1'b0;
            pending_frame_bank    <= 1'b0;
            pending_frame_valid   <= 1'b0;
        end else begin
            frame_sel_toggle_sync <= {frame_sel_toggle_sync[1:0], frame_sel_toggle};
            frame_sel_sync        <= {frame_sel_sync[0], frame_sel};

            if(frame_sel_update) begin
                pending_frame_bank  <= frame_sel_sync[1];
                pending_frame_valid <= 1'b1;
            end

            if(wr_rst && pending_frame_valid) begin
                read_frame_bank     <= pending_frame_bank;
                pending_frame_valid <= 1'b0;
            end
        end
    end

    reg [LINE_ADDR_WIDTH - 1'b1 :0] wr_cnt;
    always @(posedge ddr_clk)
    begin 
        if(wr_rst)
            wr_cnt <= 9'd0;
        else if(ddr_rdone)
            wr_cnt <= wr_cnt + DDR_ADDR_OFFSET;
        else
            wr_cnt <= wr_cnt;
    end 
    
    // Stage7F13: in the 4-channel build, read requests may wait behind
    // other windows. Hold the request until ddr_rrdy is returned by the
    // shared DDR read arbiter/controller.
    reg ddr_rreq_hold;
    always @(posedge ddr_clk)
    begin
        if(!ddr_rstn || wr_rst || !init_done)
            ddr_rreq_hold <= 1'b0;
        else if(wr_trig)
            ddr_rreq_hold <= 1'b1;
        else if(ddr_rrdy)
            ddr_rreq_hold <= 1'b0;
    end

    assign ddr_rreq = init_done && ddr_rreq_hold;
    assign ddr_raddr = {read_frame_bank,wr_cnt} + ADDR_OFFSET;
    assign ddr_rd_len = RD_LINE_NUM;
    
    reg  [ 8:0]           wr_addr;
    reg  [11:0]           rd_addr;
    wire [RAM_WIDTH-1:0]  rd_data;
    
    //===========================================================================
    always @(posedge ddr_clk)
    begin
        if(wr_rst)
            wr_addr <= (SIM == 1'b1) ? 9'd180 : 9'd0;
        else if(ddr_rdata_en)
            wr_addr <= wr_addr + 9'd1;
        else
            wr_addr <= wr_addr;
    end 

    rd_fram_buf rd_fram_buf (
        .wr_data    (  ddr_rdata       ),// input [255:0]            
        .wr_addr    (  wr_addr         ),// input [8:0]              
        .wr_en      (  ddr_rdata_en    ),// input                    
        .wr_clk     (  ddr_clk         ),// input                    
        .wr_rst     (  ~ddr_rstn       ),// input                    
        .rd_addr    (  rd_addr         ),// input [11:0]             
        .rd_data    (  rd_data         ),// output [31:0]            
        .rd_clk     (  vout_clk        ),// input                    
        .rd_rst     (  ~ddr_rstn_2d    ) // input                    
    );
    
    reg [1:0] rd_cnt;
    wire      read_en;
    always @(posedge vout_clk)
    begin
        if(rd_en)
            rd_cnt <= rd_cnt + 1'b1;
        else
            rd_cnt <= 2'd0;
    end 
    
    always @(posedge vout_clk)
    begin
        if(rd_rst)
            rd_addr <= 'd0;
        else if(read_en)
            rd_addr <= rd_addr + 1'b1;
        else
            rd_addr <= rd_addr;
    end 
    
    reg [PIX_WIDTH- 1'b1 : 0] read_data;
    reg [RAM_WIDTH-1:0]       rd_data_1d;
    always @(posedge vout_clk)
    begin
        rd_data_1d <= rd_data;
    end 
    
    generate
    if(PIX_WIDTH == 6'd24)
    begin
        assign read_en = rd_en && (rd_cnt != 2'd3);
        
        always @(posedge vout_clk)
        begin
            if(rd_en_1d)
            begin
                if(rd_cnt[1:0] == 2'd1)
                    read_data <= rd_data[PIX_WIDTH-1:0];
                else if(rd_cnt[1:0] == 2'd2)
                    read_data <= {rd_data[15:0],rd_data_1d[31:PIX_WIDTH]};
                else if(rd_cnt[1:0] == 2'd3)
                    read_data <= {rd_data[7:0],rd_data_1d[31:16]};
                else
                    read_data <= rd_data_1d[31:8];
            end 
            else
                read_data <= 'd0;
        end 
    end
    else if(PIX_WIDTH == 6'd16)
    begin
        assign read_en = rd_en && (rd_cnt[0] != 1'b1);
        
        always @(posedge vout_clk)
        begin
            if(rd_en_1d)
            begin
                if(rd_cnt[0])
                    read_data <= rd_data[15:0];
                else
                    read_data <= rd_data_1d[31:16];
            end 
            else
                read_data <= 'd0;
        end 
    end
    else
    begin
        assign read_en = rd_en;
        
        always @(posedge vout_clk)
        begin
            read_data <= rd_data;
        end 
    end
endgenerate

    assign vout_de = rd_en_2d;
    assign vout_data = read_data;

endmodule
