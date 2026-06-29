`timescale 1ns / 1ps
`default_nettype wire
`define UD #1
// -----------------------------------------------------------------------------
// Stage7F14C four-channel direct DDR frame buffer.
//
// Four GMII/FPGV receivers write packet payloads directly to each channel's DDR
// bank by byte_offset.  Read side reuses the proven rd_buf + shared AXI read
// controller from Stage7F13.  Write side uses fpgv_gmii_direct_ddr_writer_f14c;
// each writer uses wr_fram_buf SDPRAM for payload storage, not inferred pkt_mem.
// -----------------------------------------------------------------------------
module fram_buf_4ch_direct_f14c #(
    parameter                     MEM_ROW_WIDTH        = 15,
    parameter                     MEM_COLUMN_WIDTH     = 10,
    parameter                     MEM_BANK_WIDTH       = 3,
    parameter                     CTRL_ADDR_WIDTH      = MEM_ROW_WIDTH + MEM_BANK_WIDTH + MEM_COLUMN_WIDTH,
    parameter                     MEM_DQ_WIDTH         = 32,
    parameter                     H_NUM                = 12'd800,
    parameter                     V_NUM                = 12'd480,
    parameter                     PIX_WIDTH            = 16,
    parameter                     LINE_ADDR_WIDTH      = 19,
    parameter                     LEN_WIDTH            = 32,
    parameter                     FRAME_CNT_WIDTH      = CTRL_ADDR_WIDTH - LINE_ADDR_WIDTH
)(
    input                         ddr_clk,
    input                         ddr_rstn,

    input                         ch0_gmii_clk,
    input                         ch0_gmii_rstn,
    input  [7:0]                  ch0_gmii_rxd,
    input                         ch0_gmii_dv,
    input                         ch0_gmii_er,
    input                         ch1_gmii_clk,
    input                         ch1_gmii_rstn,
    input  [7:0]                  ch1_gmii_rxd,
    input                         ch1_gmii_dv,
    input                         ch1_gmii_er,
    input                         ch2_gmii_clk,
    input                         ch2_gmii_rstn,
    input  [7:0]                  ch2_gmii_rxd,
    input                         ch2_gmii_dv,
    input                         ch2_gmii_er,
    input                         ch3_gmii_clk,
    input                         ch3_gmii_rstn,
    input  [7:0]                  ch3_gmii_rxd,
    input                         ch3_gmii_dv,
    input                         ch3_gmii_er,

    output reg [3:0]              init_done,
    output      [3:0]             frame_done_seen,
    output      [31:0]            ch0_frame_done_count,
    output      [31:0]            ch1_frame_done_count,
    output      [31:0]            ch2_frame_done_count,
    output      [31:0]            ch3_frame_done_count,
    output      [31:0]            ch0_overflow_count,
    output      [31:0]            ch1_overflow_count,
    output      [31:0]            ch2_overflow_count,
    output      [31:0]            ch3_overflow_count,

    input                         vout_clk,
    input                         rd_fsync,
    input                         rd_en_ch0,
    input                         rd_en_ch1,
    input                         rd_en_ch2,
    input                         rd_en_ch3,
    output                        vout_de_ch0,
    output                        vout_de_ch1,
    output                        vout_de_ch2,
    output                        vout_de_ch3,
    output [PIX_WIDTH-1:0]        vout_data_ch0,
    output [PIX_WIDTH-1:0]        vout_data_ch1,
    output [PIX_WIDTH-1:0]        vout_data_ch2,
    output [PIX_WIDTH-1:0]        vout_data_ch3,

    output [CTRL_ADDR_WIDTH-1:0]  axi_awaddr,
    output [3:0]                  axi_awid,
    output [3:0]                  axi_awlen,
    output [2:0]                  axi_awsize,
    output [1:0]                  axi_awburst,
    input                         axi_awready,
    output                        axi_awvalid,

    output [MEM_DQ_WIDTH*8-1:0]   axi_wdata,
    output [MEM_DQ_WIDTH-1:0]     axi_wstrb,
    input                         axi_wlast,
    output                        axi_wvalid,
    input                         axi_wready,
    input  [3:0]                  axi_bid,

    output [CTRL_ADDR_WIDTH-1:0]  axi_araddr,
    output [3:0]                  axi_arid,
    output [3:0]                  axi_arlen,
    output [2:0]                  axi_arsize,
    output [1:0]                  axi_arburst,
    output                        axi_arvalid,
    input                         axi_arready,

    output                        axi_rready,
    input  [MEM_DQ_WIDTH*8-1:0]   axi_rdata,
    input                         axi_rvalid,
    input                         axi_rlast,
    input  [3:0]                  axi_rid
);

    localparam [CTRL_ADDR_WIDTH-1:0] BANK_STRIDE = ({{(CTRL_ADDR_WIDTH-1){1'b0}},1'b1} << LINE_ADDR_WIDTH);
    localparam [CTRL_ADDR_WIDTH-1:0] CH_STRIDE   = (BANK_STRIDE << 1);
    localparam [CTRL_ADDR_WIDTH-1:0] CH0_OFFSET  = CH_STRIDE * 0;
    localparam [CTRL_ADDR_WIDTH-1:0] CH1_OFFSET  = CH_STRIDE * 1;
    localparam [CTRL_ADDR_WIDTH-1:0] CH2_OFFSET  = CH_STRIDE * 2;
    localparam [CTRL_ADDR_WIDTH-1:0] CH3_OFFSET  = CH_STRIDE * 3;

    wire [3:0] wr_req;
    wire [CTRL_ADDR_WIDTH-1:0] wr_addr0, wr_addr1, wr_addr2, wr_addr3;
    wire [LEN_WIDTH-1:0]       wr_len0,  wr_len1,  wr_len2,  wr_len3;
    wire [MEM_DQ_WIDTH*8-1:0]  wr_data0, wr_data1, wr_data2, wr_data3;
    wire [3:0] wr_ready_to_ch;
    wire [3:0] wr_done_to_ch;
    wire [3:0] wr_data_req_to_ch;

    wire [3:0] done_bank;
    wire [3:0] done_toggle;
    reg  [3:0] done_toggle_d;
    wire [3:0] done_pulse = done_toggle ^ done_toggle_d;
    assign frame_done_seen = init_done;

    always @(posedge ddr_clk) begin
        if(!ddr_rstn) begin
            done_toggle_d <= 4'b0000;
            init_done     <= 4'b0000;
        end else begin
            done_toggle_d <= done_toggle;
            init_done     <= init_done | done_pulse;
        end
    end

    fpgv_gmii_direct_ddr_writer_f14c #(.ADDR_WIDTH(CTRL_ADDR_WIDTH), .ADDR_OFFSET(CH0_OFFSET), .DQ_WIDTH(MEM_DQ_WIDTH), .LEN_WIDTH(LEN_WIDTH), .LINE_ADDR_WIDTH(LINE_ADDR_WIDTH)) u_dir_wr0 (
        .gmii_clk(ch0_gmii_clk), .gmii_rstn(ch0_gmii_rstn), .gmii_rxd(ch0_gmii_rxd), .gmii_rx_dv(ch0_gmii_dv), .gmii_rx_er(ch0_gmii_er),
        .ddr_clk(ddr_clk), .ddr_rstn(ddr_rstn), .ddr_wreq(wr_req[0]), .ddr_waddr(wr_addr0), .ddr_wr_len(wr_len0), .ddr_wrdy(wr_ready_to_ch[0]), .ddr_wdone(wr_done_to_ch[0]), .ddr_wdata(wr_data0), .ddr_wdata_req(wr_data_req_to_ch[0]),
        .frame_done_bank(done_bank[0]), .frame_done_toggle(done_toggle[0]), .frame_done_count(ch0_frame_done_count), .udp_packet_count(), .fpgv_packet_count(), .accepted_packet_count(), .overflow_count(ch0_overflow_count), .last_frame_id(), .last_packet_id(), .last_packet_total(), .last_payload_len(), .last_byte_offset(), .debug_state());
    fpgv_gmii_direct_ddr_writer_f14c #(.ADDR_WIDTH(CTRL_ADDR_WIDTH), .ADDR_OFFSET(CH1_OFFSET), .DQ_WIDTH(MEM_DQ_WIDTH), .LEN_WIDTH(LEN_WIDTH), .LINE_ADDR_WIDTH(LINE_ADDR_WIDTH)) u_dir_wr1 (
        .gmii_clk(ch1_gmii_clk), .gmii_rstn(ch1_gmii_rstn), .gmii_rxd(ch1_gmii_rxd), .gmii_rx_dv(ch1_gmii_dv), .gmii_rx_er(ch1_gmii_er),
        .ddr_clk(ddr_clk), .ddr_rstn(ddr_rstn), .ddr_wreq(wr_req[1]), .ddr_waddr(wr_addr1), .ddr_wr_len(wr_len1), .ddr_wrdy(wr_ready_to_ch[1]), .ddr_wdone(wr_done_to_ch[1]), .ddr_wdata(wr_data1), .ddr_wdata_req(wr_data_req_to_ch[1]),
        .frame_done_bank(done_bank[1]), .frame_done_toggle(done_toggle[1]), .frame_done_count(ch1_frame_done_count), .udp_packet_count(), .fpgv_packet_count(), .accepted_packet_count(), .overflow_count(ch1_overflow_count), .last_frame_id(), .last_packet_id(), .last_packet_total(), .last_payload_len(), .last_byte_offset(), .debug_state());
    fpgv_gmii_direct_ddr_writer_f14c #(.ADDR_WIDTH(CTRL_ADDR_WIDTH), .ADDR_OFFSET(CH2_OFFSET), .DQ_WIDTH(MEM_DQ_WIDTH), .LEN_WIDTH(LEN_WIDTH), .LINE_ADDR_WIDTH(LINE_ADDR_WIDTH)) u_dir_wr2 (
        .gmii_clk(ch2_gmii_clk), .gmii_rstn(ch2_gmii_rstn), .gmii_rxd(ch2_gmii_rxd), .gmii_rx_dv(ch2_gmii_dv), .gmii_rx_er(ch2_gmii_er),
        .ddr_clk(ddr_clk), .ddr_rstn(ddr_rstn), .ddr_wreq(wr_req[2]), .ddr_waddr(wr_addr2), .ddr_wr_len(wr_len2), .ddr_wrdy(wr_ready_to_ch[2]), .ddr_wdone(wr_done_to_ch[2]), .ddr_wdata(wr_data2), .ddr_wdata_req(wr_data_req_to_ch[2]),
        .frame_done_bank(done_bank[2]), .frame_done_toggle(done_toggle[2]), .frame_done_count(ch2_frame_done_count), .udp_packet_count(), .fpgv_packet_count(), .accepted_packet_count(), .overflow_count(ch2_overflow_count), .last_frame_id(), .last_packet_id(), .last_packet_total(), .last_payload_len(), .last_byte_offset(), .debug_state());
    fpgv_gmii_direct_ddr_writer_f14c #(.ADDR_WIDTH(CTRL_ADDR_WIDTH), .ADDR_OFFSET(CH3_OFFSET), .DQ_WIDTH(MEM_DQ_WIDTH), .LEN_WIDTH(LEN_WIDTH), .LINE_ADDR_WIDTH(LINE_ADDR_WIDTH)) u_dir_wr3 (
        .gmii_clk(ch3_gmii_clk), .gmii_rstn(ch3_gmii_rstn), .gmii_rxd(ch3_gmii_rxd), .gmii_rx_dv(ch3_gmii_dv), .gmii_rx_er(ch3_gmii_er),
        .ddr_clk(ddr_clk), .ddr_rstn(ddr_rstn), .ddr_wreq(wr_req[3]), .ddr_waddr(wr_addr3), .ddr_wr_len(wr_len3), .ddr_wrdy(wr_ready_to_ch[3]), .ddr_wdone(wr_done_to_ch[3]), .ddr_wdata(wr_data3), .ddr_wdata_req(wr_data_req_to_ch[3]),
        .frame_done_bank(done_bank[3]), .frame_done_toggle(done_toggle[3]), .frame_done_count(ch3_frame_done_count), .udp_packet_count(), .fpgv_packet_count(), .accepted_packet_count(), .overflow_count(ch3_overflow_count), .last_frame_id(), .last_packet_id(), .last_packet_total(), .last_payload_len(), .last_byte_offset(), .debug_state());

    wire shared_wr_cmd_ready;
    wire shared_wr_cmd_done;
    wire shared_wr_data_req;
    reg [1:0] wr_grant;
    reg       wr_busy;

    always @(posedge ddr_clk) begin
        if(!ddr_rstn) begin
            wr_grant <= 2'd0;
            wr_busy  <= 1'b0;
        end else if(!wr_busy) begin
            if(wr_req[0]) begin wr_grant <= 2'd0; wr_busy <= 1'b1; end
            else if(wr_req[1]) begin wr_grant <= 2'd1; wr_busy <= 1'b1; end
            else if(wr_req[2]) begin wr_grant <= 2'd2; wr_busy <= 1'b1; end
            else if(wr_req[3]) begin wr_grant <= 2'd3; wr_busy <= 1'b1; end
        end else if(shared_wr_cmd_done) begin
            wr_busy <= 1'b0;
        end
    end

    wire [CTRL_ADDR_WIDTH-1:0] shared_wr_cmd_addr = (wr_grant == 2'd0) ? wr_addr0 : (wr_grant == 2'd1) ? wr_addr1 : (wr_grant == 2'd2) ? wr_addr2 : wr_addr3;
    wire [LEN_WIDTH-1:0]       shared_wr_cmd_len  = (wr_grant == 2'd0) ? wr_len0  : (wr_grant == 2'd1) ? wr_len1  : (wr_grant == 2'd2) ? wr_len2  : wr_len3;
    wire [MEM_DQ_WIDTH*8-1:0]  shared_wr_data     = (wr_grant == 2'd0) ? wr_data0 : (wr_grant == 2'd1) ? wr_data1 : (wr_grant == 2'd2) ? wr_data2 : wr_data3;
    wire                       shared_wr_cmd_en   = wr_busy && ((wr_grant == 2'd0) ? wr_req[0] : (wr_grant == 2'd1) ? wr_req[1] : (wr_grant == 2'd2) ? wr_req[2] : wr_req[3]);

    assign wr_ready_to_ch    = (wr_busy && shared_wr_cmd_ready) ? (4'b0001 << wr_grant) : 4'b0000;
    assign wr_done_to_ch     = (wr_busy && shared_wr_cmd_done)  ? (4'b0001 << wr_grant) : 4'b0000;
    assign wr_data_req_to_ch = (wr_busy && shared_wr_data_req)  ? (4'b0001 << wr_grant) : 4'b0000;

    wire [3:0] rd_req;
    wire [CTRL_ADDR_WIDTH-1:0] rd_addr0, rd_addr1, rd_addr2, rd_addr3;
    wire [LEN_WIDTH-1:0]       rd_len0,  rd_len1,  rd_len2,  rd_len3;
    wire [3:0] rd_ready_to_ch;
    wire [3:0] rd_done_to_ch;
    wire [3:0] rd_data_en_to_ch;
    wire [MEM_DQ_WIDTH*8-1:0] shared_read_rdata;

    rd_buf #(.ADDR_WIDTH(CTRL_ADDR_WIDTH), .ADDR_OFFSET(CH0_OFFSET), .H_NUM(H_NUM), .V_NUM(V_NUM), .DQ_WIDTH(MEM_DQ_WIDTH), .LEN_WIDTH(LEN_WIDTH), .PIX_WIDTH(PIX_WIDTH), .LINE_ADDR_WIDTH(LINE_ADDR_WIDTH), .FRAME_CNT_WIDTH(FRAME_CNT_WIDTH)) u_rd0 (
        .ddr_clk(ddr_clk), .ddr_rstn(ddr_rstn), .vout_clk(vout_clk), .rd_fsync(rd_fsync), .rd_en(rd_en_ch0), .vout_de(vout_de_ch0), .vout_data(vout_data_ch0), .frame_sel(done_bank[0]), .frame_sel_toggle(done_toggle[0]), .init_done(init_done[0]),
        .ddr_rreq(rd_req[0]), .ddr_raddr(rd_addr0), .ddr_rd_len(rd_len0), .ddr_rrdy(rd_ready_to_ch[0]), .ddr_rdone(rd_done_to_ch[0]), .ddr_rdata(shared_read_rdata), .ddr_rdata_en(rd_data_en_to_ch[0]));
    rd_buf #(.ADDR_WIDTH(CTRL_ADDR_WIDTH), .ADDR_OFFSET(CH1_OFFSET), .H_NUM(H_NUM), .V_NUM(V_NUM), .DQ_WIDTH(MEM_DQ_WIDTH), .LEN_WIDTH(LEN_WIDTH), .PIX_WIDTH(PIX_WIDTH), .LINE_ADDR_WIDTH(LINE_ADDR_WIDTH), .FRAME_CNT_WIDTH(FRAME_CNT_WIDTH)) u_rd1 (
        .ddr_clk(ddr_clk), .ddr_rstn(ddr_rstn), .vout_clk(vout_clk), .rd_fsync(rd_fsync), .rd_en(rd_en_ch1), .vout_de(vout_de_ch1), .vout_data(vout_data_ch1), .frame_sel(done_bank[1]), .frame_sel_toggle(done_toggle[1]), .init_done(init_done[1]),
        .ddr_rreq(rd_req[1]), .ddr_raddr(rd_addr1), .ddr_rd_len(rd_len1), .ddr_rrdy(rd_ready_to_ch[1]), .ddr_rdone(rd_done_to_ch[1]), .ddr_rdata(shared_read_rdata), .ddr_rdata_en(rd_data_en_to_ch[1]));
    rd_buf #(.ADDR_WIDTH(CTRL_ADDR_WIDTH), .ADDR_OFFSET(CH2_OFFSET), .H_NUM(H_NUM), .V_NUM(V_NUM), .DQ_WIDTH(MEM_DQ_WIDTH), .LEN_WIDTH(LEN_WIDTH), .PIX_WIDTH(PIX_WIDTH), .LINE_ADDR_WIDTH(LINE_ADDR_WIDTH), .FRAME_CNT_WIDTH(FRAME_CNT_WIDTH)) u_rd2 (
        .ddr_clk(ddr_clk), .ddr_rstn(ddr_rstn), .vout_clk(vout_clk), .rd_fsync(rd_fsync), .rd_en(rd_en_ch2), .vout_de(vout_de_ch2), .vout_data(vout_data_ch2), .frame_sel(done_bank[2]), .frame_sel_toggle(done_toggle[2]), .init_done(init_done[2]),
        .ddr_rreq(rd_req[2]), .ddr_raddr(rd_addr2), .ddr_rd_len(rd_len2), .ddr_rrdy(rd_ready_to_ch[2]), .ddr_rdone(rd_done_to_ch[2]), .ddr_rdata(shared_read_rdata), .ddr_rdata_en(rd_data_en_to_ch[2]));
    rd_buf #(.ADDR_WIDTH(CTRL_ADDR_WIDTH), .ADDR_OFFSET(CH3_OFFSET), .H_NUM(H_NUM), .V_NUM(V_NUM), .DQ_WIDTH(MEM_DQ_WIDTH), .LEN_WIDTH(LEN_WIDTH), .PIX_WIDTH(PIX_WIDTH), .LINE_ADDR_WIDTH(LINE_ADDR_WIDTH), .FRAME_CNT_WIDTH(FRAME_CNT_WIDTH)) u_rd3 (
        .ddr_clk(ddr_clk), .ddr_rstn(ddr_rstn), .vout_clk(vout_clk), .rd_fsync(rd_fsync), .rd_en(rd_en_ch3), .vout_de(vout_de_ch3), .vout_data(vout_data_ch3), .frame_sel(done_bank[3]), .frame_sel_toggle(done_toggle[3]), .init_done(init_done[3]),
        .ddr_rreq(rd_req[3]), .ddr_raddr(rd_addr3), .ddr_rd_len(rd_len3), .ddr_rrdy(rd_ready_to_ch[3]), .ddr_rdone(rd_done_to_ch[3]), .ddr_rdata(shared_read_rdata), .ddr_rdata_en(rd_data_en_to_ch[3]));

    wire shared_rd_cmd_ready;
    wire shared_rd_cmd_done;
    wire shared_read_en;
    wire read_ready = 1'b1;
    reg [1:0] rd_grant;
    reg       rd_busy;
    always @(posedge ddr_clk) begin
        if(!ddr_rstn) begin
            rd_grant <= 2'd0;
            rd_busy  <= 1'b0;
        end else if(!rd_busy) begin
            if(rd_req[0]) begin rd_grant <= 2'd0; rd_busy <= 1'b1; end
            else if(rd_req[1]) begin rd_grant <= 2'd1; rd_busy <= 1'b1; end
            else if(rd_req[2]) begin rd_grant <= 2'd2; rd_busy <= 1'b1; end
            else if(rd_req[3]) begin rd_grant <= 2'd3; rd_busy <= 1'b1; end
        end else if(shared_rd_cmd_done) begin
            rd_busy <= 1'b0;
        end
    end

    wire [CTRL_ADDR_WIDTH-1:0] shared_rd_cmd_addr = (rd_grant == 2'd0) ? rd_addr0 : (rd_grant == 2'd1) ? rd_addr1 : (rd_grant == 2'd2) ? rd_addr2 : rd_addr3;
    wire [LEN_WIDTH-1:0]       shared_rd_cmd_len  = (rd_grant == 2'd0) ? rd_len0  : (rd_grant == 2'd1) ? rd_len1  : (rd_grant == 2'd2) ? rd_len2  : rd_len3;
    wire                       shared_rd_cmd_en   = rd_busy && ((rd_grant == 2'd0) ? rd_req[0] : (rd_grant == 2'd1) ? rd_req[1] : (rd_grant == 2'd2) ? rd_req[2] : rd_req[3]);

    assign rd_ready_to_ch   = (rd_busy && shared_rd_cmd_ready) ? (4'b0001 << rd_grant) : 4'b0000;
    assign rd_done_to_ch    = (rd_busy && shared_rd_cmd_done)  ? (4'b0001 << rd_grant) : 4'b0000;
    assign rd_data_en_to_ch = (rd_busy && shared_read_en)      ? (4'b0001 << rd_grant) : 4'b0000;

    wr_rd_ctrl_top #(
        .CTRL_ADDR_WIDTH(CTRL_ADDR_WIDTH),
        .MEM_DQ_WIDTH(MEM_DQ_WIDTH)
    ) u_wr_rd_ctrl_top (
        .clk(ddr_clk),
        .rstn(ddr_rstn),
        .wr_cmd_en(shared_wr_cmd_en),
        .wr_cmd_addr(shared_wr_cmd_addr),
        .wr_cmd_len(shared_wr_cmd_len),
        .wr_cmd_ready(shared_wr_cmd_ready),
        .wr_cmd_done(shared_wr_cmd_done),
        .wr_bac(),
        .wr_ctrl_data(shared_wr_data),
        .wr_data_re(shared_wr_data_req),
        .rd_cmd_en(shared_rd_cmd_en),
        .rd_cmd_addr(shared_rd_cmd_addr),
        .rd_cmd_len(shared_rd_cmd_len),
        .rd_cmd_ready(shared_rd_cmd_ready),
        .rd_cmd_done(shared_rd_cmd_done),
        .read_ready(read_ready),
        .read_rdata(shared_read_rdata),
        .read_en(shared_read_en),
        .axi_awaddr(axi_awaddr),
        .axi_awid(axi_awid),
        .axi_awlen(axi_awlen),
        .axi_awsize(axi_awsize),
        .axi_awburst(axi_awburst),
        .axi_awready(axi_awready),
        .axi_awvalid(axi_awvalid),
        .axi_wdata(axi_wdata),
        .axi_wstrb(axi_wstrb),
        .axi_wlast(axi_wlast),
        .axi_wvalid(axi_wvalid),
        .axi_wready(axi_wready),
        .axi_bid(4'd0),
        .axi_bresp(2'd0),
        .axi_bvalid(1'b0),
        .axi_bready(),
        .axi_araddr(axi_araddr),
        .axi_arid(axi_arid),
        .axi_arlen(axi_arlen),
        .axi_arsize(axi_arsize),
        .axi_arburst(axi_arburst),
        .axi_arvalid(axi_arvalid),
        .axi_arready(axi_arready),
        .axi_rready(axi_rready),
        .axi_rdata(axi_rdata),
        .axi_rvalid(axi_rvalid),
        .axi_rlast(axi_rlast),
        .axi_rid(axi_rid),
        .axi_rresp(2'd0)
    );

endmodule
