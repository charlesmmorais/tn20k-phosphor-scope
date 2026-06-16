`timescale 1ns/1ps
`default_nettype none
module tb_tmds_encoder;
    reg clk=0, de=1; reg [1:0] ctrl=0; reg [7:0] din=0;
    wire [9:0] q; integer errors=0;
    tmds_encoder dut(.clk(clk),.de(de),.ctrl(ctrl),.din(din),.q_out(q));
    always #5 clk=~clk;
    function [7:0] tmds_decode; input [9:0] qq;
        reg [7:0] qm; integer i; reg [7:0] d; begin
            qm = qq[9]?~qq[7:0]:qq[7:0];
            d[0]=qm[0];
            for(i=1;i<8;i=i+1) d[i]=qq[8]?(qm[i]^qm[i-1]):~(qm[i]^qm[i-1]);
            tmds_decode=d;
        end
    endfunction
    integer disparity=0, k, ones, count=0, maxabs=0, maxcnt=0, a;
    reg [7:0] din_d;
    always @(posedge clk) din_d<=din;
    task check; begin
        @(negedge clk);
        ones=0; for(k=0;k<10;k=k+1) ones=ones+q[k];
        disparity=disparity+(2*ones-10);
        a = (disparity<0)?-disparity:disparity; if(a>maxabs) maxabs=a;
        a = (dut.cnt<0)?-dut.cnt:dut.cnt;       if(a>maxcnt) maxcnt=a;
        if(tmds_decode(q)!==din_d) begin
            $display("FAIL roundtrip din=%02x dec=%02x q=%b",din_d,tmds_decode(q),q);
            errors=errors+1; end
        count=count+1;
    end endtask
    integer v; reg [15:0] lfsr=16'hACE1;
    initial begin
        de=0; ctrl=0; din=0; repeat(4) @(posedge clk);   // seed cnt=0
        de=1; @(negedge clk); @(negedge clk); disparity=0;
        for(v=0;v<256;v=v+1) begin din=v[7:0]; @(posedge clk); check; end  // varredura
        for(v=0;v<8000;v=v+1) begin                                        // aleatorio
            lfsr = {lfsr[14:0], lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};
            din = lfsr[7:0]; @(posedge clk); check;
        end
        // limites de balanco DC / DC-balance bounds (NAO podem crescer com o stream)
        if(maxabs > 30) begin $display("FAIL: disparidade acumulada=%0d > 30",maxabs); errors=errors+1; end
        if(maxcnt > 16) begin $display("FAIL: cnt interno=%0d > 16",maxcnt); errors=errors+1; end
        de=0;
        ctrl=2'b00; @(posedge clk); @(negedge clk); if(q!==10'b1101010100) begin $display("FAIL tok00"); errors=errors+1; end
        ctrl=2'b01; @(posedge clk); @(negedge clk); if(q!==10'b0010101011) begin $display("FAIL tok01"); errors=errors+1; end
        ctrl=2'b10; @(posedge clk); @(negedge clk); if(q!==10'b0101010100) begin $display("FAIL tok10"); errors=errors+1; end
        ctrl=2'b11; @(posedge clk); @(negedge clk); if(q!==10'b1010101011) begin $display("FAIL tok11"); errors=errors+1; end
        if(errors==0) $display("PASS tb_tmds_encoder (%0d simbolos, max|disp|=%0d, max|cnt|=%0d)",count,maxabs,maxcnt);
        else $display("FAILED: %0d erro(s)",errors);
        $finish;
    end
endmodule
`default_nettype wire
