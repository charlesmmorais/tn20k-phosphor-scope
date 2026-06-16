// Testbench de integracao: beam_plotter + scope_engine + framebuffer
//  - desenha um segmento e confere que os pixels acenderam com o brilho certo
//  - confere que o "decay" (apagar) leva o brilho de volta a zero
//  Integration test: draws a segment, checks pixels lit with the right
//  brightness, then checks the decay brings them back to zero.
`timescale 1ns/1ps
`default_nettype none
module tb_scope_engine;
    reg clk=0, rst=1;
    always #5 clk=~clk;

    // plotter <-> engine
    wire [9:0] d_x,d_y; wire [3:0] d_amt; wire d_valid,d_ready;
    // engine <-> framebuffer (porta B)
    wire [16:0] b_addr; wire [3:0] b_din,b_dout; wire b_we;
    wire eng_ready;
    // porta A (leitura de inspecao) / inspection read port
    reg  [16:0] a_addr=0; wire [3:0] a_dout;

    // entradas do plotter / plotter inputs
    reg [9:0] s_x=160, s_y=120; reg s_valid=0;

    integer errors=0;

    framebuffer #(.AW(17),.DW(4),.DEPTH(76800)) fb(
        .clk(clk), .a_addr(a_addr), .a_dout(a_dout),
        .b_addr(b_addr), .b_din(b_din), .b_we(b_we), .b_dout(b_dout));

    scope_engine #(.AW(17),.DW(4),.DEPTH(76800),.W(320)) eng(
        .clk(clk), .rst(rst), .d_x(d_x), .d_y(d_y), .d_amt(d_amt),
        .d_valid(d_valid), .d_ready(d_ready),
        .b_addr(b_addr), .b_din(b_din), .b_we(b_we), .b_dout(b_dout),
        .ready(eng_ready));

    beam_plotter bp(
        .clk(clk), .rst(rst), .s_x(s_x), .s_y(s_y), .s_valid(s_valid),
        .o_x(d_x), .o_y(d_y), .o_amt(d_amt), .o_valid(d_valid), .o_ready(d_ready));

    // le um endereco / read one address  (porta A, 1 ciclo de latencia)
    task read_px; input [16:0] addr; output [3:0] val;
        begin
            a_addr = addr; @(posedge clk); @(posedge clk); val = a_dout;
        end
    endtask

    function [16:0] idx; input [9:0] xx,yy; begin idx = yy*320 + xx; end endfunction

    reg [3:0] v;
    integer i;
    initial begin
        repeat(4) @(posedge clk); rst=0;

        // espera a fase CLEAR terminar / wait for CLEAR to finish
        wait(eng_ready); @(posedge clk);

        // ---- desenha segmento (160,120) -> (164,120) ----
        s_x=164; s_y=120; s_valid=1; @(posedge clk); s_valid=0;

        // deixa o plotter+engine desenharem os 5 pixels / let them draw
        repeat(120) @(posedge clk);

        // ---- confere brilho (segmento curto=4 -> brilho 9) ----
        for(i=160;i<=164;i=i+1) begin
            read_px(idx(i[9:0],10'd120), v);
            if(v !== 4'd9) begin
                $display("FAIL: pixel (%0d,120) brilho=%0d (esperado/expected 9)",i,v);
                errors=errors+1;
            end
        end
        // vizinhos nao desenhados devem estar apagados / neighbours stay dark
        read_px(idx(10'd159,10'd120), v);
        if(v!==4'd0) begin $display("FAIL: pixel 159 nao deveria acender=%0d",v); errors=errors+1; end
        read_px(idx(10'd165,10'd120), v);
        if(v!==4'd0) begin $display("FAIL: pixel 165 nao deveria acender=%0d",v); errors=errors+1; end

        if(errors==0) $display("OK: segmento desenhado com brilho correto / segment drawn correctly");

        // ---- agora deixa o fosforo apagar / let phosphor decay ----
        repeat(1_600_000) @(posedge clk);
        read_px(idx(10'd162,10'd120), v);
        if(v!==4'd0) begin
            $display("FAIL: apos decay pixel ainda=%0d (esperado/expected 0)",v);
            errors=errors+1;
        end else
            $display("OK: decay levou o pixel de volta a 0 / decay returned pixel to 0");

        if(errors==0) $display("PASS tb_scope_engine");
        else          $display("TESTE FALHOU/FAILED: %0d erro(s)",errors);
        $finish;
    end
endmodule
`default_nettype wire
