`timescale 1ns/1ps
// ============================================================================
//  scope_engine.v  -  Motor do fosforo / Phosphor engine
// ----------------------------------------------------------------------------
//  Este modulo e dono da Porta B do framebuffer e faz DUAS coisas que, juntas,
//  criam o efeito de tela de osciloscopio:
//
//   1) DESENHAR (draw): quando o tracador (beam_plotter) entrega um pixel,
//      somamos brilho naquele endereco (acende o fosforo).
//   2) APAGAR (decay): continuamente varremos TODA a memoria subtraindo 1 do
//      brilho de cada pixel. E o "fosforo esfriando" -> o rastro vai sumindo
//      suavemente, deixando aquele clarao caracteristico.
//
//  This module owns the framebuffer Port B and does TWO things that together
//  create the oscilloscope-screen effect:
//   1) DRAW: when beam_plotter hands a pixel, we ADD brightness there.
//   2) DECAY: we continuously sweep the WHOLE memory subtracting 1 from every
//      pixel's brightness. That is the "phosphor cooling down" -> the trace
//      fades smoothly, giving the characteristic afterglow.
//
//  Cada operacao e uma leitura-modificacao-escrita (RMW) de 2 ciclos por causa
//  da latencia de 1 ciclo da BSRAM. O DESENHO tem prioridade sobre o APAGAR.
//  Each op is a 2-cycle read-modify-write (BSRAM has 1-cycle latency).
//  DRAW has priority over DECAY.
//
//  Ao ligar, uma fase CLEAR zera toda a memoria (tela preta garantida).
//  On power-up a CLEAR phase zeroes the whole memory (guaranteed black screen).
// ============================================================================
`default_nettype none

module scope_engine #(
    parameter AW = 17,
    parameter DW = 4,
    parameter DEPTH = 76800,
    parameter W = 320            // largura do framebuffer / framebuffer width
)(
    input  wire           clk,
    input  wire           rst,
    // entrada de pixels do tracador / pixel input from plotter
    input  wire [9:0]     d_x,
    input  wire [9:0]     d_y,
    input  wire [3:0]     d_amt,
    input  wire           d_valid,
    output reg            d_ready,
    // interface com o framebuffer (porta B) / framebuffer port B
    output reg  [AW-1:0]  b_addr,
    output reg  [DW-1:0]  b_din,
    output reg            b_we,
    input  wire [DW-1:0]  b_dout,
    output wire           ready    // 1 quando a fase CLEAR terminou / CLEAR done
);
    localparam CLEAR=2'd0, READ=2'd1, WRITE=2'd2;
    reg [1:0] state;

    reg [AW-1:0] sweep;    // varredura do apagar / decay sweep pointer
    reg [AW-1:0] clr;      // ponteiro de limpeza / clear pointer
    reg [AW-1:0] taddr;    // endereco da operacao corrente / current op address
    reg          op_draw;  // 1=desenhar, 0=apagar / 1=draw, 0=decay
    reg [3:0]    amt_l;    // brilho a somar / brightness to add

    assign ready = (state != CLEAR);

    // indice no framebuffer = y*320 + x  =  (y<<8)+(y<<6)+x  (sem multiplicador)
    // framebuffer index without a multiplier
    function [AW-1:0] fb_index;
        input [9:0] xx, yy;
        begin fb_index = ({7'd0,yy} << 8) + ({7'd0,yy} << 6) + {7'd0,xx}; end
    endfunction

    wire        do_draw   = (state==READ) && d_valid;
    wire [AW-1:0] draw_idx = fb_index(d_x, d_y);
    wire [AW-1:0] sel_addr = do_draw ? draw_idx : sweep;

    // soma saturada / saturating add
    wire [4:0] sum = {1'b0, b_dout} + {1'b0, amt_l};
    wire [3:0] draw_new  = sum[4] ? 4'd15 : sum[3:0];
    wire [3:0] decay_new = (b_dout == 4'd0) ? 4'd0 : (b_dout - 4'd1);

    always @(posedge clk) begin
        if (rst) begin
            state<=CLEAR; sweep<=0; clr<=0; taddr<=0; op_draw<=0; amt_l<=0;
            b_addr<=0; b_din<=0; b_we<=0; d_ready<=0;
        end else begin
            case (state)
            // --------- limpeza inicial / initial clear ---------
            CLEAR: begin
                d_ready <= 1'b0;
                b_addr  <= clr;
                b_din   <= 4'd0;
                b_we    <= 1'b1;
                if (clr == DEPTH-1) begin clr <= 0; state <= READ; end
                else                clr <= clr + 1'b1;
            end
            // --------- fase de leitura do RMW / RMW read phase ---------
            READ: begin
                b_we    <= 1'b0;
                b_addr  <= sel_addr;
                taddr   <= sel_addr;
                op_draw <= do_draw;
                amt_l   <= d_amt;
                d_ready <= do_draw;       // consome 1 pixel do tracador / accept pixel
                state   <= WRITE;
            end
            // --------- fase de escrita do RMW / RMW write phase ---------
            WRITE: begin
                d_ready <= 1'b0;
                b_addr  <= taddr;
                b_we    <= 1'b1;
                b_din   <= op_draw ? draw_new : decay_new;
                if (!op_draw)
                    sweep <= (sweep == DEPTH-1) ? {AW{1'b0}} : (sweep + 1'b1);
                state   <= READ;
            end
            default: state <= CLEAR;
            endcase
        end
    end
endmodule
`default_nettype wire
