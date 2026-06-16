`timescale 1ns/1ps
// ============================================================================
//  top.v  -  Osciloscopio de Fosforo / Phosphor Oscilloscope  (TOP LEVEL)
//  Sipeed Tang Nano 20K  (Gowin GW2AR-LV18QN88C8/I7)
// ----------------------------------------------------------------------------
//  Liga todos os blocos:
//    gowin_rpll   -> gera 25.2 MHz (pixel) e 126 MHz (serial)
//    video_timing -> sincronismo 640x480@60
//    control      -> escolhe a figura (auto + botoes)
//    signal_gen   -> gera os pontos (DDS)
//    beam_plotter -> desenha a reta entre pontos (brilho ~ velocidade)
//    scope_engine -> acende (draw) e apaga (decay) o fosforo no framebuffer
//    framebuffer  -> 320x240x4 em BSRAM
//    colorizer    -> intensidade -> verde P31 + graticula
//    tmds_encoder -> 8b/10b (x3)
//    hdmi_serializer -> OSER10 + ELVDS -> pinos HDMI
//
//  Fluxo de video alinhado em pipeline / aligned video pipeline:
//    timing(x,y,sync) --addr--> framebuffer(+1) --> colorizer --> tmds(+1) --> ser
//  As posicoes e sincronismos sao atrasados 1 ciclo para casar com a leitura
//  da BSRAM. / position & sync are delayed 1 cycle to match BSRAM read latency.
// ============================================================================
`default_nettype none

module top (
    input  wire        clk27,        // 27 MHz  (pino 4 / pin 4)
    input  wire [1:0]  btn_n,        // 2 botoes, ativo-baixo / 2 buttons, active-low
    output wire [5:0]  led,          // 6 LEDs, ativo-baixo / active-low
    output wire        tmds_clk_p,
    output wire        tmds_clk_n,
    output wire [2:0]  tmds_d_p,
    output wire [2:0]  tmds_d_n
);
    // ---------------- Clocks ----------------
    wire clk_pix, clk_ser, lock;
    gowin_rpll u_pll (.clk27(clk27), .clk_serial(clk_ser),
                      .clk_pixel(clk_pix), .lock(lock));

    // Reset sincronizado no dominio de pixel / pixel-domain synchronous reset
    reg [1:0] rst_sync = 2'b11;
    always @(posedge clk_pix) rst_sync <= {rst_sync[0], ~lock};
    wire rst = rst_sync[1];

    // ---------------- Sincronismo de video / video timing ----------------
    wire [9:0] x, y;
    wire       active, hsync, vsync, frame_start;
    video_timing u_vt (
        .clk(clk_pix), .rst(rst),
        .x(x), .y(y), .active(active),
        .hsync(hsync), .vsync(vsync), .frame_start(frame_start)
    );

    // ---------------- Controle / control ----------------
    wire [2:0] pattern;
    wire       auto_en;
    control u_ctrl (.clk(clk_pix), .rst(rst), .btn_n(btn_n),
                    .pattern(pattern), .auto_en(auto_en));

    // ---------------- Gerador + tracador / generator + plotter ----------------
    wire [9:0] s_x, s_y; wire s_valid;
    signal_gen u_sg (.clk(clk_pix), .rst(rst), .pattern(pattern),
                     .px(s_x), .py(s_y), .sample_valid(s_valid));

    wire [9:0] d_x, d_y; wire [3:0] d_amt; wire d_valid, d_ready;
    beam_plotter u_bp (.clk(clk_pix), .rst(rst),
                       .s_x(s_x), .s_y(s_y), .s_valid(s_valid),
                       .o_x(d_x), .o_y(d_y), .o_amt(d_amt),
                       .o_valid(d_valid), .o_ready(d_ready));

    // ---------------- Framebuffer + engine ----------------
    wire [16:0] a_addr, b_addr;
    wire [3:0]  a_dout, b_dout, b_din;
    wire        b_we, eng_ready;

    // endereco de leitura de video: (y/2)*320 + (x/2)  (sem multiplicador)
    // video read address using shifts only
    wire [9:0] yy = {1'b0, y[9:1]};   // y/2  (0..239)
    wire [9:0] xx = {1'b0, x[9:1]};   // x/2  (0..319)
    assign a_addr = ({7'd0,yy} << 8) + ({7'd0,yy} << 6) + {7'd0,xx};

    framebuffer u_fb (
        .clk(clk_pix),
        .a_addr(a_addr), .a_dout(a_dout),
        .b_addr(b_addr), .b_din(b_din), .b_we(b_we), .b_dout(b_dout)
    );

    scope_engine u_eng (
        .clk(clk_pix), .rst(rst),
        .d_x(d_x), .d_y(d_y), .d_amt(d_amt), .d_valid(d_valid), .d_ready(d_ready),
        .b_addr(b_addr), .b_din(b_din), .b_we(b_we), .b_dout(b_dout),
        .ready(eng_ready)
    );

    // ---------------- Pipeline de video / video pipeline ----------------
    // Atrasa posicao e sincronismo 1 ciclo p/ casar com a_dout (BSRAM +1)
    reg [9:0] x_d1, y_d1;
    reg       active_d1, hsync_d1, vsync_d1;
    always @(posedge clk_pix) begin
        x_d1 <= x; y_d1 <= y;
        active_d1 <= active; hsync_d1 <= hsync; vsync_d1 <= vsync;
    end

    wire [7:0] cr, cg, cb;
    colorizer u_col (
        .intensity(a_dout), .x(x_d1), .y(y_d1), .active(active_d1),
        .r(cr), .g(cg), .b(cb)
    );

    // ---------------- Codificacao TMDS / TMDS encoding ----------------
    wire [9:0] tr, tg, tb;
    // Canal azul carrega hsync/vsync no blanking / blue channel carries sync
    tmds_encoder u_eb (.clk(clk_pix), .de(active_d1), .ctrl({vsync_d1,hsync_d1}),
                       .din(cb), .q_out(tb));
    tmds_encoder u_eg (.clk(clk_pix), .de(active_d1), .ctrl(2'b00),
                       .din(cg), .q_out(tg));
    tmds_encoder u_er (.clk(clk_pix), .de(active_d1), .ctrl(2'b00),
                       .din(cr), .q_out(tr));

    hdmi_serializer u_ser (
        .clk_serial(clk_ser), .clk_pixel(clk_pix), .rst(~lock),
        .tmds_r(tr), .tmds_g(tg), .tmds_b(tb),
        .tmds_clk_p(tmds_clk_p), .tmds_clk_n(tmds_clk_n),
        .tmds_d_p(tmds_d_p),     .tmds_d_n(tmds_d_n)
    );

    // ---------------- LEDs de status / status LEDs ----------------
    reg [6:0] hb = 7'd0;
    always @(posedge clk_pix)
        if (rst) hb <= 7'd0; else if (frame_start) hb <= hb + 1'b1;
    // ativo-baixo: bit 1 acende o LED / active-low: a 1 lights the LED
    assign led = ~{lock, auto_en, pattern, hb[6]};

endmodule
`default_nettype wire
