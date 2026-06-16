# ============================================================================
#  Makefile - Osciloscopio de Fosforo / Phosphor Oscilloscope
#  Sipeed Tang Nano 20K
# ----------------------------------------------------------------------------
#  Fluxo OPEN-SOURCE (yosys + nextpnr-himbaechel + apicula + openFPGALoader),
#  instalavel via OSS CAD Suite (https://github.com/YosysHQ/oss-cad-suite-build).
#  Para o Gowin IDE oficial, veja o README (basta adicionar src/*.v + .cst).
#
#  OPEN-SOURCE flow (yosys + nextpnr-himbaechel + apicula + openFPGALoader),
#  installable via the OSS CAD Suite. For the official Gowin IDE see the README.
#
#  Alvos / targets:
#    make            -> gera o bitstream build/top.fs
#    make flash      -> grava na SRAM (volatil) / program SRAM (volatile)
#    make flash-spi  -> grava na Flash SPI (permanente) / program SPI flash
#    make sim        -> roda todos os testbenches / run all testbenches
#    make preview    -> gera as imagens de previa / render preview images
#    make clean
# ============================================================================

DEVICE  = GW2AR-LV18QN88C8/I7
FAMILY  = GW2A-18C
TOP     = top
BOARD   = tangnano20k

SRC     = $(wildcard src/*.v)
CST     = constraints/tangnano20k.cst
BUILD   = build

.PHONY: all flash flash-spi sim preview clean

all: $(BUILD)/top.fs

$(BUILD)/top.fs: $(SRC) $(CST)
	@mkdir -p $(BUILD)
	# A tabela de seno precisa estar no diretorio de trabalho do yosys
	# The sine table must be in yosys' working directory ($readmemh)
	cp src/sine_lut.hex sine_lut.hex
	yosys -p "read_verilog $(SRC); synth_gowin -top $(TOP) -json $(BUILD)/top.json"
	nextpnr-himbaechel --device $(DEVICE) \
		--json $(BUILD)/top.json --write $(BUILD)/top_pnr.json \
		--vopt family=$(FAMILY) --vopt cst=$(CST)
	gowin_pack -d $(FAMILY) -o $(BUILD)/top.fs $(BUILD)/top_pnr.json
	@rm -f sine_lut.hex
	@echo "OK -> $(BUILD)/top.fs"

flash: $(BUILD)/top.fs
	openFPGALoader -b $(BOARD) $(BUILD)/top.fs

flash-spi: $(BUILD)/top.fs
	openFPGALoader -b $(BOARD) -f $(BUILD)/top.fs

sim:
	cd sim && ./run.sh

preview:
	python3 model/phosphor_model.py

clean:
	rm -rf $(BUILD) sine_lut.hex sim/*.vvp sim/*.vcd
