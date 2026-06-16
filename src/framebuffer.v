`timescale 1ns/1ps
// ============================================================================
//  framebuffer.v  -  Memoria de imagem em BSRAM / on-chip BSRAM framebuffer
// ----------------------------------------------------------------------------
//  320 x 240 pixels, 4 bits de INTENSIDADE por pixel (16 niveis de brilho).
//  Total = 76800 x 4 bits = 307.200 bits, que cabem folgados na BSRAM do
//  GW2AR-18 (~828 kbit). NAO usamos a SDRAM externa: tudo dentro do FPGA,
//  o que torna o projeto simples de sintetizar e 100% simulavel.
//
//  320 x 240 pixels, 4-bit INTENSITY each (16 brightness levels).
//  Total = 76800 x 4 = 307,200 bits, fitting comfortably in the GW2AR-18
//  BSRAM (~828 kbit). No external SDRAM is used: everything lives inside the
//  FPGA, which keeps the design easy to synthesize and fully simulable.
//
//  Memoria VERDADEIRAMENTE DUAL-PORT / TRUE dual-port memory:
//    Porta A: leitura para o video (so le)        / video read (read-only)
//    Porta B: leitura-modificacao-escrita (engine) / read-modify-write (engine)
//  Ambas as portas tem 1 ciclo de latencia de leitura (BSRAM sincrona).
//  Both ports have 1 read-latency cycle (synchronous BSRAM).
// ============================================================================
`default_nettype none

module framebuffer #(
    parameter AW = 17,           // bits de endereco / address bits (2^17 > 76800)
    parameter DW = 4,            // bits por pixel / bits per pixel
    parameter DEPTH = 76800      // 320*240
)(
    input  wire           clk,
    // Porta A - leitura de video / Port A - video read
    input  wire [AW-1:0]  a_addr,
    output reg  [DW-1:0]  a_dout,
    // Porta B - leitura/escrita do engine / Port B - engine read/write
    input  wire [AW-1:0]  b_addr,
    input  wire [DW-1:0]  b_din,
    input  wire           b_we,
    output reg  [DW-1:0]  b_dout
);
    (* ram_style = "block" *)
    reg [DW-1:0] mem [0:DEPTH-1];

`ifdef SIM
    integer i;
    initial begin
        a_dout = 0; b_dout = 0;
        for (i=0;i<DEPTH;i=i+1) mem[i]=0;  // tela limpa na simulacao / clear in sim
    end
`endif

    // Porta A: leitura sincrona / Port A: synchronous read
    always @(posedge clk)
        a_dout <= mem[a_addr];

    // Porta B: escreve e tambem le (read-first) / Port B: write + read-first
    always @(posedge clk) begin
        if (b_we) mem[b_addr] <= b_din;
        b_dout <= mem[b_addr];
    end
endmodule
`default_nettype wire
