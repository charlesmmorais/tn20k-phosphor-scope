# clocks.py - Restricoes de clock para o fluxo OSS (nextpnr-himbaechel)
# Clock constraints for the OSS flow. Passed via: nextpnr ... --pre-pack clocks.py
# Ajuste os nomes se a sua versao do nextpnr exigir nomes hierarquicos.
# Adjust names if your nextpnr version needs hierarchical names.
ctx.addClock("clk27", 27)        # cristal / crystal
# Os clocks derivados do rPLL/CLKDIV (126 MHz e 25.2 MHz) normalmente sao
# detectados automaticamente. Se necessario, descomente e ajuste:
# ctx.addClock("clk_ser", 126)
# ctx.addClock("clk_pix", 25.2)
