`timescale 1ns/1ps
// ============================================================================
//  gowin_rpll.v  -  Geracao de clocks / Clock generation  (especifico Gowin)
// ----------------------------------------------------------------------------
//  A partir do cristal de 27 MHz da Tang Nano 20K geramos:
//    - clk_serial = 126 MHz  (5x o pixel, para o serializador TMDS)
//    - clk_pixel  = 25.2 MHz (clock de pixel para 640x480 @ 60 Hz)
//
//  From the Tang Nano 20K 27 MHz crystal we generate:
//    - clk_serial = 126 MHz  (5x pixel clock, for the TMDS serializer)
//    - clk_pixel  = 25.2 MHz (pixel clock for 640x480 @ 60 Hz)
//
//  Parametros do rPLL (calculados em https://juj.github.io/gowin_fpga_code_
//  generators/pll_calculator.html):  27 / 3 * 14 = 126 MHz, VCO = 1008 MHz.
//  IDIV_SEL=2 (/3), FBDIV_SEL=13 (x14), ODIV_SEL=8.
//  O clock de pixel sai de um CLKDIV /5.
// ============================================================================
`default_nettype none

module gowin_rpll (
    input  wire clk27,        // 27 MHz / cristal
    output wire clk_serial,   // 126 MHz
    output wire clk_pixel,    // 25.2 MHz
    output wire lock
);
`ifdef SIM
    // ---- Modelo comportamental p/ simulacao / behavioral model for sim ----
    reg s = 1'b0; reg [2:0] d = 3'd0; reg p = 1'b0;
    // 126 MHz aprox: meio periodo ~3.97 ns
    always #3.968 s = ~s;
    assign clk_serial = s;
    always @(posedge s) begin
        if (d == 3'd4) begin d <= 0; p <= ~p; end
        else d <= d + 1'b1;
    end
    assign clk_pixel = p;
    assign lock = 1'b1;
`else
    // ---- Hardware real: primitivas Gowin / real Gowin primitives ----
    wire pll_clkout;
    rPLL #(
        .DEVICE("GW2AR-18"),
        .FCLKIN("27"),
        .IDIV_SEL(2),        // /3  -> PFD = 9 MHz
        .FBDIV_SEL(13),      // x14 -> 126 MHz
        .ODIV_SEL(8),        // VCO = 1008 MHz
        .DYN_IDIV_SEL("false"), .DYN_FBDIV_SEL("false"), .DYN_ODIV_SEL("false"),
        .PSDA_SEL("0000"), .DYN_DA_EN("false"), .DUTYDA_SEL("1000"),
        .CLKOUT_FT_DIR(1'b1), .CLKOUTP_FT_DIR(1'b1),
        .CLKOUT_DLY_STEP(0),  .CLKOUTP_DLY_STEP(0),
        .CLKFB_SEL("internal"),
        .CLKOUT_BYPASS("false"), .CLKOUTP_BYPASS("false"), .CLKOUTD_BYPASS("false"),
        .DYN_SDIV_SEL(2), .CLKOUTD_SRC("CLKOUT"), .CLKOUTD3_SRC("CLKOUT")
    ) u_pll (
        .CLKOUT(pll_clkout), .LOCK(lock),
        .CLKOUTP(), .CLKOUTD(), .CLKOUTD3(),
        .RESET(1'b0), .RESET_P(1'b0),
        .CLKIN(clk27), .CLKFB(1'b0),
        .FBDSEL(6'b0), .IDSEL(6'b0), .ODSEL(6'b0),
        .PSDA(4'b0), .DUTYDA(4'b0), .FDLY(4'b0)
    );
    assign clk_serial = pll_clkout;

    // Divide por 5 para obter o clock de pixel / divide by 5 for pixel clock
    CLKDIV #(.DIV_MODE("5"), .GSREN("false")) u_div (
        .CLKOUT(clk_pixel),
        .HCLKIN(pll_clkout),
        .RESETN(lock),
        .CALIB(1'b0)
    );
`endif
endmodule
`default_nettype wire
