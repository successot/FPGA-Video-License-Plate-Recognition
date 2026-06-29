`timescale 1ns / 1ps
`default_nettype wire
`define UD #1
// -----------------------------------------------------------------------------
// Stage7F14D four-channel direct DDR frame buffer.
//
// Four GMII/FPGV receivers write packet payloads directly to each channel's DDR
// bank by byte_offset.  Read side reuses the proven rd_buf + shared AXI read
// controller from Stage7F13.  Write side uses fpgv_gmii_direct_ddr_writer_f14d;
// each writer uses wr_fram_buf SDPRAM for payload storage, not inferred pkt_mem.
// -----------------------------------------------------------------------------
module fram_buf_4ch_direct_f14d #(
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
    parameter                     FRAME_CNT_WIDTH      = CTRL_ADDR_WIDTH - LINE_ADDR_WIDTH,
    // F14T: previous-bank publish threshold. 700/750 accepts frames with limited
    // packet loss while avoiding very incomplete banks.
    parameter                     MIN_PACKETS_FOR_PREV_BANK_PUBLISH = 16'd16,
    // F14V stable default: OFF. F14S1 used this as a diagnostic and it causes tearing.
    parameter                     FORCE_CH2_DONE_AFTER_ANY_WRITE = 1'b0
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
    input                         rd_line_req_ch0,
    input                         rd_line_req_ch1,
    input                         rd_line_req_ch2,
    input                         rd_line_req_ch3,
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
    input  [3:0]                  axi_rid,

    // F14W: deterministic CH2 debug outputs.  Top-level wires use the same
    // dbg_ch2_* names and are PAP_MARK_DEBUG marked, so Select Net can find
    // them by searching dbg_ch2.
    output                        dbg_ch2_wr_req_out,
    output                        dbg_ch2_wr_done_out,
    output                        dbg_ch2_wdata_req_out,
    output                        dbg_ch2_wr_grant_is_ch2_out,
    output                        dbg_shared_wr_cmd_en_out,
    output                        dbg_shared_wr_cmd_done_out,
    output                        dbg_ch2_rd_req_out,
    output                        dbg_ch2_rd_done_out,
    output                        dbg_ch2_rd_ready_out,
    output                        dbg_ch2_rd_data_en_out,
    output                        dbg_ch2_rd_grant_is_ch2_out,
    output                        dbg_shared_rd_cmd_en_out,
    output                        dbg_shared_rd_cmd_done_out,
    output                        dbg_shared_rd_cmd_ready_out,
    output                        dbg_ch2_done_bank_out,
    output                        dbg_ch2_done_toggle_out,
    output                        dbg_ch2_init_done_out,
    output                        dbg_ch2_hdr_accept_out,
    output                        dbg_ch2_hdr_last_by_id_out,
    output                        dbg_ch2_hdr_last_by_offset_out,
    output                        dbg_ch2_rx_prevbank_candidate_out,
    output                        dbg_ch2_rx_relaxed_complete_out,
    output                        dbg_ch2_rx_publish_candidate_out,
    output                        dbg_ch2_pkt_publish_out,
    output                        dbg_ch2_meta_wr_en_out,
    output                        dbg_ch2_meta_pending_valid_out,
    output                        dbg_ch2_meta_full_out,
    output                        dbg_ch2_meta_empty_out,
    output                        dbg_ch2_meta_rd_en_out,
    output                        dbg_ch2_cmd_active_out,
    output                        dbg_ch2_cmd_started_out,
    output                        dbg_ch2_prev_publish_pending_out,
    output                        dbg_ch2_prev_publish_bank_out,
    output [31:0]                 dbg_ch2_prev_publish_latched_count_out,
    output [31:0]                 dbg_ch2_prevbank_publish_count_out,
    output [31:0]                 dbg_ch2_prevbank_skip_count_out,
    output [15:0]                 dbg_ch2_prevbank_packet_count_at_event_out,
    output [31:0]                 dbg_ch2_meta_wr_count_out,
    output [31:0]                 dbg_ch2_meta_rd_count_out,
    output [31:0]                 dbg_ch2_ddr_wreq_count_out,
    output [31:0]                 dbg_ch2_ddr_wdone_count_out,
    output [31:0]                 dbg_ch2_force_done_count_out,
    output [15:0]                 dbg_ch2_last_good_packet_id_out,
    output [15:0]                 dbg_ch2_last_good_packet_total_out,
    output [15:0]                 dbg_ch2_last_good_payload_len_out,
    output [31:0]                 dbg_ch2_last_good_byte_offset_out,
    output [31:0]                 dbg_ch2_relaxed_publish_count_out,
    output [31:0]                 dbg_ch2_strict_publish_count_out,
    output [31:0]                 dbg_ch2_drop_bad_header_count_out,
    output [31:0]                 dbg_ch2_drop_no_free_slot_count_out,
    output [31:0]                 dbg_ch2_drop_meta_pending_count_out,
    output [31:0]                 dbg_ch2_drop_meta_full_count_out,
    output [31:0]                 dbg_ch2_drop_gmii_error_count_out,
    output [31:0]                 dbg_ch2_drop_payload_error_count_out,
    output [31:0]                 dbg_ch2_duplicate_packet_count_out,
    output [15:0]                 dbg_ch2_slot_busy_count_out,
    output [15:0]                 dbg_ch2_slot_busy_max_out,
    output                        dbg_ch2_have_free_slot_out
);

    localparam [CTRL_ADDR_WIDTH-1:0] BANK_STRIDE = ({{(CTRL_ADDR_WIDTH-1){1'b0}},1'b1} << LINE_ADDR_WIDTH);
    localparam [CTRL_ADDR_WIDTH-1:0] CH_STRIDE   = (BANK_STRIDE << 1);
    localparam [CTRL_ADDR_WIDTH-1:0] CH0_OFFSET  = CH_STRIDE * 0;
    localparam [CTRL_ADDR_WIDTH-1:0] CH1_OFFSET  = CH_STRIDE * 1;
    localparam [CTRL_ADDR_WIDTH-1:0] CH2_OFFSET  = CH_STRIDE * 2;
    localparam [CTRL_ADDR_WIDTH-1:0] CH3_OFFSET  = CH_STRIDE * 3;

    wire [3:0] wr_req /* synthesis PAP_MARK_DEBUG="true" */;
    wire [CTRL_ADDR_WIDTH-1:0] wr_addr0, wr_addr1, wr_addr2, wr_addr3;
    wire [LEN_WIDTH-1:0]       wr_len0,  wr_len1,  wr_len2,  wr_len3;
    wire [MEM_DQ_WIDTH*8-1:0]  wr_data0, wr_data1, wr_data2, wr_data3;
    wire [3:0] wr_ready_to_ch;
    wire [3:0] wr_done_to_ch /* synthesis PAP_MARK_DEBUG="true" */;
    wire [3:0] wr_data_req_to_ch /* synthesis PAP_MARK_DEBUG="true" */;

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


    // F14W: CH2 writer debug port wires.
    wire w2_dbg_hdr_accept;
    wire w2_dbg_hdr_last_by_id;
    wire w2_dbg_hdr_last_by_offset;
    wire w2_dbg_rx_prevbank_publish_candidate;
    wire w2_dbg_rx_relaxed_complete;
    wire w2_dbg_rx_publish_candidate;
    wire w2_dbg_pkt_publish;
    wire w2_dbg_meta_wr_en;
    wire w2_dbg_meta_pending_valid;
    wire w2_dbg_meta_full;
    wire w2_dbg_meta_empty;
    wire w2_dbg_meta_rd_en;
    wire w2_dbg_cmd_active;
    wire w2_dbg_cmd_started;
    wire w2_dbg_prev_publish_pending;
    wire w2_dbg_prev_publish_bank;
    wire [31:0] w2_dbg_prev_publish_latched_count;
    wire [31:0] w2_dbg_prevbank_publish_count;
    wire [31:0] w2_dbg_prevbank_skip_count;
    wire [15:0] w2_dbg_prevbank_packet_count_at_event;
    wire [31:0] w2_dbg_meta_wr_count;
    wire [31:0] w2_dbg_meta_rd_count;
    wire [31:0] w2_dbg_ddr_wreq_count;
    wire [31:0] w2_dbg_ddr_wdone_count;
    wire [31:0] w2_dbg_force_done_count;
    wire [15:0] w2_dbg_last_good_packet_id;
    wire [15:0] w2_dbg_last_good_packet_total;
    wire [15:0] w2_dbg_last_good_payload_len;
    wire [31:0] w2_dbg_last_good_byte_offset;
    wire [31:0] w2_dbg_relaxed_publish_count;
    wire [31:0] w2_dbg_strict_publish_count;
    wire [31:0] w2_dbg_drop_bad_header_count;
    wire [31:0] w2_dbg_drop_no_free_slot_count;
    wire [31:0] w2_dbg_drop_meta_pending_count;
    wire [31:0] w2_dbg_drop_meta_full_count;
    wire [31:0] w2_dbg_drop_gmii_error_count;
    wire [31:0] w2_dbg_drop_payload_error_count;
    wire [31:0] w2_dbg_duplicate_packet_count;
    wire [15:0] w2_dbg_slot_busy_count;
    wire [15:0] w2_dbg_slot_busy_max;
    wire        w2_dbg_have_free_slot;

    fpgv_gmii_direct_ddr_writer_f14d #(.ADDR_WIDTH(CTRL_ADDR_WIDTH), .ADDR_OFFSET(CH0_OFFSET), .DQ_WIDTH(MEM_DQ_WIDTH), .LEN_WIDTH(LEN_WIDTH), .LINE_ADDR_WIDTH(LINE_ADDR_WIDTH), .PUBLISH_PREV_BANK_ON_PACKET0(1'b1), .MIN_PACKETS_FOR_PREV_BANK_PUBLISH(MIN_PACKETS_FOR_PREV_BANK_PUBLISH), .FORCE_FRAME_DONE_AFTER_ANY_WRITE(1'b0)) u_dir_wr0 (
        .gmii_clk(ch0_gmii_clk), .gmii_rstn(ch0_gmii_rstn), .gmii_rxd(ch0_gmii_rxd), .gmii_rx_dv(ch0_gmii_dv), .gmii_rx_er(ch0_gmii_er),
        .ddr_clk(ddr_clk), .ddr_rstn(ddr_rstn), .ddr_wreq(wr_req[0]), .ddr_waddr(wr_addr0), .ddr_wr_len(wr_len0), .ddr_wrdy(wr_ready_to_ch[0]), .ddr_wdone(wr_done_to_ch[0]), .ddr_wdata(wr_data0), .ddr_wdata_req(wr_data_req_to_ch[0]),
        .frame_done_bank(done_bank[0]), .frame_done_toggle(done_toggle[0]), .frame_done_count(ch0_frame_done_count), .udp_packet_count(), .fpgv_packet_count(), .accepted_packet_count(), .overflow_count(ch0_overflow_count), .last_frame_id(), .last_packet_id(), .last_packet_total(), .last_payload_len(), .last_byte_offset(), .debug_state());
    fpgv_gmii_direct_ddr_writer_f14d #(.ADDR_WIDTH(CTRL_ADDR_WIDTH), .ADDR_OFFSET(CH1_OFFSET), .DQ_WIDTH(MEM_DQ_WIDTH), .LEN_WIDTH(LEN_WIDTH), .LINE_ADDR_WIDTH(LINE_ADDR_WIDTH), .PUBLISH_PREV_BANK_ON_PACKET0(1'b1), .MIN_PACKETS_FOR_PREV_BANK_PUBLISH(MIN_PACKETS_FOR_PREV_BANK_PUBLISH), .FORCE_FRAME_DONE_AFTER_ANY_WRITE(1'b0)) u_dir_wr1 (
        .gmii_clk(ch1_gmii_clk), .gmii_rstn(ch1_gmii_rstn), .gmii_rxd(ch1_gmii_rxd), .gmii_rx_dv(ch1_gmii_dv), .gmii_rx_er(ch1_gmii_er),
        .ddr_clk(ddr_clk), .ddr_rstn(ddr_rstn), .ddr_wreq(wr_req[1]), .ddr_waddr(wr_addr1), .ddr_wr_len(wr_len1), .ddr_wrdy(wr_ready_to_ch[1]), .ddr_wdone(wr_done_to_ch[1]), .ddr_wdata(wr_data1), .ddr_wdata_req(wr_data_req_to_ch[1]),
        .frame_done_bank(done_bank[1]), .frame_done_toggle(done_toggle[1]), .frame_done_count(ch1_frame_done_count), .udp_packet_count(), .fpgv_packet_count(), .accepted_packet_count(), .overflow_count(ch1_overflow_count), .last_frame_id(), .last_packet_id(), .last_packet_total(), .last_payload_len(), .last_byte_offset(), .debug_state());
    fpgv_gmii_direct_ddr_writer_f14d #(.ADDR_WIDTH(CTRL_ADDR_WIDTH), .ADDR_OFFSET(CH2_OFFSET), .DQ_WIDTH(MEM_DQ_WIDTH), .LEN_WIDTH(LEN_WIDTH), .LINE_ADDR_WIDTH(LINE_ADDR_WIDTH), .PUBLISH_PREV_BANK_ON_PACKET0(1'b1), .MIN_PACKETS_FOR_PREV_BANK_PUBLISH(MIN_PACKETS_FOR_PREV_BANK_PUBLISH), .FORCE_FRAME_DONE_AFTER_ANY_WRITE(FORCE_CH2_DONE_AFTER_ANY_WRITE)) u_dir_wr2 (
        .gmii_clk(ch2_gmii_clk), .gmii_rstn(ch2_gmii_rstn), .gmii_rxd(ch2_gmii_rxd), .gmii_rx_dv(ch2_gmii_dv), .gmii_rx_er(ch2_gmii_er),
        .ddr_clk(ddr_clk), .ddr_rstn(ddr_rstn), .ddr_wreq(wr_req[2]), .ddr_waddr(wr_addr2), .ddr_wr_len(wr_len2), .ddr_wrdy(wr_ready_to_ch[2]), .ddr_wdone(wr_done_to_ch[2]), .ddr_wdata(wr_data2), .ddr_wdata_req(wr_data_req_to_ch[2]),
        .frame_done_bank(done_bank[2]), .frame_done_toggle(done_toggle[2]), .frame_done_count(ch2_frame_done_count), .udp_packet_count(), .fpgv_packet_count(), .accepted_packet_count(), .overflow_count(ch2_overflow_count), .last_frame_id(), .last_packet_id(), .last_packet_total(), .last_payload_len(), .last_byte_offset(), .debug_state(),
        .dbg_hdr_accept(w2_dbg_hdr_accept),
        .dbg_hdr_last_by_id(w2_dbg_hdr_last_by_id),
        .dbg_hdr_last_by_offset(w2_dbg_hdr_last_by_offset),
        .dbg_rx_prevbank_publish_candidate(w2_dbg_rx_prevbank_publish_candidate),
        .dbg_rx_relaxed_complete(w2_dbg_rx_relaxed_complete),
        .dbg_rx_publish_candidate(w2_dbg_rx_publish_candidate),
        .dbg_pkt_publish(w2_dbg_pkt_publish),
        .dbg_meta_wr_en(w2_dbg_meta_wr_en),
        .dbg_meta_pending_valid(w2_dbg_meta_pending_valid),
        .dbg_meta_full(w2_dbg_meta_full),
        .dbg_meta_empty(w2_dbg_meta_empty),
        .dbg_meta_rd_en(w2_dbg_meta_rd_en),
        .dbg_cmd_active(w2_dbg_cmd_active),
        .dbg_cmd_started(w2_dbg_cmd_started),
        .dbg_prev_publish_pending(w2_dbg_prev_publish_pending),
        .dbg_prev_publish_bank(w2_dbg_prev_publish_bank),
        .dbg_prev_publish_latched_count(w2_dbg_prev_publish_latched_count),
        .dbg_prevbank_publish_count(w2_dbg_prevbank_publish_count),
        .dbg_prevbank_skip_count(w2_dbg_prevbank_skip_count),
        .dbg_prevbank_packet_count_at_event(w2_dbg_prevbank_packet_count_at_event),
        .dbg_meta_wr_count(w2_dbg_meta_wr_count),
        .dbg_meta_rd_count(w2_dbg_meta_rd_count),
        .dbg_ddr_wreq_count(w2_dbg_ddr_wreq_count),
        .dbg_ddr_wdone_count(w2_dbg_ddr_wdone_count),
        .dbg_force_done_count(w2_dbg_force_done_count),
        .dbg_last_good_packet_id(w2_dbg_last_good_packet_id),
        .dbg_last_good_packet_total(w2_dbg_last_good_packet_total),
        .dbg_last_good_payload_len(w2_dbg_last_good_payload_len),
        .dbg_last_good_byte_offset(w2_dbg_last_good_byte_offset),
        .dbg_relaxed_publish_count(w2_dbg_relaxed_publish_count),
        .dbg_strict_publish_count(w2_dbg_strict_publish_count),
        .dbg_drop_bad_header_count(w2_dbg_drop_bad_header_count),
        .dbg_drop_no_free_slot_count(w2_dbg_drop_no_free_slot_count),
        .dbg_drop_meta_pending_count(w2_dbg_drop_meta_pending_count),
        .dbg_drop_meta_full_count(w2_dbg_drop_meta_full_count),
        .dbg_drop_gmii_error_count(w2_dbg_drop_gmii_error_count),
        .dbg_drop_payload_error_count(w2_dbg_drop_payload_error_count),
        .dbg_duplicate_packet_count(w2_dbg_duplicate_packet_count),
        .dbg_slot_busy_count(w2_dbg_slot_busy_count),
        .dbg_slot_busy_max(w2_dbg_slot_busy_max),
        .dbg_have_free_slot(w2_dbg_have_free_slot));
    fpgv_gmii_direct_ddr_writer_f14d #(.ADDR_WIDTH(CTRL_ADDR_WIDTH), .ADDR_OFFSET(CH3_OFFSET), .DQ_WIDTH(MEM_DQ_WIDTH), .LEN_WIDTH(LEN_WIDTH), .LINE_ADDR_WIDTH(LINE_ADDR_WIDTH), .PUBLISH_PREV_BANK_ON_PACKET0(1'b1), .MIN_PACKETS_FOR_PREV_BANK_PUBLISH(MIN_PACKETS_FOR_PREV_BANK_PUBLISH), .FORCE_FRAME_DONE_AFTER_ANY_WRITE(1'b0)) u_dir_wr3 (
        .gmii_clk(ch3_gmii_clk), .gmii_rstn(ch3_gmii_rstn), .gmii_rxd(ch3_gmii_rxd), .gmii_rx_dv(ch3_gmii_dv), .gmii_rx_er(ch3_gmii_er),
        .ddr_clk(ddr_clk), .ddr_rstn(ddr_rstn), .ddr_wreq(wr_req[3]), .ddr_waddr(wr_addr3), .ddr_wr_len(wr_len3), .ddr_wrdy(wr_ready_to_ch[3]), .ddr_wdone(wr_done_to_ch[3]), .ddr_wdata(wr_data3), .ddr_wdata_req(wr_data_req_to_ch[3]),
        .frame_done_bank(done_bank[3]), .frame_done_toggle(done_toggle[3]), .frame_done_count(ch3_frame_done_count), .udp_packet_count(), .fpgv_packet_count(), .accepted_packet_count(), .overflow_count(ch3_overflow_count), .last_frame_id(), .last_packet_id(), .last_packet_total(), .last_payload_len(), .last_byte_offset(), .debug_state());

    wire shared_wr_cmd_ready /* synthesis PAP_MARK_DEBUG="true" */;
    wire shared_wr_cmd_done /* synthesis PAP_MARK_DEBUG="true" */;
    wire shared_wr_data_req /* synthesis PAP_MARK_DEBUG="true" */;
    reg [1:0] wr_grant /* synthesis PAP_MARK_DEBUG="true" */;
    reg       wr_busy /* synthesis PAP_MARK_DEBUG="true" */;
    reg       wr_cmd_pending /* synthesis PAP_MARK_DEBUG="true" */;
    reg       shared_wr_cmd_en_r /* synthesis PAP_MARK_DEBUG="true" */;
    reg [CTRL_ADDR_WIDTH-1:0] shared_wr_cmd_addr_r;
    reg [LEN_WIDTH-1:0]       shared_wr_cmd_len_r;

    // F14O critical fix:
    // F14N pulsed shared_wr_cmd_en in the same clock edge that wr_grant was
    // updated.  wr_cmd_trans samples wr_cmd_addr/wr_cmd_len on that same edge,
    // so the mux still used the OLD wr_grant.  With CH2 input this often issued
    // a command using CH0's stale address/length, so wr_cmd_done/frame_done never
    // reached the requesting writer.
    //
    // F14O fully latches grant/address/length first, then asserts wr_cmd_en on
    // the next ddr_clk when the command bus is stable.  Data routing still uses
    // the latched wr_grant for the whole transaction.
    always @(posedge ddr_clk) begin
        if(!ddr_rstn) begin
            wr_grant             <= 2'd0;
            wr_busy              <= 1'b0;
            wr_cmd_pending       <= 1'b0;
            shared_wr_cmd_en_r   <= 1'b0;
            shared_wr_cmd_addr_r <= {CTRL_ADDR_WIDTH{1'b0}};
            shared_wr_cmd_len_r  <= {LEN_WIDTH{1'b0}};
        end else begin
            shared_wr_cmd_en_r <= 1'b0;

            if(!wr_busy) begin
                if(wr_req[0]) begin
                    wr_grant             <= 2'd0;
                    wr_busy              <= 1'b1;
                    wr_cmd_pending       <= 1'b1;
                    shared_wr_cmd_addr_r <= wr_addr0;
                    shared_wr_cmd_len_r  <= wr_len0;
                end else if(wr_req[1]) begin
                    wr_grant             <= 2'd1;
                    wr_busy              <= 1'b1;
                    wr_cmd_pending       <= 1'b1;
                    shared_wr_cmd_addr_r <= wr_addr1;
                    shared_wr_cmd_len_r  <= wr_len1;
                end else if(wr_req[2]) begin
                    wr_grant             <= 2'd2;
                    wr_busy              <= 1'b1;
                    wr_cmd_pending       <= 1'b1;
                    shared_wr_cmd_addr_r <= wr_addr2;
                    shared_wr_cmd_len_r  <= wr_len2;
                end else if(wr_req[3]) begin
                    wr_grant             <= 2'd3;
                    wr_busy              <= 1'b1;
                    wr_cmd_pending       <= 1'b1;
                    shared_wr_cmd_addr_r <= wr_addr3;
                    shared_wr_cmd_len_r  <= wr_len3;
                end
            end else if(wr_cmd_pending && shared_wr_cmd_ready) begin
                shared_wr_cmd_en_r <= 1'b1;
                wr_cmd_pending     <= 1'b0;
            end else if(shared_wr_cmd_done) begin
                wr_busy <= 1'b0;
            end
        end
    end

    wire [CTRL_ADDR_WIDTH-1:0] shared_wr_cmd_addr = shared_wr_cmd_addr_r;
    wire [LEN_WIDTH-1:0]       shared_wr_cmd_len  = shared_wr_cmd_len_r;
    wire [MEM_DQ_WIDTH*8-1:0]  shared_wr_data     = (wr_grant == 2'd0) ? wr_data0 : (wr_grant == 2'd1) ? wr_data1 : (wr_grant == 2'd2) ? wr_data2 : wr_data3;
    wire                       shared_wr_cmd_en /* synthesis PAP_MARK_DEBUG="true" */ = shared_wr_cmd_en_r;

    assign wr_ready_to_ch    = (wr_busy && !wr_cmd_pending && shared_wr_cmd_ready) ? (4'b0001 << wr_grant) : 4'b0000;
    assign wr_done_to_ch     = (wr_busy && shared_wr_cmd_done)  ? (4'b0001 << wr_grant) : 4'b0000;
    assign wr_data_req_to_ch = (wr_busy && shared_wr_data_req)  ? (4'b0001 << wr_grant) : 4'b0000;

// F14O_DEBUG_PROBES: convenient CH2-only probes for PDS Debugger.
wire dbg_ch2_wr_req      /* synthesis PAP_MARK_DEBUG="true" */ = wr_req[2];
wire dbg_ch2_wr_done     /* synthesis PAP_MARK_DEBUG="true" */ = wr_done_to_ch[2];
wire dbg_ch2_wdata_req   /* synthesis PAP_MARK_DEBUG="true" */ = wr_data_req_to_ch[2];
wire dbg_wr_grant_is_ch2 /* synthesis PAP_MARK_DEBUG="true" */ = (wr_grant == 2'd2);
wire dbg_wr_cmd_en       /* synthesis PAP_MARK_DEBUG="true" */ = shared_wr_cmd_en;
wire dbg_wr_cmd_done     /* synthesis PAP_MARK_DEBUG="true" */ = shared_wr_cmd_done;


    wire [3:0] rd_req /* synthesis PAP_MARK_DEBUG="true" */;
    wire [CTRL_ADDR_WIDTH-1:0] rd_addr0, rd_addr1, rd_addr2, rd_addr3;
    wire [LEN_WIDTH-1:0]       rd_len0,  rd_len1,  rd_len2,  rd_len3;
    wire [3:0] rd_ready_to_ch;
    wire [3:0] rd_done_to_ch /* synthesis PAP_MARK_DEBUG="true" */;
    wire [3:0] rd_data_en_to_ch;
    wire [MEM_DQ_WIDTH*8-1:0] shared_read_rdata;

    rd_buf #(.ADDR_WIDTH(CTRL_ADDR_WIDTH), .ADDR_OFFSET(CH0_OFFSET), .H_NUM(H_NUM), .V_NUM(V_NUM), .DQ_WIDTH(MEM_DQ_WIDTH), .LEN_WIDTH(LEN_WIDTH), .PIX_WIDTH(PIX_WIDTH), .LINE_ADDR_WIDTH(LINE_ADDR_WIDTH), .FRAME_CNT_WIDTH(FRAME_CNT_WIDTH)) u_rd0 (
        .ddr_clk(ddr_clk), .ddr_rstn(ddr_rstn), .vout_clk(vout_clk), .rd_fsync(rd_fsync), .rd_en(rd_en_ch0), .rd_line_req(rd_line_req_ch0), .vout_de(vout_de_ch0), .vout_data(vout_data_ch0), .frame_sel(done_bank[0]), .frame_sel_toggle(done_toggle[0]), .init_done(init_done[0]),
        .ddr_rreq(rd_req[0]), .ddr_raddr(rd_addr0), .ddr_rd_len(rd_len0), .ddr_rrdy(rd_ready_to_ch[0]), .ddr_rdone(rd_done_to_ch[0]), .ddr_rdata(shared_read_rdata), .ddr_rdata_en(rd_data_en_to_ch[0]));
    rd_buf #(.ADDR_WIDTH(CTRL_ADDR_WIDTH), .ADDR_OFFSET(CH1_OFFSET), .H_NUM(H_NUM), .V_NUM(V_NUM), .DQ_WIDTH(MEM_DQ_WIDTH), .LEN_WIDTH(LEN_WIDTH), .PIX_WIDTH(PIX_WIDTH), .LINE_ADDR_WIDTH(LINE_ADDR_WIDTH), .FRAME_CNT_WIDTH(FRAME_CNT_WIDTH)) u_rd1 (
        .ddr_clk(ddr_clk), .ddr_rstn(ddr_rstn), .vout_clk(vout_clk), .rd_fsync(rd_fsync), .rd_en(rd_en_ch1), .rd_line_req(rd_line_req_ch1), .vout_de(vout_de_ch1), .vout_data(vout_data_ch1), .frame_sel(done_bank[1]), .frame_sel_toggle(done_toggle[1]), .init_done(init_done[1]),
        .ddr_rreq(rd_req[1]), .ddr_raddr(rd_addr1), .ddr_rd_len(rd_len1), .ddr_rrdy(rd_ready_to_ch[1]), .ddr_rdone(rd_done_to_ch[1]), .ddr_rdata(shared_read_rdata), .ddr_rdata_en(rd_data_en_to_ch[1]));
    rd_buf #(.ADDR_WIDTH(CTRL_ADDR_WIDTH), .ADDR_OFFSET(CH2_OFFSET), .H_NUM(H_NUM), .V_NUM(V_NUM), .DQ_WIDTH(MEM_DQ_WIDTH), .LEN_WIDTH(LEN_WIDTH), .PIX_WIDTH(PIX_WIDTH), .LINE_ADDR_WIDTH(LINE_ADDR_WIDTH), .FRAME_CNT_WIDTH(FRAME_CNT_WIDTH)) u_rd2 (
        .ddr_clk(ddr_clk), .ddr_rstn(ddr_rstn), .vout_clk(vout_clk), .rd_fsync(rd_fsync), .rd_en(rd_en_ch2), .rd_line_req(rd_line_req_ch2), .vout_de(vout_de_ch2), .vout_data(vout_data_ch2), .frame_sel(done_bank[2]), .frame_sel_toggle(done_toggle[2]), .init_done(init_done[2]),
        .ddr_rreq(rd_req[2]), .ddr_raddr(rd_addr2), .ddr_rd_len(rd_len2), .ddr_rrdy(rd_ready_to_ch[2]), .ddr_rdone(rd_done_to_ch[2]), .ddr_rdata(shared_read_rdata), .ddr_rdata_en(rd_data_en_to_ch[2]));
    rd_buf #(.ADDR_WIDTH(CTRL_ADDR_WIDTH), .ADDR_OFFSET(CH3_OFFSET), .H_NUM(H_NUM), .V_NUM(V_NUM), .DQ_WIDTH(MEM_DQ_WIDTH), .LEN_WIDTH(LEN_WIDTH), .PIX_WIDTH(PIX_WIDTH), .LINE_ADDR_WIDTH(LINE_ADDR_WIDTH), .FRAME_CNT_WIDTH(FRAME_CNT_WIDTH)) u_rd3 (
        .ddr_clk(ddr_clk), .ddr_rstn(ddr_rstn), .vout_clk(vout_clk), .rd_fsync(rd_fsync), .rd_en(rd_en_ch3), .rd_line_req(rd_line_req_ch3), .vout_de(vout_de_ch3), .vout_data(vout_data_ch3), .frame_sel(done_bank[3]), .frame_sel_toggle(done_toggle[3]), .init_done(init_done[3]),
        .ddr_rreq(rd_req[3]), .ddr_raddr(rd_addr3), .ddr_rd_len(rd_len3), .ddr_rrdy(rd_ready_to_ch[3]), .ddr_rdone(rd_done_to_ch[3]), .ddr_rdata(shared_read_rdata), .ddr_rdata_en(rd_data_en_to_ch[3]));

    wire shared_rd_cmd_ready /* synthesis PAP_MARK_DEBUG="true" */;
    wire shared_rd_cmd_done /* synthesis PAP_MARK_DEBUG="true" */;
    wire shared_read_en;
    wire read_ready = 1'b1;
    reg [1:0] rd_grant;
    reg       rd_busy;
    reg       rd_cmd_pending;
    reg       shared_rd_cmd_en_r /* synthesis PAP_MARK_DEBUG="true" */;
    reg [CTRL_ADDR_WIDTH-1:0] shared_rd_cmd_addr_r;
    reg [LEN_WIDTH-1:0]       shared_rd_cmd_len_r;

    // F14O: use the same latched-command pattern on the read side so the
    // command address/length match the granted window.
    always @(posedge ddr_clk) begin
        if(!ddr_rstn) begin
            rd_grant             <= 2'd0;
            rd_busy              <= 1'b0;
            rd_cmd_pending       <= 1'b0;
            shared_rd_cmd_en_r   <= 1'b0;
            shared_rd_cmd_addr_r <= {CTRL_ADDR_WIDTH{1'b0}};
            shared_rd_cmd_len_r  <= {LEN_WIDTH{1'b0}};
        end else begin
            shared_rd_cmd_en_r <= 1'b0;

            if(!rd_busy) begin
                if(rd_req[0]) begin
                    rd_grant             <= 2'd0;
                    rd_busy              <= 1'b1;
                    rd_cmd_pending       <= 1'b1;
                    shared_rd_cmd_addr_r <= rd_addr0;
                    shared_rd_cmd_len_r  <= rd_len0;
                end else if(rd_req[1]) begin
                    rd_grant             <= 2'd1;
                    rd_busy              <= 1'b1;
                    rd_cmd_pending       <= 1'b1;
                    shared_rd_cmd_addr_r <= rd_addr1;
                    shared_rd_cmd_len_r  <= rd_len1;
                end else if(rd_req[2]) begin
                    rd_grant             <= 2'd2;
                    rd_busy              <= 1'b1;
                    rd_cmd_pending       <= 1'b1;
                    shared_rd_cmd_addr_r <= rd_addr2;
                    shared_rd_cmd_len_r  <= rd_len2;
                end else if(rd_req[3]) begin
                    rd_grant             <= 2'd3;
                    rd_busy              <= 1'b1;
                    rd_cmd_pending       <= 1'b1;
                    shared_rd_cmd_addr_r <= rd_addr3;
                    shared_rd_cmd_len_r  <= rd_len3;
                end
            end else if(rd_cmd_pending && shared_rd_cmd_ready) begin
                shared_rd_cmd_en_r <= 1'b1;
                rd_cmd_pending     <= 1'b0;
            end else if(shared_rd_cmd_done) begin
                rd_busy <= 1'b0;
            end
        end
    end

    wire [CTRL_ADDR_WIDTH-1:0] shared_rd_cmd_addr = shared_rd_cmd_addr_r;
    wire [LEN_WIDTH-1:0]       shared_rd_cmd_len  = shared_rd_cmd_len_r;
    wire                       shared_rd_cmd_en   = shared_rd_cmd_en_r;

    assign rd_ready_to_ch   = (rd_busy && !rd_cmd_pending && shared_rd_cmd_ready) ? (4'b0001 << rd_grant) : 4'b0000;
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


    // F14W deterministic debug output assignments.
    assign dbg_ch2_wr_req_out                         = wr_req[2];
    assign dbg_ch2_wr_done_out                        = wr_done_to_ch[2];
    assign dbg_ch2_wdata_req_out                      = wr_data_req_to_ch[2];
    assign dbg_ch2_wr_grant_is_ch2_out                = (wr_grant == 2'd2);
    assign dbg_shared_wr_cmd_en_out                   = shared_wr_cmd_en;
    assign dbg_shared_wr_cmd_done_out                 = shared_wr_cmd_done;
    assign dbg_ch2_rd_req_out                         = rd_req[2];
    assign dbg_ch2_rd_done_out                        = rd_done_to_ch[2];
    assign dbg_ch2_rd_ready_out                       = rd_ready_to_ch[2];
    assign dbg_ch2_rd_data_en_out                     = rd_data_en_to_ch[2];
    assign dbg_ch2_rd_grant_is_ch2_out                = (rd_grant == 2'd2);
    assign dbg_shared_rd_cmd_en_out                   = shared_rd_cmd_en;
    assign dbg_shared_rd_cmd_done_out                 = shared_rd_cmd_done;
    assign dbg_shared_rd_cmd_ready_out                = shared_rd_cmd_ready;
    assign dbg_ch2_done_bank_out                      = done_bank[2];
    assign dbg_ch2_done_toggle_out                    = done_toggle[2];
    assign dbg_ch2_init_done_out                      = init_done[2];
    assign dbg_ch2_hdr_accept_out                     = w2_dbg_hdr_accept;
    assign dbg_ch2_hdr_last_by_id_out                 = w2_dbg_hdr_last_by_id;
    assign dbg_ch2_hdr_last_by_offset_out             = w2_dbg_hdr_last_by_offset;
    assign dbg_ch2_rx_prevbank_candidate_out          = w2_dbg_rx_prevbank_publish_candidate;
    assign dbg_ch2_rx_relaxed_complete_out            = w2_dbg_rx_relaxed_complete;
    assign dbg_ch2_rx_publish_candidate_out           = w2_dbg_rx_publish_candidate;
    assign dbg_ch2_pkt_publish_out                    = w2_dbg_pkt_publish;
    assign dbg_ch2_meta_wr_en_out                     = w2_dbg_meta_wr_en;
    assign dbg_ch2_meta_pending_valid_out             = w2_dbg_meta_pending_valid;
    assign dbg_ch2_meta_full_out                      = w2_dbg_meta_full;
    assign dbg_ch2_meta_empty_out                     = w2_dbg_meta_empty;
    assign dbg_ch2_meta_rd_en_out                     = w2_dbg_meta_rd_en;
    assign dbg_ch2_cmd_active_out                     = w2_dbg_cmd_active;
    assign dbg_ch2_cmd_started_out                    = w2_dbg_cmd_started;
    assign dbg_ch2_prev_publish_pending_out           = w2_dbg_prev_publish_pending;
    assign dbg_ch2_prev_publish_bank_out              = w2_dbg_prev_publish_bank;
    assign dbg_ch2_prev_publish_latched_count_out     = w2_dbg_prev_publish_latched_count;
    assign dbg_ch2_prevbank_publish_count_out         = w2_dbg_prevbank_publish_count;
    assign dbg_ch2_prevbank_skip_count_out            = w2_dbg_prevbank_skip_count;
    assign dbg_ch2_prevbank_packet_count_at_event_out = w2_dbg_prevbank_packet_count_at_event;
    assign dbg_ch2_meta_wr_count_out                  = w2_dbg_meta_wr_count;
    assign dbg_ch2_meta_rd_count_out                  = w2_dbg_meta_rd_count;
    assign dbg_ch2_ddr_wreq_count_out                 = w2_dbg_ddr_wreq_count;
    assign dbg_ch2_ddr_wdone_count_out                = w2_dbg_ddr_wdone_count;
    assign dbg_ch2_force_done_count_out               = w2_dbg_force_done_count;
    assign dbg_ch2_last_good_packet_id_out            = w2_dbg_last_good_packet_id;
    assign dbg_ch2_last_good_packet_total_out         = w2_dbg_last_good_packet_total;
    assign dbg_ch2_last_good_payload_len_out          = w2_dbg_last_good_payload_len;
    assign dbg_ch2_last_good_byte_offset_out          = w2_dbg_last_good_byte_offset;
    assign dbg_ch2_relaxed_publish_count_out          = w2_dbg_relaxed_publish_count;
    assign dbg_ch2_strict_publish_count_out           = w2_dbg_strict_publish_count;
    assign dbg_ch2_drop_bad_header_count_out           = w2_dbg_drop_bad_header_count;
    assign dbg_ch2_drop_no_free_slot_count_out         = w2_dbg_drop_no_free_slot_count;
    assign dbg_ch2_drop_meta_pending_count_out         = w2_dbg_drop_meta_pending_count;
    assign dbg_ch2_drop_meta_full_count_out            = w2_dbg_drop_meta_full_count;
    assign dbg_ch2_drop_gmii_error_count_out           = w2_dbg_drop_gmii_error_count;
    assign dbg_ch2_drop_payload_error_count_out        = w2_dbg_drop_payload_error_count;
    assign dbg_ch2_duplicate_packet_count_out          = w2_dbg_duplicate_packet_count;
    assign dbg_ch2_slot_busy_count_out                 = w2_dbg_slot_busy_count;
    assign dbg_ch2_slot_busy_max_out                   = w2_dbg_slot_busy_max;
    assign dbg_ch2_have_free_slot_out                  = w2_dbg_have_free_slot;

endmodule
