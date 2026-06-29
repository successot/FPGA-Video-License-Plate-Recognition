`timescale 1ns / 1ps
`default_nettype wire
// -----------------------------------------------------------------------------
// MES50HP Stage5B SFP0 RX 4-channel FPGV/UDP monitor.
// This is a receive-only debug wrapper for the link:
//   MES50H SFP0 -> DAC/fiber -> MES50HP SFP0 -> HSST lane2 -> QSGMII -> GMII ch0..ch3
//
// It uses the already-verified fpgv_gmii_rx_monitor from the MES50H frozen project.
// Channel bit order:
//   [0] SFP0/QSGMII ch0
//   [1] SFP0/QSGMII ch1
//   [2] SFP0/QSGMII ch2
//   [3] SFP0/QSGMII ch3
// -----------------------------------------------------------------------------
module mes50hp_sfp_rx_debug_4ch #(
    parameter [47:0] LOCAL_MAC = 48'h02_00_00_00_50_01,
    parameter [31:0] LOCAL_IP  = 32'hC0A8_0164,   // 192.168.1.100
    parameter [15:0] UDP_PORT  = 16'd5000
)(
    input             free_clk,
    input             free_rst_n,

    input             clk_ch0,
    input             rstn_ch0,
    input      [7:0]  rxd_ch0,
    input             dv_ch0,
    input             er_ch0,

    input             clk_ch1,
    input             rstn_ch1,
    input      [7:0]  rxd_ch1,
    input             dv_ch1,
    input             er_ch1,

    input             clk_ch2,
    input             rstn_ch2,
    input      [7:0]  rxd_ch2,
    input             dv_ch2,
    input             er_ch2,

    input             clk_ch3,
    input             rstn_ch3,
    input      [7:0]  rxd_ch3,
    input             dv_ch3,
    input             er_ch3,

    output     [3:0]  rx_activity_live /* synthesis PAP_MARK_DEBUG="true" */,
    output     [3:0]  rx_frame_seen    /* synthesis PAP_MARK_DEBUG="true" */,
    output     [3:0]  udp5000_seen     /* synthesis PAP_MARK_DEBUG="true" */,
    output     [3:0]  fpgv_seen        /* synthesis PAP_MARK_DEBUG="true" */,
    output     [3:0]  rx_error_seen    /* synthesis PAP_MARK_DEBUG="true" */,
    output reg [1:0]  active_channel   /* synthesis PAP_MARK_DEBUG="true" */,

    output     [15:0] last_packet_id_ch0    /* synthesis PAP_MARK_DEBUG="true" */,
    output     [15:0] last_packet_id_ch1    /* synthesis PAP_MARK_DEBUG="true" */,
    output     [15:0] last_packet_id_ch2    /* synthesis PAP_MARK_DEBUG="true" */,
    output     [15:0] last_packet_id_ch3    /* synthesis PAP_MARK_DEBUG="true" */,
    output     [15:0] last_packet_total_ch0 /* synthesis PAP_MARK_DEBUG="true" */,
    output     [15:0] last_packet_total_ch1 /* synthesis PAP_MARK_DEBUG="true" */,
    output     [15:0] last_packet_total_ch2 /* synthesis PAP_MARK_DEBUG="true" */,
    output     [15:0] last_packet_total_ch3 /* synthesis PAP_MARK_DEBUG="true" */,
    output     [15:0] last_width_ch0        /* synthesis PAP_MARK_DEBUG="true" */,
    output     [15:0] last_width_ch1        /* synthesis PAP_MARK_DEBUG="true" */,
    output     [15:0] last_width_ch2        /* synthesis PAP_MARK_DEBUG="true" */,
    output     [15:0] last_width_ch3        /* synthesis PAP_MARK_DEBUG="true" */,
    output     [15:0] last_height_ch0       /* synthesis PAP_MARK_DEBUG="true" */,
    output     [15:0] last_height_ch1       /* synthesis PAP_MARK_DEBUG="true" */,
    output     [15:0] last_height_ch2       /* synthesis PAP_MARK_DEBUG="true" */,
    output     [15:0] last_height_ch3       /* synthesis PAP_MARK_DEBUG="true" */,

    output     [7:0]  debug_led             /* synthesis PAP_MARK_DEBUG="true" */,

    // LINK_ATTRIB_DIAG_LITE: export counters already produced by u_mon_ch2.
    output     [31:0] diag_ch2_frame_count,
    output     [31:0] diag_ch2_udp5000_count,
    output     [31:0] diag_ch2_fpgv_count,
    output     [31:0] diag_ch2_er_cycle_count
);

wire frame_pulse_0, frame_pulse_1, frame_pulse_2, frame_pulse_3;
wire udp_pulse_0,   udp_pulse_1,   udp_pulse_2,   udp_pulse_3;
wire fpgv_pulse_0,  fpgv_pulse_1,  fpgv_pulse_2,  fpgv_pulse_3;
wire err_pulse_0,   err_pulse_1,   err_pulse_2,   err_pulse_3;

wire [31:0] frame_count_0, frame_count_1, frame_count_2, frame_count_3;
wire [31:0] udp_count_0,   udp_count_1,   udp_count_2,   udp_count_3;
wire [31:0] fpgv_count_0,  fpgv_count_1,  fpgv_count_2,  fpgv_count_3;
wire [31:0] err_count_0,   err_count_1,   err_count_2,   err_count_3;

wire [31:0] frame_id_0, frame_id_1, frame_id_2, frame_id_3;
wire [7:0]  last_mode_0, last_mode_1, last_mode_2, last_mode_3;
wire [7:0]  mon_led_0, mon_led_1, mon_led_2, mon_led_3;

fpgv_gmii_rx_monitor #(.LOCAL_MAC(LOCAL_MAC), .LOCAL_IP(LOCAL_IP), .UDP_PORT(UDP_PORT)) u_mon_ch0 (
    .clk(clk_ch0), .rst_n(rstn_ch0), .gmii_rxd(rxd_ch0), .gmii_rx_dv(dv_ch0), .gmii_rx_er(er_ch0),
    .gmii_frame_pulse(frame_pulse_0), .ip_udp_pulse(udp_pulse_0), .fpgv_pulse(fpgv_pulse_0), .error_pulse(err_pulse_0),
    .gmii_frame_count(frame_count_0), .udp_packet_count(udp_count_0), .fpgv_packet_count(fpgv_count_0), .error_count(err_count_0),
    .last_frame_id(frame_id_0), .last_packet_id(last_packet_id_ch0), .last_packet_total(last_packet_total_ch0),
    .last_width(last_width_ch0), .last_height(last_height_ch0), .last_mode(last_mode_0), .debug_led(mon_led_0)
);

fpgv_gmii_rx_monitor #(.LOCAL_MAC(LOCAL_MAC), .LOCAL_IP(LOCAL_IP), .UDP_PORT(UDP_PORT)) u_mon_ch1 (
    .clk(clk_ch1), .rst_n(rstn_ch1), .gmii_rxd(rxd_ch1), .gmii_rx_dv(dv_ch1), .gmii_rx_er(er_ch1),
    .gmii_frame_pulse(frame_pulse_1), .ip_udp_pulse(udp_pulse_1), .fpgv_pulse(fpgv_pulse_1), .error_pulse(err_pulse_1),
    .gmii_frame_count(frame_count_1), .udp_packet_count(udp_count_1), .fpgv_packet_count(fpgv_count_1), .error_count(err_count_1),
    .last_frame_id(frame_id_1), .last_packet_id(last_packet_id_ch1), .last_packet_total(last_packet_total_ch1),
    .last_width(last_width_ch1), .last_height(last_height_ch1), .last_mode(last_mode_1), .debug_led(mon_led_1)
);

fpgv_gmii_rx_monitor #(.LOCAL_MAC(LOCAL_MAC), .LOCAL_IP(LOCAL_IP), .UDP_PORT(UDP_PORT)) u_mon_ch2 (
    .clk(clk_ch2), .rst_n(rstn_ch2), .gmii_rxd(rxd_ch2), .gmii_rx_dv(dv_ch2), .gmii_rx_er(er_ch2),
    .gmii_frame_pulse(frame_pulse_2), .ip_udp_pulse(udp_pulse_2), .fpgv_pulse(fpgv_pulse_2), .error_pulse(err_pulse_2),
    .gmii_frame_count(frame_count_2), .udp_packet_count(udp_count_2), .fpgv_packet_count(fpgv_count_2), .error_count(err_count_2),
    .last_frame_id(frame_id_2), .last_packet_id(last_packet_id_ch2), .last_packet_total(last_packet_total_ch2),
    .last_width(last_width_ch2), .last_height(last_height_ch2), .last_mode(last_mode_2), .debug_led(mon_led_2)
);

fpgv_gmii_rx_monitor #(.LOCAL_MAC(LOCAL_MAC), .LOCAL_IP(LOCAL_IP), .UDP_PORT(UDP_PORT)) u_mon_ch3 (
    .clk(clk_ch3), .rst_n(rstn_ch3), .gmii_rxd(rxd_ch3), .gmii_rx_dv(dv_ch3), .gmii_rx_er(er_ch3),
    .gmii_frame_pulse(frame_pulse_3), .ip_udp_pulse(udp_pulse_3), .fpgv_pulse(fpgv_pulse_3), .error_pulse(err_pulse_3),
    .gmii_frame_count(frame_count_3), .udp_packet_count(udp_count_3), .fpgv_packet_count(fpgv_count_3), .error_count(err_count_3),
    .last_frame_id(frame_id_3), .last_packet_id(last_packet_id_ch3), .last_packet_total(last_packet_total_ch3),
    .last_width(last_width_ch3), .last_height(last_height_ch3), .last_mode(last_mode_3), .debug_led(mon_led_3)
);

assign rx_activity_live = {dv_ch3, dv_ch2, dv_ch1, dv_ch0};
assign rx_frame_seen    = {|frame_count_3, |frame_count_2, |frame_count_1, |frame_count_0};
assign udp5000_seen     = {|udp_count_3,   |udp_count_2,   |udp_count_1,   |udp_count_0};
assign fpgv_seen        = {|fpgv_count_3,  |fpgv_count_2,  |fpgv_count_1,  |fpgv_count_0};
assign rx_error_seen    = {|err_count_3,   |err_count_2,   |err_count_1,   |err_count_0};

// LINK_ATTRIB_DIAG_LITE: no additional FPGV parser is instantiated.
assign diag_ch2_frame_count    = frame_count_2;
assign diag_ch2_udp5000_count  = udp_count_2;
assign diag_ch2_fpgv_count     = fpgv_count_2;
assign diag_ch2_er_cycle_count = err_count_2;

always @(*) begin
    if(fpgv_seen[0] | udp5000_seen[0] | rx_frame_seen[0])      active_channel = 2'd0;
    else if(fpgv_seen[1] | udp5000_seen[1] | rx_frame_seen[1]) active_channel = 2'd1;
    else if(fpgv_seen[2] | udp5000_seen[2] | rx_frame_seen[2]) active_channel = 2'd2;
    else if(fpgv_seen[3] | udp5000_seen[3] | rx_frame_seen[3]) active_channel = 2'd3;
    else                                                      active_channel = 2'd0;
end

reg [25:0] hb_cnt;
reg        heartbeat;
always @(posedge free_clk or negedge free_rst_n) begin
    if(!free_rst_n) begin
        hb_cnt    <= 26'd0;
        heartbeat <= 1'b0;
    end else begin
        hb_cnt <= hb_cnt + 26'd1;
        if(hb_cnt == 26'd0)
            heartbeat <= ~heartbeat;
    end
end

assign debug_led[0] = heartbeat;           // free_clk heartbeat
assign debug_led[1] = |rx_frame_seen;      // Ethernet frame seen on any SFP0 QSGMII channel
assign debug_led[2] = |rx_activity_live;   // current GMII RX activity
assign debug_led[3] = udp5000_seen[0];     // ch0 UDP5000 seen
assign debug_led[4] = udp5000_seen[1];     // ch1 UDP5000 seen
assign debug_led[5] = udp5000_seen[2];     // ch2 UDP5000 seen
assign debug_led[6] = udp5000_seen[3];     // ch3 UDP5000 seen
assign debug_led[7] = |rx_error_seen;      // GMII RX error seen

endmodule
