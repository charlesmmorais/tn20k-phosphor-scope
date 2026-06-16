`timescale 1ns/1ps
// ============================================================================
//  colorizer.v  -  Da cor ao pixel / Pixel colouriser
// ----------------------------------------------------------------------------
//  Converte a INTENSIDADE (0..15) guardada no framebuffer em uma cor RGB de
//  fosforo verde estilo P31, e desenha por baixo a GRADE (graticula) do
//  osciloscopio. Tudo combinacional.
//
//  Converts the framebuffer INTENSITY (0..15) into a P31-style green phosphor
//  RGB colour, and draws the oscilloscope GRATICULE underneath. Purely
//  combinational.
//
//  Truque do brilho / brightness trick: nos niveis mais altos somamos um pouco
//  de vermelho e azul para o pico do rastro parecer "branco quente", como num
//  CRT real. At the highest levels we add some red/blue so the peak looks
//  "white-hot", like a real CRT.
// ============================================================================
`default_nettype none

module colorizer (
    input  wire [3:0] intensity,   // brilho do fosforo / phosphor brightness
    input  wire [9:0] x,           // 0..639
    input  wire [9:0] y,           // 0..479
    input  wire       active,      // dentro da area visivel / inside visible area
    output reg  [7:0] r,
    output reg  [7:0] g,
    output reg  [7:0] b
);
    // ---- Cor do fosforo a partir da intensidade / phosphor colour ----
    wire [7:0] g_ph = {intensity, intensity};                 // 0..255 (verde principal)
    wire [7:0] r_ph = (intensity <= 4'd9)  ? 8'd0 :
                      ({4'd0,(intensity-4'd9)} * 8'd28);       // vermelho so no topo
    wire [7:0] b_ph = (intensity <= 4'd12) ? 8'd0 :
                      ({4'd0,(intensity-4'd12)} * 8'd24);      // azul so no pico

    // ---- Graticula / graticule ----
    wire v_line  = (x[5:0] == 6'd0);                 // linhas verticais a cada 64 px
    wire h_line  = (y[5:0] == 6'd0);                 // linhas horizontais a cada 64 px
    wire x_axis  = (y == 10'd240);                   // eixo horizontal central
    wire y_axis  = (x == 10'd320);                   // eixo vertical central
    wire border  = (x < 10'd2) || (x > 10'd637) ||
                   (y < 10'd2) || (y > 10'd477);
    wire axis    = x_axis | y_axis | border;
    wire grid    = v_line  | h_line;

    wire [7:0] grid_g = axis ? 8'd70 : (grid ? 8'd34 : 8'd0); // verde escuro da grade

    always @(*) begin
        if (!active) begin
            r = 8'd0; g = 8'd0; b = 8'd0;
        end else if (intensity != 4'd0) begin
            // O rastro vence a grade (usamos o maior verde) / trace beats grid
            r = r_ph;
            g = (g_ph > grid_g) ? g_ph : grid_g;
            b = b_ph;
        end else begin
            // sem rastro: mostra a grade / no trace: show graticule
            r = 8'd0;
            g = grid_g;
            b = 8'd0;
        end
    end
endmodule
`default_nettype wire
