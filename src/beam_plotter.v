`timescale 1ns/1ps
// beam_plotter.v - Tracador do feixe (Bresenham + brilho ~ velocidade)
// Electron-beam plotter: Bresenham line + brightness ~ dwell time (1/speed).
//
// Saidas COMBINACIONAIS (o_x,o_y,o_amt,o_valid) refletem o pixel atual (cx,cy)
// e so avancam quando o consumidor aceita (o_valid && o_ready). Isso evita o
// atraso de 1 ciclo que duplicaria/perderia pixels (handshake valid/ready).
// COMBINATIONAL outputs reflect the current pixel and advance only on accept;
// this avoids a 1-cycle skew that would duplicate/drop pixels.
`default_nettype none
module beam_plotter #(parameter MAX_SEG=48)(
    input  wire clk, input wire rst,
    input  wire [9:0] s_x, input wire [9:0] s_y, input wire s_valid,
    output wire [9:0] o_x, output wire [9:0] o_y, output wire [3:0] o_amt,
    output wire o_valid, input wire o_ready
);
    localparam IDLE=2'd0, SETUP=2'd1, DRAW=2'd2;
    reg [1:0] state;
    reg signed [11:0] cx,cy, cur_x,cur_y, tx,ty, adx,ady, err;
    reg signed [1:0] sx,sy;
    reg [11:0] nleft;
    reg [3:0] amt;
    reg pend; reg [9:0] pend_x,pend_y;

    function [3:0] bright; input [11:0] s; begin
        if (s<=1) bright=4'd15; else if (s<=2) bright=4'd12;
        else if (s<=4) bright=4'd9; else if (s<=8) bright=4'd6;
        else if (s<=16) bright=4'd4; else bright=4'd2; end
    endfunction
    function signed [11:0] absdiff; input signed [11:0] a,b;
        begin absdiff=(a>b)?(a-b):(b-a); end
    endfunction
    wire signed [11:0] e2 = err<<<1;

    // saidas combinacionais / combinational outputs
    assign o_x     = cx[9:0];
    assign o_y     = cy[9:0];
    assign o_amt   = amt;
    assign o_valid = (state==DRAW);

    always @(posedge clk) begin
        if (rst) begin
            state<=IDLE; pend<=1'b0; pend_x<=10'd160; pend_y<=10'd120;
            cur_x<=12'sd160; cur_y<=12'sd120; cx<=12'sd160; cy<=12'sd120;
            adx<=0; ady<=0; err<=0; sx<=2'sd1; sy<=2'sd1; nleft<=0; amt<=0;
        end else begin
            if (s_valid) begin pend<=1'b1; pend_x<=s_x; pend_y<=s_y; end
            case (state)
            IDLE: begin
                if (pend) begin
                    pend<=1'b0;
                    tx<=$signed({2'b00,pend_x}); ty<=$signed({2'b00,pend_y});
                    adx<=absdiff($signed({2'b00,pend_x}),cur_x);
                    ady<=absdiff($signed({2'b00,pend_y}),cur_y);
                    sx<=($signed({2'b00,pend_x})>cur_x)?2'sd1:-2'sd1;
                    sy<=($signed({2'b00,pend_y})>cur_y)?2'sd1:-2'sd1;
                    err<=absdiff($signed({2'b00,pend_x}),cur_x)
                        -absdiff($signed({2'b00,pend_y}),cur_y);
                    cx<=cur_x; cy<=cur_y; state<=SETUP;
                end
            end
            SETUP: begin
                nleft<=(adx>ady)?adx:ady;
                amt<=bright((adx>ady)?adx:ady);
                if (((adx>ady)?adx:ady)>MAX_SEG) begin
                    cur_x<=tx; cur_y<=ty; state<=IDLE;   // retracao / retrace
                end else state<=DRAW;
            end
            DRAW: begin
                if (o_ready) begin   // consumidor aceitou o pixel atual / accepted
                    if (nleft==0) begin
                        cur_x<=tx; cur_y<=ty; state<=IDLE;
                    end else begin
                        if ((e2>-ady)&&(e2<adx)) begin err<=err-ady+adx; cx<=cx+sx; cy<=cy+sy; end
                        else if (e2>-ady) begin err<=err-ady; cx<=cx+sx; end
                        else if (e2<adx)  begin err<=err+adx; cy<=cy+sy; end
                        nleft<=nleft-1'b1;
                    end
                end
            end
            default: state<=IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
