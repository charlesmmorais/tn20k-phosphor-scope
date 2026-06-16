# 🟢 Osciloscópio de Fósforo / Phosphor Oscilloscope - Tang Nano 20K

**🇧🇷 Português** · [🇬🇧 English](README.en.md)

> Um FPGA de ~R$150 que **vira** um osciloscópio analógico de fósforo verde, saindo direto no seu monitor por HDMI - sem ADC, sem placa extra, sem SDRAM externa. Tudo cabe dentro do chip.

<p align="center">
  <img src="docs/images/preview_lissajous.png" width="520" alt="Figura de Lissajous 2:3 com brilho de fósforo"/>
</p>

<p align="center">
  <img src="docs/images/preview_patterns.png" width="780" alt="As 8 figuras geradas"/>
</p>

*(As imagens acima são geradas pelo **modelo de referência em Python** - `model/phosphor_model.py` - que usa exatamente a mesma matemática do hardware. É a previsão fiel do que aparece na tela.)*

---

## ✨ Por que este projeto faz o maker pensar "por que não pensei nisto antes?"

A maioria dos projetos de FPGA com HDMI desenha *quadrados, barras de cor ou o jogo da vida*. Aqui a ideia é outra:

> **O FPGA não está desenhando um osciloscópio. O FPGA É o osciloscópio.**
> Ele modela, em silício, as duas coisas físicas que dão a um tubo de raios catódicos (CRT) aquela beleza inconfundível: **o feixe de elétrons** e **o fósforo que brilha e esfria**.

E o detalhe que quase ninguém implementa, o que separa um "traço de computador" de um "traço analógico":

🔑 **O brilho de cada ponto é proporcional ao tempo que o feixe passa ali (modulação do eixo Z).**
Num CRT real, onde o feixe é lento ele deposita mais energia e o fósforo brilha mais - por isso as *pontas* de uma figura de Lissajous são ofuscantes e os trechos rápidos são tênues. Aqui medimos o "comprimento" de cada segmento e acendemos o pixel com brilho **∝ 1/velocidade**. É isso que faz o resultado parecer um Tektronix dos anos 70, e não um GIF.

Junte a isso o **decaimento do fósforo** (uma varredura contínua que vai apagando a tela devagarinho) e você tem aquele *afterglow* - o rastro que persiste e some suavemente.

---

## 🧠 Como funciona (visão geral)

<p align="center">
  <img src="docs/images/architecture.svg" width="900" alt="Diagrama de arquitetura"/>
</p>

O sinal percorre uma linha de montagem (*pipeline*):

1. **`gowin_rpll`** - do cristal de 27 MHz gera **25.2 MHz** (clock de pixel) e **126 MHz** (5× para o serializador TMDS).
2. **`signal_gen`** - um **DDS** (síntese digital direta) com tabela de seno produz os pontos (x,y) que o feixe deve seguir. Mudando a razão de frequências X:Y nascem as figuras de **Lissajous**.
3. **`beam_plotter`** - liga os pontos com retas usando **Bresenham** (só somas!) e calcula o **brilho ∝ 1/velocidade**.
4. **`scope_engine`** - dono da memória de imagem. Faz duas coisas ao mesmo tempo: **ACENDE** (soma brilho onde o feixe passa) e **APAGA** (varre toda a memória subtraindo 1 - o fósforo esfriando).
5. **`framebuffer`** - 320×240 com 4 bits de intensidade por pixel, **dentro da BSRAM do FPGA** (sem SDRAM externa!). É lido pelo vídeo e escalado 2× para 640×480.
6. **`colorizer`** - converte intensidade em verde fósforo **P31** e desenha a **graticula** (a grade do osciloscópio).
7. **`tmds_encoder` ×3 + `hdmi_serializer`** - codificação **8b/10b (DVI)** e serialização **OSER10 + ELVDS** para os pares diferenciais do HDMI.

📖 **Quer o porquê de cada bloco, com a matemática?** Leia [`docs/theory_pt.md`](docs/theory_pt.md).

---

## 🛠️ Hardware necessário

- **Sipeed Tang Nano 20K** (FPGA Gowin `GW2AR-LV18QN88C8/I7`).
- Um **cabo HDMI** e um monitor/TV que aceite **640×480 @ 60 Hz** (praticamente todos).
- Só isso. **Nenhum** componente externo, ADC ou fonte de sinal - o gerador de sinais é interno.

---

## 🚀 Como compilar e gravar

### Opção A - Ferramentas open-source (recomendado, scriptável)

Instale o [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build) (traz `yosys`, `nextpnr-himbaechel`, `apicula`/`gowin_pack` e `openFPGALoader`). Depois:

```bash
make            # gera build/top.fs
make flash      # grava na SRAM (some ao desligar)
make flash-spi  # grava na Flash (permanente)
```

### Opção B - Gowin IDE oficial

1. Crie um projeto para o dispositivo `GW2AR-LV18QN88C8/I7`.
2. Adicione todos os arquivos de `src/*.v` e a tabela `src/sine_lut.hex`.
3. Adicione as restrições `constraints/tangnano20k.cst` e `constraints/tangnano20k.sdc`.
4. Defina `top` como módulo de topo, sintetize, faça o place & route e grave.

> ⚠️ **Pinos do HDMI/botões:** os números em `tangnano20k.cst` são os mais comuns, mas **podem variar com a revisão da placa**. Se a tela ficar preta, confira contra o [exemplo oficial da Sipeed](https://github.com/sipeed/TangNano-20K-example) e o esquemático.

---

## 🎮 Controles

O projeto é **autônomo**: ao ligar, ele já começa a desenhar e **troca de figura sozinho a cada ~6 segundos**. Os dois botões da placa permitem interagir:

| Botão | Ação |
|-------|------|
| **BTN0** (S1) | Próxima figura agora |
| **BTN1** (S2) | Liga/desliga a troca automática |

Os **LEDs** mostram o estado: PLL travada, modo automático e o número da figura atual.

As 8 figuras: `Lissajous 1:1`, `1:2`, `1:3`, `2:3`, `3:4`, `3:5`, e duas no **modo YT** (tempo) - `seno` e `triângulo` - com **disparo (trigger)** para a onda ficar parada na tela.

---

## 🔬 Simulação e testes (tudo verificado!)

Você **não precisa do FPGA** para conferir que a lógica está correta. Todos os blocos têm testbench em Icarus Verilog:

```bash
sudo apt install iverilog     # se ainda não tiver
make sim                      # ou:  cd sim && ./run.sh
```

| Testbench | O que prova |
|-----------|-------------|
| `tb_video_timing` | Conta 800×525 ciclos/quadro, 640×480 pixels ativos e a largura do sincronismo (96/linha). |
| `tb_signal_gen` | Todas as amostras caem dentro do framebuffer e cada figura realmente varia. |
| `tb_tmds_encoder` | **Round-trip** (codifica→decodifica volta o byte original) em 8256 símbolos + **balanço DC** limitado. |
| `tb_scope_engine` | Desenha um segmento com o brilho certo e o **decaimento** leva o pixel de volta a 0. |
| `tb_top_smoke` | Integra tudo: vídeo roda sem `X`, sincronismos alternam, TMDS válido. |

Saída esperada: **`RESULTADO / RESULT: 4 PASS, 0 FAIL`**.

> 💡 E mais: `model/phosphor_model.py` é um **modelo de referência** em Python que reproduz a mesma matemática e gera as imagens deste README. Rode `make preview` para gerá-las.

---

## 📁 Estrutura do projeto

```
tn20k-phosphor-scope/
├── src/                  # RTL (Verilog) - o coração do projeto
│   ├── top.v             # topo: liga todos os blocos
│   ├── gowin_rpll.v      # PLL: 27 → 126 / 25.2 MHz  (primitivas Gowin)
│   ├── video_timing.v    # sincronismo 640x480@60
│   ├── control.v         # botões + troca automática
│   ├── signal_gen.v      # DDS: gera os pontos (Lissajous / YT)
│   ├── sine_lut.v        # tabela de seno (+ sine_lut.hex)
│   ├── beam_plotter.v    # Bresenham + brilho ∝ velocidade
│   ├── scope_engine.v    # acende (draw) + apaga (decay) o fósforo
│   ├── framebuffer.v     # BSRAM 320x240x4 dual-port
│   ├── colorizer.v       # verde P31 + graticula
│   ├── tmds_encoder.v    # 8b/10b (DVI) - lógica pura, testável
│   └── hdmi_serializer.v # OSER10 + ELVDS  (primitivas Gowin)
├── sim/                  # testbenches + run.sh
├── model/               # modelo de referência em Python + previews
├── constraints/         # .cst (pinos), .sdc (tempo), clocks.py (OSS)
├── docs/                # teoria detalhada (PT/EN) + diagramas
├── Makefile             # fluxo OSS + sim + preview
└── README.md
```

---

## 🧪 Brinque com os parâmetros (mini-exercícios didáticos)

Quase tudo é parametrizado. Experimente e veja na tela:

- **Persistência do fósforo** - em `scope_engine.v`, o decaimento subtrai 1 por varredura. Faça-o subtrair 1 a cada *N* varreduras para um rastro **mais longo** (como um fósforo P7 de radar), ou aumente para apagar mais rápido.
- **Velocidade das figuras** - em `signal_gen.v`, o parâmetro `STEP` controla a velocidade do feixe; `SLOW_BITS` controla a lentidão do *morph* (a figura girando).
- **Resolução do framebuffer / profundidade de cor** - `framebuffer.v` usa 4 bits (16 níveis). Suba para 5–6 bits para gradientes mais suaves (cuidado com o uso de BSRAM).
- **Novas figuras** - adicione razões X:Y na tabela de `signal_gen.v` e crie suas próprias Lissajous.
- **Cor do fósforo** - `colorizer.v` faz verde P31. Troque para o âmbar P3 ou o branco-azulado P4.

---

## ❓ Resolução de problemas

- **Tela preta / "sem sinal":** quase sempre são os **pinos do HDMI** no `.cst` (veja o aviso acima) ou o monitor não aceitar 640×480. Confira os LEDs: se a PLL não trava, reveja o clock de 27 MHz (pino 4).
- **Imagem treme / cores erradas:** confira a polaridade dos pares diferenciais; alguns cabos/placas invertem P/N.
- **Nada nos botões:** o projeto funciona mesmo sem eles (troca automática). Verifique os pinos `btn_n` no `.cst`.
- **`make` falha no `nextpnr`:** use uma versão recente do OSS CAD Suite - o suporte a Gowin (`himbaechel`) evolui rápido.

---

## 📜 Licença

[MIT](LICENSE) - use, modifique, ensine e compartilhe à vontade.

---

## 🙌 Créditos & referências

Projeto autoral. Apoiado em conhecimento público de: especificação **DVI/TMDS**, primitivas **Gowin** (rPLL, CLKDIV, OSER10, ELVDS_OBUF), o fluxo **OSS** (Yosys + nextpnr-himbaechel + apicula) e os exemplos da **Sipeed** para a Tang Nano 20K.

Se este projeto te fez sorrir, deixe uma ⭐ e mostre o seu fósforo brilhando. 🟢
