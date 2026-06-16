// tangnano20k.sdc - Restricoes de tempo / timing constraints (Gowin IDE)
// O clock de entrada e 27 MHz (periodo ~37.04 ns). Os clocks de 126 MHz e
// 25.2 MHz sao DERIVADOS pelo rPLL/CLKDIV e a ferramenta os propaga.
// Input clock is 27 MHz; the 126 MHz and 25.2 MHz clocks are derived by the
// rPLL/CLKDIV and propagated by the tool.
create_clock -name clk27 -period 37.04 -waveform {0 18.52} [get_ports {clk27}]
