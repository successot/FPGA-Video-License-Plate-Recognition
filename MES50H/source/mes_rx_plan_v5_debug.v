`timescale 1ns / 1ps
`default_nettype wire
// -----------------------------------------------------------------------------
// MES50H RX plan V5 debug wrapper
// Implements the plan's missing Stage-1/Stage-2 coverage:
//   - monitors all 8 RJ45 GMII RX channels in parallel
//   - detects Ethernet/IPv4/UDP dst-port 5000/FPGV packets on every channel
//   - exposes sticky channel vectors for Pango debug and LED indication
// Channel bit order:
//   [0] U10 ch0, [1] U10 ch1, [2] U10 ch2, [3] U10 ch3,
//   [4] U2  ch0, [5] U2  ch1, [6] U2  ch2, [7] U2  ch3
// -----------------------------------------------------------------------------
module mes_rx_plan_v5_debug #(
    parameter [47:0] LOCAL_MAC = 48'h02_00_00_00_50_01,
    parameter [31:0] LOCAL_IP  = 32'hC0A8_0164,
    parameter [15:0] UDP_PORT  = 16'd5000,
    // Port-matrix diagnostic selector: 0=U10 CH2, 1=U2 CH2.
    parameter        DIAG_USE_U2_CH2 = 1'b0
)(
    input             free_clk,
    input             free_rst_n,
    input      [7:0]  link,

    input             clk_u10_ch0,
    input             rstn_u10_ch0,
    input      [7:0]  rxd_u10_ch0,
    input             dv_u10_ch0,
    input             er_u10_ch0,

    input             clk_u10_ch1,
    input             rstn_u10_ch1,
    input      [7:0]  rxd_u10_ch1,
    input             dv_u10_ch1,
    input             er_u10_ch1,

    input             clk_u10_ch2,
    input             rstn_u10_ch2,
    input      [7:0]  rxd_u10_ch2,
    input             dv_u10_ch2,
    input             er_u10_ch2,

    input             clk_u10_ch3,
    input             rstn_u10_ch3,
    input      [7:0]  rxd_u10_ch3,
    input             dv_u10_ch3,
    input             er_u10_ch3,

    input             clk_u2_ch0,
    input             rstn_u2_ch0,
    input      [7:0]  rxd_u2_ch0,
    input             dv_u2_ch0,
    input             er_u2_ch0,

    input             clk_u2_ch1,
    input             rstn_u2_ch1,
    input      [7:0]  rxd_u2_ch1,
    input             dv_u2_ch1,
    input             er_u2_ch1,

    input             clk_u2_ch2,
    input             rstn_u2_ch2,
    input      [7:0]  rxd_u2_ch2,
    input             dv_u2_ch2,
    input             er_u2_ch2,

    input             clk_u2_ch3,
    input             rstn_u2_ch3,
    input      [7:0]  rxd_u2_ch3,
    input             dv_u2_ch3,
    input             er_u2_ch3,

    output     [7:0]  rx_activity_live /* synthesis PAP_MARK_DEBUG="true" */,
    output     [7:0]  rx_frame_seen    /* synthesis PAP_MARK_DEBUG="true" */,
    output     [7:0]  udp5000_seen     /* synthesis PAP_MARK_DEBUG="true" */,
    output     [7:0]  fpgv_seen        /* synthesis PAP_MARK_DEBUG="true" */,
    output     [7:0]  rx_error_seen    /* synthesis PAP_MARK_DEBUG="true" */,
    output     [2:0]  active_channel   /* synthesis PAP_MARK_DEBUG="true" */,
    output     [7:0]  debug_led        /* synthesis PAP_MARK_DEBUG="true" */,

    // PORT_MATRIX_DIAG_V3: reuse the existing selected ingress CH2 monitor counters.
    output     [31:0] diag_selected_ch2_frame_count,
    output     [31:0] diag_selected_ch2_udp5000_count,
    output     [31:0] diag_selected_ch2_fpgv_count,
    output     [31:0] diag_selected_ch2_er_cycle_count,
    output     [15:0] diag_selected_ch2_last_packet_id,
    output     [15:0] diag_selected_ch2_last_packet_total
);

wire        frame_pulse_0, frame_pulse_1, frame_pulse_2, frame_pulse_3;
wire        frame_pulse_4, frame_pulse_5, frame_pulse_6, frame_pulse_7;
wire        udp_pulse_0, udp_pulse_1, udp_pulse_2, udp_pulse_3;
wire        udp_pulse_4, udp_pulse_5, udp_pulse_6, udp_pulse_7;
wire        fpgv_pulse_0, fpgv_pulse_1, fpgv_pulse_2, fpgv_pulse_3;
wire        fpgv_pulse_4, fpgv_pulse_5, fpgv_pulse_6, fpgv_pulse_7;
wire        err_pulse_0, err_pulse_1, err_pulse_2, err_pulse_3;
wire        err_pulse_4, err_pulse_5, err_pulse_6, err_pulse_7;

wire [31:0] frame_count_0, frame_count_1, frame_count_2, frame_count_3;
wire [31:0] frame_count_4, frame_count_5, frame_count_6, frame_count_7;
wire [31:0] udp_count_0, udp_count_1, udp_count_2, udp_count_3;
wire [31:0] udp_count_4, udp_count_5, udp_count_6, udp_count_7;
wire [31:0] fpgv_count_0, fpgv_count_1, fpgv_count_2, fpgv_count_3;
wire [31:0] fpgv_count_4, fpgv_count_5, fpgv_count_6, fpgv_count_7;
wire [31:0] err_count_0, err_count_1, err_count_2, err_count_3;
wire [31:0] err_count_4, err_count_5, err_count_6, err_count_7;

wire [31:0] frame_id_0, frame_id_1, frame_id_2, frame_id_3;
wire [31:0] frame_id_4, frame_id_5, frame_id_6, frame_id_7;
wire [15:0] pkt_id_0, pkt_id_1, pkt_id_2, pkt_id_3;
wire [15:0] pkt_id_4, pkt_id_5, pkt_id_6, pkt_id_7;
wire [15:0] pkt_total_0, pkt_total_1, pkt_total_2, pkt_total_3;
wire [15:0] pkt_total_4, pkt_total_5, pkt_total_6, pkt_total_7;
wire [15:0] width_0, width_1, width_2, width_3;
wire [15:0] width_4, width_5, width_6, width_7;
wire [15:0] height_0, height_1, height_2, height_3;
wire [15:0] height_4, height_5, height_6, height_7;
wire [7:0]  mode_0, mode_1, mode_2, mode_3;
wire [7:0]  mode_4, mode_5, mode_6, mode_7;
wire [7:0]  mon_led_0, mon_led_1, mon_led_2, mon_led_3;
wire [7:0]  mon_led_4, mon_led_5, mon_led_6, mon_led_7;

fpgv_gmii_rx_monitor #(.LOCAL_MAC(LOCAL_MAC), .LOCAL_IP(LOCAL_IP), .UDP_PORT(UDP_PORT)) u_mon_u10_ch0 (
    .clk(clk_u10_ch0), .rst_n(rstn_u10_ch0), .gmii_rxd(rxd_u10_ch0), .gmii_rx_dv(dv_u10_ch0), .gmii_rx_er(er_u10_ch0),
    .gmii_frame_pulse(frame_pulse_0), .ip_udp_pulse(udp_pulse_0), .fpgv_pulse(fpgv_pulse_0), .error_pulse(err_pulse_0),
    .gmii_frame_count(frame_count_0), .udp_packet_count(udp_count_0), .fpgv_packet_count(fpgv_count_0), .error_count(err_count_0),
    .last_frame_id(frame_id_0), .last_packet_id(pkt_id_0), .last_packet_total(pkt_total_0), .last_width(width_0), .last_height(height_0), .last_mode(mode_0),
    .debug_led(mon_led_0)
);

fpgv_gmii_rx_monitor #(.LOCAL_MAC(LOCAL_MAC), .LOCAL_IP(LOCAL_IP), .UDP_PORT(UDP_PORT)) u_mon_u10_ch1 (
    .clk(clk_u10_ch1), .rst_n(rstn_u10_ch1), .gmii_rxd(rxd_u10_ch1), .gmii_rx_dv(dv_u10_ch1), .gmii_rx_er(er_u10_ch1),
    .gmii_frame_pulse(frame_pulse_1), .ip_udp_pulse(udp_pulse_1), .fpgv_pulse(fpgv_pulse_1), .error_pulse(err_pulse_1),
    .gmii_frame_count(frame_count_1), .udp_packet_count(udp_count_1), .fpgv_packet_count(fpgv_count_1), .error_count(err_count_1),
    .last_frame_id(frame_id_1), .last_packet_id(pkt_id_1), .last_packet_total(pkt_total_1), .last_width(width_1), .last_height(height_1), .last_mode(mode_1),
    .debug_led(mon_led_1)
);

fpgv_gmii_rx_monitor #(.LOCAL_MAC(LOCAL_MAC), .LOCAL_IP(LOCAL_IP), .UDP_PORT(UDP_PORT)) u_mon_u10_ch2 (
    .clk(clk_u10_ch2), .rst_n(rstn_u10_ch2), .gmii_rxd(rxd_u10_ch2), .gmii_rx_dv(dv_u10_ch2), .gmii_rx_er(er_u10_ch2),
    .gmii_frame_pulse(frame_pulse_2), .ip_udp_pulse(udp_pulse_2), .fpgv_pulse(fpgv_pulse_2), .error_pulse(err_pulse_2),
    .gmii_frame_count(frame_count_2), .udp_packet_count(udp_count_2), .fpgv_packet_count(fpgv_count_2), .error_count(err_count_2),
    .last_frame_id(frame_id_2), .last_packet_id(pkt_id_2), .last_packet_total(pkt_total_2), .last_width(width_2), .last_height(height_2), .last_mode(mode_2),
    .debug_led(mon_led_2)
);

fpgv_gmii_rx_monitor #(.LOCAL_MAC(LOCAL_MAC), .LOCAL_IP(LOCAL_IP), .UDP_PORT(UDP_PORT)) u_mon_u10_ch3 (
    .clk(clk_u10_ch3), .rst_n(rstn_u10_ch3), .gmii_rxd(rxd_u10_ch3), .gmii_rx_dv(dv_u10_ch3), .gmii_rx_er(er_u10_ch3),
    .gmii_frame_pulse(frame_pulse_3), .ip_udp_pulse(udp_pulse_3), .fpgv_pulse(fpgv_pulse_3), .error_pulse(err_pulse_3),
    .gmii_frame_count(frame_count_3), .udp_packet_count(udp_count_3), .fpgv_packet_count(fpgv_count_3), .error_count(err_count_3),
    .last_frame_id(frame_id_3), .last_packet_id(pkt_id_3), .last_packet_total(pkt_total_3), .last_width(width_3), .last_height(height_3), .last_mode(mode_3),
    .debug_led(mon_led_3)
);

fpgv_gmii_rx_monitor #(.LOCAL_MAC(LOCAL_MAC), .LOCAL_IP(LOCAL_IP), .UDP_PORT(UDP_PORT)) u_mon_u2_ch0 (
    .clk(clk_u2_ch0), .rst_n(rstn_u2_ch0), .gmii_rxd(rxd_u2_ch0), .gmii_rx_dv(dv_u2_ch0), .gmii_rx_er(er_u2_ch0),
    .gmii_frame_pulse(frame_pulse_4), .ip_udp_pulse(udp_pulse_4), .fpgv_pulse(fpgv_pulse_4), .error_pulse(err_pulse_4),
    .gmii_frame_count(frame_count_4), .udp_packet_count(udp_count_4), .fpgv_packet_count(fpgv_count_4), .error_count(err_count_4),
    .last_frame_id(frame_id_4), .last_packet_id(pkt_id_4), .last_packet_total(pkt_total_4), .last_width(width_4), .last_height(height_4), .last_mode(mode_4),
    .debug_led(mon_led_4)
);

fpgv_gmii_rx_monitor #(.LOCAL_MAC(LOCAL_MAC), .LOCAL_IP(LOCAL_IP), .UDP_PORT(UDP_PORT)) u_mon_u2_ch1 (
    .clk(clk_u2_ch1), .rst_n(rstn_u2_ch1), .gmii_rxd(rxd_u2_ch1), .gmii_rx_dv(dv_u2_ch1), .gmii_rx_er(er_u2_ch1),
    .gmii_frame_pulse(frame_pulse_5), .ip_udp_pulse(udp_pulse_5), .fpgv_pulse(fpgv_pulse_5), .error_pulse(err_pulse_5),
    .gmii_frame_count(frame_count_5), .udp_packet_count(udp_count_5), .fpgv_packet_count(fpgv_count_5), .error_count(err_count_5),
    .last_frame_id(frame_id_5), .last_packet_id(pkt_id_5), .last_packet_total(pkt_total_5), .last_width(width_5), .last_height(height_5), .last_mode(mode_5),
    .debug_led(mon_led_5)
);

fpgv_gmii_rx_monitor #(.LOCAL_MAC(LOCAL_MAC), .LOCAL_IP(LOCAL_IP), .UDP_PORT(UDP_PORT)) u_mon_u2_ch2 (
    .clk(clk_u2_ch2), .rst_n(rstn_u2_ch2), .gmii_rxd(rxd_u2_ch2), .gmii_rx_dv(dv_u2_ch2), .gmii_rx_er(er_u2_ch2),
    .gmii_frame_pulse(frame_pulse_6), .ip_udp_pulse(udp_pulse_6), .fpgv_pulse(fpgv_pulse_6), .error_pulse(err_pulse_6),
    .gmii_frame_count(frame_count_6), .udp_packet_count(udp_count_6), .fpgv_packet_count(fpgv_count_6), .error_count(err_count_6),
    .last_frame_id(frame_id_6), .last_packet_id(pkt_id_6), .last_packet_total(pkt_total_6), .last_width(width_6), .last_height(height_6), .last_mode(mode_6),
    .debug_led(mon_led_6)
);

fpgv_gmii_rx_monitor #(.LOCAL_MAC(LOCAL_MAC), .LOCAL_IP(LOCAL_IP), .UDP_PORT(UDP_PORT)) u_mon_u2_ch3 (
    .clk(clk_u2_ch3), .rst_n(rstn_u2_ch3), .gmii_rxd(rxd_u2_ch3), .gmii_rx_dv(dv_u2_ch3), .gmii_rx_er(er_u2_ch3),
    .gmii_frame_pulse(frame_pulse_7), .ip_udp_pulse(udp_pulse_7), .fpgv_pulse(fpgv_pulse_7), .error_pulse(err_pulse_7),
    .gmii_frame_count(frame_count_7), .udp_packet_count(udp_count_7), .fpgv_packet_count(fpgv_count_7), .error_count(err_count_7),
    .last_frame_id(frame_id_7), .last_packet_id(pkt_id_7), .last_packet_total(pkt_total_7), .last_width(width_7), .last_height(height_7), .last_mode(mode_7),
    .debug_led(mon_led_7)
);

assign rx_activity_live = {dv_u2_ch3, dv_u2_ch2, dv_u2_ch1, dv_u2_ch0, dv_u10_ch3, dv_u10_ch2, dv_u10_ch1, dv_u10_ch0};
assign rx_frame_seen    = {|frame_count_7, |frame_count_6, |frame_count_5, |frame_count_4, |frame_count_3, |frame_count_2, |frame_count_1, |frame_count_0};
assign udp5000_seen     = {|udp_count_7,   |udp_count_6,   |udp_count_5,   |udp_count_4,   |udp_count_3,   |udp_count_2,   |udp_count_1,   |udp_count_0};
assign fpgv_seen        = {|fpgv_count_7,  |fpgv_count_6,  |fpgv_count_5,  |fpgv_count_4,  |fpgv_count_3,  |fpgv_count_2,  |fpgv_count_1,  |fpgv_count_0};
assign rx_error_seen    = {|err_count_7,   |err_count_6,   |err_count_5,   |err_count_4,   |err_count_3,   |err_count_2,   |err_count_1,   |err_count_0};

// PORT_MATRIX_DIAG_V3: no extra parser instance is created.
// U10 CH2 is monitor index 2; U2 CH2 is monitor index 6.
assign diag_selected_ch2_frame_count       = DIAG_USE_U2_CH2 ? frame_count_6 : frame_count_2;
assign diag_selected_ch2_udp5000_count     = DIAG_USE_U2_CH2 ? udp_count_6   : udp_count_2;
assign diag_selected_ch2_fpgv_count        = DIAG_USE_U2_CH2 ? fpgv_count_6  : fpgv_count_2;
assign diag_selected_ch2_er_cycle_count    = DIAG_USE_U2_CH2 ? err_count_6   : err_count_2;
assign diag_selected_ch2_last_packet_id    = DIAG_USE_U2_CH2 ? pkt_id_6      : pkt_id_2;
assign diag_selected_ch2_last_packet_total = DIAG_USE_U2_CH2 ? pkt_total_6   : pkt_total_2;

reg [2:0] active_channel_r;
always @(*) begin
    if(fpgv_seen[0] | udp5000_seen[0] | rx_frame_seen[0])       active_channel_r = 3'd0;
    else if(fpgv_seen[1] | udp5000_seen[1] | rx_frame_seen[1])  active_channel_r = 3'd1;
    else if(fpgv_seen[2] | udp5000_seen[2] | rx_frame_seen[2])  active_channel_r = 3'd2;
    else if(fpgv_seen[3] | udp5000_seen[3] | rx_frame_seen[3])  active_channel_r = 3'd3;
    else if(fpgv_seen[4] | udp5000_seen[4] | rx_frame_seen[4])  active_channel_r = 3'd4;
    else if(fpgv_seen[5] | udp5000_seen[5] | rx_frame_seen[5])  active_channel_r = 3'd5;
    else if(fpgv_seen[6] | udp5000_seen[6] | rx_frame_seen[6])  active_channel_r = 3'd6;
    else if(fpgv_seen[7] | udp5000_seen[7] | rx_frame_seen[7])  active_channel_r = 3'd7;
    else                                                       active_channel_r = 3'd0;
end
assign active_channel = active_channel_r;

// V4 RSTN-SAFE: free_rst_n is sourced from cross_reset_sync external_rstn.
// Use synchronous reset for this free_clk-domain side-band heartbeat.
reg [25:0] hb_cnt;
reg        heartbeat;
always @(posedge free_clk) begin
    if(!free_rst_n) begin
        hb_cnt    <= 26'd0;
        heartbeat <= 1'b0;
    end else begin
        hb_cnt <= hb_cnt + 26'd1;
        if(hb_cnt == 26'd0)
            heartbeat <= ~heartbeat;
    end
end

assign debug_led[0] = heartbeat;           // FPGA free_clk heartbeat
assign debug_led[1] = |link;               // any RJ45 link up
assign debug_led[2] = |rx_activity_live;   // any channel is receiving right now
assign debug_led[3] = |rx_frame_seen[3:0]; // any U10 channel has received at least one frame
assign debug_led[4] = |rx_frame_seen[7:4]; // any U2 channel has received at least one frame
assign debug_led[5] = |udp5000_seen;       // UDP dst port 5000 seen on any channel
assign debug_led[6] = |fpgv_seen;          // FPGV magic seen on any channel
assign debug_led[7] = |rx_error_seen;      // GMII RX error seen

endmodule
