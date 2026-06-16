`timescale 1ns/1ps
`default_nettype none
module tb_signal_gen;
    reg clk=0, rst=1; reg [2:0] pattern=0;
    wire [9:0] px,py; wire sv;
    integer errors=0, nsamp=0;
    signal_gen dut(.clk(clk),.rst(rst),.pattern(pattern),.px(px),.py(py),.sample_valid(sv));
    always #5 clk=~clk;
    integer p,n,minx,maxx,miny,maxy,ix,iy;
    initial begin
        repeat(4) @(posedge clk); rst=0;
        repeat(2000) @(posedge clk);
        for(p=0;p<8;p=p+1) begin
            pattern=p[2:0];
            repeat(500) @(posedge clk);
            minx=99999; maxx=-1; miny=99999; maxy=-1; n=0;
            repeat(40000) begin
                @(posedge clk);
                if(sv) begin
                    ix=px; iy=py; nsamp=nsamp+1; n=n+1;
                    if(ix>319) begin $display("FAIL p%0d px=%0d>319",p,ix); errors=errors+1; end
                    if(iy>239) begin $display("FAIL p%0d py=%0d>239",p,iy); errors=errors+1; end
                    if(ix<minx) minx=ix; if(ix>maxx) maxx=ix;
                    if(iy<miny) miny=iy; if(iy>maxy) maxy=iy;
                end
            end
            $display("  pattern %0d: n=%0d x[%0d..%0d] dx=%0d y[%0d..%0d] dy=%0d",p,n,minx,maxx,maxx-minx,miny,maxy,maxy-miny);
            if(n<100) begin $display("FAIL p%0d n=%0d",p,n); errors=errors+1; end
            if((maxx-minx)<20 && (maxy-miny)<20) begin $display("FAIL p%0d no variation",p); errors=errors+1; end
        end
        if(errors==0) $display("PASS tb_signal_gen (%0d samples)",nsamp);
        else $display("FAILED: %0d erro(s)",errors);
        $finish;
    end
endmodule
`default_nettype wire
