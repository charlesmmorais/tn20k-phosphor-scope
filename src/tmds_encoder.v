`timescale 1ns/1ps
// tmds_encoder.v - Codificador TMDS 8b/10b (DVI) / TMDS 8b/10b encoder (DVI)
// q_out[0] e transmitido primeiro / q_out[0] is transmitted first.
`default_nettype none
module tmds_encoder (
    input  wire clk, input wire de, input wire [1:0] ctrl,
    input  wire [7:0] din, output reg [9:0] q_out
);
    wire [3:0] n1d = din[0]+din[1]+din[2]+din[3]+din[4]+din[5]+din[6]+din[7];
    wire use_xnor = (n1d>4'd4) || ((n1d==4'd4)&&(din[0]==1'b0));
    wire [8:0] qm;
    assign qm[0]=din[0];
    assign qm[1]=use_xnor?~(qm[0]^din[1]):(qm[0]^din[1]);
    assign qm[2]=use_xnor?~(qm[1]^din[2]):(qm[1]^din[2]);
    assign qm[3]=use_xnor?~(qm[2]^din[3]):(qm[2]^din[3]);
    assign qm[4]=use_xnor?~(qm[3]^din[4]):(qm[3]^din[4]);
    assign qm[5]=use_xnor?~(qm[4]^din[5]):(qm[4]^din[5]);
    assign qm[6]=use_xnor?~(qm[5]^din[6]):(qm[5]^din[6]);
    assign qm[7]=use_xnor?~(qm[6]^din[7]):(qm[6]^din[7]);
    assign qm[8]=use_xnor?1'b0:1'b1;
    wire [3:0] n1 = qm[0]+qm[1]+qm[2]+qm[3]+qm[4]+qm[5]+qm[6]+qm[7];
    wire [3:0] n0 = 4'd8-n1;
    wire signed [7:0] diff = $signed({4'b0,n1})-$signed({4'b0,n0});
    reg signed [7:0] cnt = 8'sd0;   // disparidade / running disparity (inicia 0)
    always @(posedge clk) begin
        if (de) begin
            if (cnt==0 || n1==n0) begin
                q_out[9]<=~qm[8]; q_out[8]<=qm[8];
                q_out[7:0]<=qm[8]?qm[7:0]:~qm[7:0];
                cnt<=qm[8]?(cnt+diff):(cnt-diff);
            end else if ((cnt>0 && n1>n0) || (cnt<0 && n0>n1)) begin
                q_out[9]<=1'b1; q_out[8]<=qm[8]; q_out[7:0]<=~qm[7:0];
                cnt<=cnt+(qm[8]?8'sd2:8'sd0)-diff;
            end else begin
                q_out[9]<=1'b0; q_out[8]<=qm[8]; q_out[7:0]<=qm[7:0];
                cnt<=cnt-(qm[8]?8'sd0:8'sd2)+diff;
            end
        end else begin
            case (ctrl)
                2'b00: q_out<=10'b1101010100;
                2'b01: q_out<=10'b0010101011;
                2'b10: q_out<=10'b0101010100;
                2'b11: q_out<=10'b1010101011;
            endcase
            cnt<=8'sd0;
        end
    end
endmodule
`default_nettype wire
