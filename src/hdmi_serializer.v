`timescale 1ns/1ps
// ============================================================================
//  hdmi_serializer.v  -  Serializa TMDS e gera os pares diferenciais (Gowin)
//                        Serialises TMDS and drives the differential pairs
// ----------------------------------------------------------------------------
//  Cada canal (R, G, B) tem 10 bits por pixel. A 25.2 MHz precisamos enviar
//  esses 10 bits em 1 periodo de pixel -> a 252 Mbit/s por canal. Usamos a
//  primitiva OSER10 (serializador 10:1 DDR) com FCLK=126 MHz, e o buffer
//  diferencial ELVDS_OBUF para sair nos pinos HDMI. O canal de clock envia o
//  padrao fixo 10'b1111100000.
//
//  Each channel (R,G,B) has 10 bits per pixel. At 25.2 MHz those 10 bits go
//  out in one pixel period -> 252 Mbit/s per channel. We use the OSER10 (10:1
//  DDR serialiser) primitive with FCLK=126 MHz, and the ELVDS_OBUF differential
//  buffer for the HDMI pins. The clock channel sends the fixed 10'b1111100000.
//
//  Em SIM, OSER10/ELVDS sao substituidos por modelos simples para permitir
//  elaborar o topo. / In SIM these primitives are replaced by simple models.
// ============================================================================
`default_nettype none

module hdmi_serializer (
    input  wire        clk_serial,  // 126 MHz
    input  wire        clk_pixel,   // 25.2 MHz
    input  wire        rst,
    input  wire [9:0]  tmds_r,
    input  wire [9:0]  tmds_g,
    input  wire [9:0]  tmds_b,
    output wire        tmds_clk_p, tmds_clk_n,
    output wire [2:0]  tmds_d_p,   tmds_d_n
);
    wire [3:0] ser; // 0,1,2 = B,G,R ; 3 = clock

`ifdef SIM
    // Modelo bem simples: apenas registra o LSB / very simple model
    reg [3:0] ser_r;
    always @(posedge clk_serial) ser_r <= {1'b1, tmds_r[0], tmds_g[0], tmds_b[0]};
    assign ser = ser_r;
`else
    // ---- Serializadores 10:1 / 10:1 serialisers ----
    OSER10 u_b (.Q(ser[0]), .FCLK(clk_serial), .PCLK(clk_pixel), .RESET(rst),
        .D0(tmds_b[0]),.D1(tmds_b[1]),.D2(tmds_b[2]),.D3(tmds_b[3]),.D4(tmds_b[4]),
        .D5(tmds_b[5]),.D6(tmds_b[6]),.D7(tmds_b[7]),.D8(tmds_b[8]),.D9(tmds_b[9]));
    OSER10 u_g (.Q(ser[1]), .FCLK(clk_serial), .PCLK(clk_pixel), .RESET(rst),
        .D0(tmds_g[0]),.D1(tmds_g[1]),.D2(tmds_g[2]),.D3(tmds_g[3]),.D4(tmds_g[4]),
        .D5(tmds_g[5]),.D6(tmds_g[6]),.D7(tmds_g[7]),.D8(tmds_g[8]),.D9(tmds_g[9]));
    OSER10 u_r (.Q(ser[2]), .FCLK(clk_serial), .PCLK(clk_pixel), .RESET(rst),
        .D0(tmds_r[0]),.D1(tmds_r[1]),.D2(tmds_r[2]),.D3(tmds_r[3]),.D4(tmds_r[4]),
        .D5(tmds_r[5]),.D6(tmds_r[6]),.D7(tmds_r[7]),.D8(tmds_r[8]),.D9(tmds_r[9]));
    // Canal de clock: padrao TMDS / clock channel: TMDS pattern
    OSER10 u_c (.Q(ser[3]), .FCLK(clk_serial), .PCLK(clk_pixel), .RESET(rst),
        .D0(1'b1),.D1(1'b1),.D2(1'b1),.D3(1'b1),.D4(1'b1),
        .D5(1'b0),.D6(1'b0),.D7(1'b0),.D8(1'b0),.D9(1'b0));
`endif

`ifdef SIM
    assign tmds_d_p   = ser[2:0];  assign tmds_d_n = ~ser[2:0];
    assign tmds_clk_p = ser[3];    assign tmds_clk_n = ~ser[3];
`else
    // ---- Buffers diferenciais emulados (ELVDS) / emulated LVDS buffers ----
    ELVDS_OBUF u_ob (.I(ser[0]), .O(tmds_d_p[0]), .OB(tmds_d_n[0]));
    ELVDS_OBUF u_og (.I(ser[1]), .O(tmds_d_p[1]), .OB(tmds_d_n[1]));
    ELVDS_OBUF u_or (.I(ser[2]), .O(tmds_d_p[2]), .OB(tmds_d_n[2]));
    ELVDS_OBUF u_oc (.I(ser[3]), .O(tmds_clk_p),  .OB(tmds_clk_n));
`endif
endmodule
`default_nettype wire
