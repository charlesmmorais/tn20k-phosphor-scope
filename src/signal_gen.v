`timescale 1ns/1ps
// ============================================================================
//  signal_gen.v  -  Gerador de sinais por DDS / DDS signal generator
// ----------------------------------------------------------------------------
//  Produz pontos (x,y) no espaco do framebuffer (320x240) que o feixe percorre.
//  Gerador de funcoes interno: nenhuma fonte externa e necessaria.
//  Internal function generator: no external source needed.
//
//  DDS: acumulador de fase de 16 bits gira a "STEP*razao"; os 8 bits altos
//  enderecam a tabela de seno. A razao X:Y define a figura de Lissajous (modo
//  XY). Um deslocamento de fase LENTO (morph) gira/abre a figura devagar.
//
//  Modo YT (tempo): o eixo X e uma varredura (sweep) e o Y segue a onda. Para a
//  onda ficar PARADA na tela usamos DISPARO (trigger): ao reiniciar a varredura
//  reiniciamos tambem a fase da onda (yt_ph<=0). Sem isso, varreduras sucessivas
//  se sobreporiam e a tela viraria uma malha borrada (osciloscopio sem trigger).
//  YT mode uses TRIGGERING: restarting the sweep also restarts the wave phase,
//  giving a stable trace (an untriggered scope would show an overlapping mesh).
// ============================================================================
`default_nettype none
module signal_gen #(
    parameter SAMPLE_DIV = 16,   // 1 amostra a cada N clocks / 1 sample / N clocks
    parameter STEP       = 96,   // velocidade base de fase / base phase speed
    parameter SLOW_BITS  = 13,   // prescaler do morph / morph prescaler
    parameter YT_STEP    = 819   // fase da onda YT por amostra (~2 periodos/tela)
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [2:0]  pattern,
    output reg  [9:0]  px,
    output reg  [9:0]  py,
    output reg         sample_valid
);
    reg [7:0] divcnt;
    wire tick = (divcnt == SAMPLE_DIV-1);
    always @(posedge clk)
        if (rst) divcnt <= 0; else divcnt <= tick ? 8'd0 : divcnt + 1'b1;

    // ---- decodificacao do pattern / pattern decode (assign = sempre valido) ----
    wire [1:0] mode    = (pattern==3'd6 || pattern==3'd7) ? 2'd1 : 2'd0; // 1=YT
    wire [3:0] rx      = (pattern==3'd3) ? 4'd2 :
                         (pattern==3'd4 || pattern==3'd5) ? 4'd3 : 4'd1;
    wire [3:0] ry      = (pattern==3'd1) ? 4'd2 :
                         (pattern==3'd2 || pattern==3'd3) ? 4'd3 :
                         (pattern==3'd4) ? 4'd4 :
                         (pattern==3'd5) ? 4'd5 : 4'd1;
    wire       wav_tri = (pattern==3'd7);                 // YT triangular
    wire       do_morph= (pattern<=3'd5);                 // Lissajous gira devagar

    // ---- acumuladores / accumulators ----
    reg [15:0] ph_x, ph_y, yt_ph;
    reg [SLOW_BITS-1:0] slow_cnt;
    reg [7:0]  morph;
    reg [9:0]  sweep;
    wire slow_tick = (slow_cnt == {SLOW_BITS{1'b1}});
    wire sweep_end = (sweep >= 10'd319);

    always @(posedge clk) begin
        if (rst) begin
            ph_x<=0; ph_y<=0; yt_ph<=0; slow_cnt<=0; morph<=0; sweep<=0;
        end else if (tick) begin
            ph_x <= ph_x + (STEP * rx);
            ph_y <= ph_y + (STEP * ry);
            slow_cnt <= slow_cnt + 1'b1;
            if (slow_tick && do_morph) morph <= morph + 8'd1;
            // varredura + disparo da onda YT / sweep + YT wave trigger
            if (sweep_end) begin sweep <= 10'd0; yt_ph <= 16'd0; end
            else           begin sweep <= sweep + 10'd2; yt_ph <= yt_ph + YT_STEP; end
        end
    end

    wire [7:0] addr_x = ph_x[15:8] + (do_morph ? morph : 8'd0);
    // Y: Lissajous usa ph_y ; YT usa yt_ph (disparado) / YT uses triggered phase
    wire [7:0] addr_y = (mode==2'd1) ? yt_ph[15:8] : ph_y[15:8];
    wire signed [7:0] sin_x, sin_y;
    sine_lut u_sx (.clk(clk), .phase(addr_x), .value(sin_x));
    sine_lut u_sy (.clk(clk), .phase(addr_y), .value(sin_y));

    // onda triangular YT a partir de yt_ph / YT triangle from yt_ph
    wire [7:0] tri_u = yt_ph[15] ? (8'd255 - yt_ph[15:8]) : yt_ph[15:8];
    wire signed [8:0] tri_s = $signed({1'b0,tri_u}) * 9'sd2 - 9'sd128;

    // pipeline p/ casar com latencia de 1 ciclo da LUT / match LUT latency
    reg tick_d1,tick_d2; reg [1:0] mode_d1,mode_d2; reg wtri_d1,wtri_d2;
    reg [9:0] sweep_d1,sweep_d2;
    always @(posedge clk) begin
        tick_d1<=tick;   tick_d2<=tick_d1;
        mode_d1<=mode;   mode_d2<=mode_d1;
        wtri_d1<=wav_tri;wtri_d2<=wtri_d1;
        sweep_d1<=sweep; sweep_d2<=sweep_d1;
    end

    reg signed [11:0] nx, ny;
    always @(*) begin
        if (mode_d2 == 2'd1) begin          // YT
            nx = {2'b0, sweep_d2};
            ny = wtri_d2 ? (12'sd120 + (tri_s - (tri_s >>>3)))
                         : (12'sd120 + (sin_y - (sin_y >>>3)));
        end else begin                       // Lissajous
            nx = 12'sd160 + sin_x;
            ny = 12'sd120 + (sin_y - (sin_y >>> 3));
        end
    end

    function [9:0] clamp; input signed [11:0] v; input [9:0] hi; begin
        if (v < 0) clamp = 10'd0; else if (v > hi) clamp = hi; else clamp = v[9:0];
    end endfunction

    always @(posedge clk) begin
        sample_valid <= tick_d2;
        if (tick_d2) begin
            px <= clamp(nx, 10'd319);
            py <= clamp(ny, 10'd239);
        end
    end
endmodule
`default_nettype wire
