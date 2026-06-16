`timescale 1ns/1ps
`default_nettype none
module tb_video_timing;
    reg clk=0, rst=1;
    wire [9:0] x,y; wire active,hsync,vsync,frame_start;
    integer errors=0;
    video_timing dut(.clk(clk),.rst(rst),.x(x),.y(y),.active(active),
                     .hsync(hsync),.vsync(vsync),.frame_start(frame_start));
    always #5 clk=~clk;
    reg fs_prev=0; wire fs_rise=frame_start & ~fs_prev;
    always @(posedge clk) fs_prev<=frame_start;
    integer edges=0, active_cnt=0, frame_len=0, hlow=0; reg measuring=0;
    always @(posedge clk) if(!rst) begin
        if(fs_rise) begin
            edges=edges+1;
            if(edges==2) begin measuring=1; frame_len=0; active_cnt=0; hlow=0; end
            else if(edges==3) begin
                measuring=0;
                if(frame_len!==800*525) begin $display("FAIL frame_len=%0d exp=%0d",frame_len,800*525); errors=errors+1; end
                if(active_cnt!==640*480) begin $display("FAIL active=%0d exp=%0d",active_cnt,640*480); errors=errors+1; end
                if(hlow!==96*525) begin $display("FAIL hsync_low=%0d exp=%0d",hlow,96*525); errors=errors+1; end
            end
        end
        if(measuring) begin
            frame_len=frame_len+1;
            if(active) active_cnt=active_cnt+1;
            if(!hsync) hlow=hlow+1;
            if(active && !hsync) begin $display("FAIL hsync low during active"); errors=errors+1; end
        end
    end
    initial begin
        repeat(4) @(posedge clk); rst=0;
        repeat(3*800*525+2000) @(posedge clk);
        if(edges<3) begin $display("FAIL edges=%0d",edges); errors=errors+1; end
        if(errors==0) $display("PASS tb_video_timing");
        else $display("FAILED: %0d erro(s)",errors);
        $finish;
    end
endmodule
`default_nettype wire
