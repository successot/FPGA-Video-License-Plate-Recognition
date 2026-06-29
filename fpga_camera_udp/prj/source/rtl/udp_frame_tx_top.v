

module udp_frame_tx_top #(
    parameter BOARD_MAC = 48'h02_00_00_00_00_22,
    parameter BOARD_IP  = {8'd192,8'd168,8'd1,8'd10},
    parameter DES_MAC   = 48'hff_ff_ff_ff_ff_ff,
    parameter DES_IP    = {8'd192,8'd168,8'd1,8'd100},
    parameter WIDTH     = 16'd640,
    parameter HEIGHT    = 16'd480,
    parameter SEND_FRAME_INTERVAL = 16'd30
)(
    input             rst_n,
    input             cam_pclk,
    input             img_vsync,
    input             img_valid,
    input      [15:0] img_data,
    input      [2:0]  mode,
    input             eth_rxc,
    input             eth_rx_ctl,
    input      [3:0]  eth_rxd,
    output            eth_txc,
    output            eth_tx_ctl,
    output     [3:0]  eth_txd,
    output            eth_rst_n,
    output            transfer_flag,
    output     [2:0]  manual_mode
);
    wire gmii_tx_clk;
    wire udp_tx_start_en;
    wire [31:0] udp_tx_data;
    wire [15:0] udp_tx_byte_num;
    wire udp_tx_done;
    wire tx_req;
    wire gmii_rx_clk;
    wire rec_pkt_done;
    wire rec_en;
    wire [31:0] rec_data;
    wire [15:0] rec_byte_num;

    eth_frame_packetizer #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT),
        .PAYLOAD_BYTES(16'd1024),
        .SEND_FRAME_INTERVAL(SEND_FRAME_INTERVAL)
    ) u_packetizer (
        .rst_n(rst_n),
        .cam_pclk(cam_pclk),
        .img_vsync(img_vsync),
        .img_valid(img_valid),
        .img_data(img_data),
        .mode(mode),
        .transfer_flag(transfer_flag),
        .eth_tx_clk(gmii_tx_clk),
        .udp_tx_req(tx_req),
        .udp_tx_done(udp_tx_done),
        .udp_tx_start_en(udp_tx_start_en),
        .udp_tx_data(udp_tx_data),
        .udp_tx_byte_num(udp_tx_byte_num)
    );

    eth_top #(
        .BOARD_MAC(BOARD_MAC),
        .BOARD_IP (BOARD_IP),
        .DES_MAC  (DES_MAC),
        .DES_IP   (DES_IP)
    ) u_eth_top (
        .sys_rst_n(rst_n),
        .eth_rxc(eth_rxc),
        .eth_rx_ctl(eth_rx_ctl),
        .eth_rxd(eth_rxd),
        .eth_txc(eth_txc),
        .eth_tx_ctl(eth_tx_ctl),
        .eth_txd(eth_txd),
        .eth_rst_n(eth_rst_n),
        .gmii_tx_clk(gmii_tx_clk),
        .udp_tx_start_en(udp_tx_start_en),
        .tx_data(udp_tx_data),
        .tx_byte_num(udp_tx_byte_num),
        .udp_tx_done(udp_tx_done),
        .tx_req(tx_req),
        .gmii_rx_clk(gmii_rx_clk),
        .rec_pkt_done(rec_pkt_done),
        .rec_en(rec_en),
        .rec_data(rec_data),
        .rec_byte_num(rec_byte_num)
    );

    udp_cmd_rx u_cmd (
        .clk(gmii_rx_clk),
        .rst_n(rst_n),
        .rec_pkt_done(rec_pkt_done),
        .rec_en(rec_en),
        .rec_data(rec_data),
        .rec_byte_num(rec_byte_num),
        .transfer_flag(transfer_flag),
        .manual_mode(manual_mode)
    );
endmodule
