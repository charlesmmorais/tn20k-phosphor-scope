// Smoke test do topo: elabora tudo junto e confere que o pipeline de video
// roda sem 'X' e que os sincronismos alternam. (PLL/serializador = stubs SIM)
`timescale 1ns/1ps
`default_nettype none
module tb_top_smoke;
    reg clk27=0; reg [1:0] btn_n=2'b11;
    wire [5:0] led; wire tmds_clk_p,tmds_clk_n; wire [2:0] tmds_d_p,tmds_d_n;
    top dut(.clk27(clk27),.btn_n(btn_n),.led(led),
            .tmds_clk_p(tmds_clk_p),.tmds_clk_n(tmds_clk_n),
            .tmds_d_p(tmds_d_p),.tmds_d_n(tmds_d_n));
    always #18 clk27=~clk27;   // ~27 MHz

    integer errors=0, n=0, hs0=0,hs1=0,vs0=0,vs1=0, xcheck=0, drew=0;
    // observa no dominio de pixel / observe in pixel domain
    always @(posedge dut.clk_pix) begin
        if (!dut.rst) begin n=n+1;
            if (dut.hsync) hs1=hs1+1; else hs0=hs0+1;
            if (dut.vsync) vs1=vs1+1; else vs0=vs0+1;
            // dentro da area ativa, as saidas TMDS nao podem ser X
            if (dut.active_d1 && n>500) begin
                xcheck=xcheck+1;
                if (^{tmds_d_p,tmds_clk_p} === 1'bx) begin
                    if(errors<3) $display("FAIL: TMDS em X durante area ativa");
                    errors=errors+1;
                end
            end
            if (dut.a_dout != 0) drew=drew+1; // algum pixel de fosforo aceso
            if (^led === 1'bx) begin $display("FAIL: led em X"); errors=errors+1; end
        end
    end

    initial begin
        // ~0.6 quadro de pixels / ~0.6 frame of pixels
        repeat(1800) @(posedge dut.clk_pix);
        if (hs0==0 || hs1==0) begin $display("FAIL: hsync nao alterna (%0d/%0d)",hs0,hs1); errors=errors+1; end
        if (vs0+vs1 < 100) begin $display("FAIL vsync"); errors=errors+1; end
        if (xcheck < 500)     begin $display("FAIL: poucas amostras ativas=%0d",xcheck); errors=errors+1; end
        $display("info: hsync(%0d/%0d) vsync(%0d/%0d) ativos=%0d pixels_fosforo=%0d",hs0,hs1,vs0,vs1,xcheck,drew);
        if (errors==0) $display("PASS tb_top_smoke");
        else $display("FAILED: %0d erro(s)",errors);
        $finish;
    end
endmodule
`default_nettype wire
