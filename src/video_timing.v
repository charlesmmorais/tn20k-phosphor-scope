`timescale 1ns/1ps
// video_timing.v - Gerador de sincronismo 640x480@60 / 640x480@60 sync generator
// Todas as saidas registradas no MESMO estagio (alinhadas) / all outputs aligned.
`default_nettype none
module video_timing #(
    parameter H_ACT=640, parameter H_FP=16, parameter H_SY=96, parameter H_BP=48,
    parameter V_ACT=480, parameter V_FP=10, parameter V_SY=2,  parameter V_BP=33
)(
    input  wire       clk, input wire rst,
    output reg [9:0]  x, output reg [9:0] y,
    output reg        active, output reg hsync, output reg vsync,
    output reg        frame_start
);
    localparam H_TOTAL=H_ACT+H_FP+H_SY+H_BP; // 800
    localparam V_TOTAL=V_ACT+V_FP+V_SY+V_BP; // 525
    reg [9:0] hcnt, vcnt;
    always @(posedge clk) begin
        if (rst) begin hcnt<=0; vcnt<=0; end
        else if (hcnt==H_TOTAL-1) begin
            hcnt<=0; vcnt<=(vcnt==V_TOTAL-1)?10'd0:vcnt+1'b1;
        end else hcnt<=hcnt+1'b1;
    end
    wire h_active=(hcnt<H_ACT);
    wire v_active=(vcnt<V_ACT);
    always @(posedge clk) begin
        x<=h_active?hcnt:10'd0;
        y<=v_active?vcnt:10'd0;
        active<=h_active & v_active;
        hsync<=~((hcnt>=H_ACT+H_FP)&&(hcnt<H_ACT+H_FP+H_SY));
        vsync<=~((vcnt>=V_ACT+V_FP)&&(vcnt<V_ACT+V_FP+V_SY));
        frame_start<=(hcnt==0)&&(vcnt==0);
    end
endmodule
`default_nettype wire
