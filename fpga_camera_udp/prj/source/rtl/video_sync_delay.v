

module video_sync_delay #(
    parameter DATA_WIDTH = 16,
    parameter DELAY = 1
)(
    input                      clk,
    input                      rst_n,
    input                      in_valid,
    input                      in_href,
    input                      in_vsync,
    input      [DATA_WIDTH-1:0] in_data,
    output                     out_valid,
    output                     out_href,
    output                     out_vsync,
    output     [DATA_WIDTH-1:0] out_data
);
    reg [DELAY-1:0] valid_d;
    reg [DELAY-1:0] href_d;
    reg [DELAY-1:0] vsync_d;
    reg [DATA_WIDTH*DELAY-1:0] data_d;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            valid_d <= {DELAY{1'b0}};
            href_d  <= {DELAY{1'b0}};
            vsync_d <= {DELAY{1'b0}};
            data_d  <= {(DATA_WIDTH*DELAY){1'b0}};
        end else begin
            valid_d[0] <= in_valid;
            href_d[0]  <= in_href;
            vsync_d[0] <= in_vsync;
            data_d[DATA_WIDTH-1:0] <= in_data;
            for(i=1; i<DELAY; i=i+1) begin
                valid_d[i] <= valid_d[i-1];
                href_d[i]  <= href_d[i-1];
                vsync_d[i] <= vsync_d[i-1];
                data_d[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] <= data_d[i*DATA_WIDTH-1 -: DATA_WIDTH];
            end
        end
    end

    assign out_valid = valid_d[DELAY-1];
    assign out_href  = href_d[DELAY-1];
    assign out_vsync = vsync_d[DELAY-1];
    assign out_data  = data_d[DATA_WIDTH*DELAY-1 -: DATA_WIDTH];
endmodule
