`timescale 1ns/1ps
// ============================================================================
//  control.v  -  Controle de demonstracao / Demo control
// ----------------------------------------------------------------------------
//  Escolhe qual figura (pattern 0..7) e mostrada. Funciona de forma autonoma:
//  troca de figura sozinho a cada ~6 s (modo auto). Os dois botoes da placa
//  permitem interagir:
//     BTN0 : proxima figura agora / next figure now
//     BTN1 : liga/desliga a troca automatica / toggle auto-cycling
//  Botoes sao ativos em nivel BAIXO e passam por um anti-repique (debounce).
//
//  Picks which figure (pattern 0..7) is shown. It runs autonomously, changing
//  figure every ~6 s (auto mode). The two on-board buttons let you interact:
//     BTN0 : next figure now
//     BTN1 : toggle auto-cycling
//  Buttons are active-LOW and are debounced.
// ============================================================================
`default_nettype none

module control #(
    parameter CLK_HZ      = 25_200_000,
    parameter PERIOD_S    = 6
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [1:0] btn_n,     // ativo-baixo / active-low  {btn1,btn0}
    output reg  [2:0] pattern,
    output reg        auto_en
);
    // ---- Anti-repique simples / simple debounce (~10 ms) ----
    localparam DB_MAX = CLK_HZ/100;     // 10 ms
    reg [1:0]  btn_s;                   // nivel estavel (ativo-alto) / stable, active-high
    reg [1:0]  btn_p;                   // valor anterior / previous
    reg [17:0] db_cnt [0:1];
    reg [1:0]  raw;

    integer k;
    always @(posedge clk) begin
        raw <= ~btn_n;                  // converte p/ ativo-alto / to active-high
        for (k=0;k<2;k=k+1) begin
            if (raw[k] != btn_s[k]) begin
                if (db_cnt[k] >= DB_MAX[17:0]) begin
                    btn_s[k]  <= raw[k];
                    db_cnt[k] <= 0;
                end else db_cnt[k] <= db_cnt[k] + 1'b1;
            end else db_cnt[k] <= 0;
        end
        btn_p <= btn_s;
    end
    wire press0 = btn_s[0] & ~btn_p[0]; // borda de subida / rising edge
    wire press1 = btn_s[1] & ~btn_p[1];

    // ---- Temporizador da troca automatica / auto-cycle timer ----
    localparam [31:0] PERIOD_CYC = CLK_HZ * PERIOD_S;
    reg [31:0] timer;

    always @(posedge clk) begin
        if (rst) begin
            pattern <= 3'd0; auto_en <= 1'b1; timer <= 0;
        end else begin
            if (press1) auto_en <= ~auto_en;     // liga/desliga auto

            if (press0) begin                    // proxima figura manual
                pattern <= pattern + 3'd1;
                timer   <= 0;
            end else if (auto_en && timer >= PERIOD_CYC) begin
                pattern <= pattern + 3'd1;        // proxima figura automatica
                timer   <= 0;
            end else begin
                timer <= timer + 1'b1;
            end
        end
    end
endmodule
`default_nettype wire
