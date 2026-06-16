# 📚 Teoria — Como cada peça funciona

[🇬🇧 English version](theory_en.md) · [⬅️ Voltar ao README](../README.md)

Este documento explica, com calma e do zero, **por que** cada bloco existe e **como** ele funciona. A ideia é que um maker que nunca mexeu com FPGA consiga entender — e que quem já mexe descubra um ou dois truques.

---

## 1. A grande sacada: o FPGA como um CRT digital

Um osciloscópio analógico tem um **tubo de raios catódicos (CRT)**. Dentro dele:

- um **feixe de elétrons** é defletido por tensões (X horizontal, Y vertical) e desenha uma trajetória;
- onde o feixe bate, uma camada de **fósforo** absorve energia e **brilha**;
- quando o feixe sai dali, o fósforo **esfria** e o brilho **decai** ao longo de alguns milissegundos.

Nós reproduzimos as três coisas em lógica digital:

| Mundo analógico | Nosso equivalente digital |
|-----------------|---------------------------|
| Feixe defletido por X/Y | `signal_gen` (gera X,Y) + `beam_plotter` (traça a reta) |
| Fósforo acendendo | `scope_engine` soma brilho no `framebuffer` |
| Fósforo esfriando | `scope_engine` varre e subtrai brilho (decay) |
| Tela de fósforo verde | `colorizer` (paleta P31) |
| Tubo / vidro | o monitor, via HDMI |

A grande diferença para um "desenho de computador" comum está no item do **brilho proporcional à velocidade** — veja a seção 4.

---

## 2. DDS — gerando os pontos (`signal_gen.v`)

**DDS (Direct Digital Synthesis / Síntese Digital Direta)** é a forma mais simples e elegante de gerar uma onda periódica em hardware.

A ideia: um **acumulador de fase** (um registrador que você soma sempre o mesmo valor) gira como o ponteiro de um relógio. Os bits altos desse acumulador são o "ângulo", que usamos para endereçar uma **tabela de seno**.

```verilog
ph_x <= ph_x + (STEP * rx);     // acumulador de 16 bits
addr_x = ph_x[15:8];            // 8 bits altos = ângulo 0..255 (0..360°)
sin_x  = sine_lut[addr_x];      // valor da senoide
```

- Quanto **maior** o passo (`STEP * rx`), mais rápido o ponteiro gira → **frequência maior**.
- A **tabela** (`sine_lut.hex`) tem 256 amostras de uma senoide, amplitude ±120, em complemento de dois de 8 bits. Ela é gerada por Python para que **hardware e simulação usem exatamente os mesmos números**.

### Figuras de Lissajous (modo XY)

Se ligarmos X = sen(a·t) no eixo horizontal e Y = sen(b·t) no vertical, a trajetória fecha numa **figura de Lissajous**. A razão **a:b** define o formato:

- 1:1 → uma elipse (ou reta/círculo, dependendo da fase);
- 1:2 → um "8" deitado;
- 2:3, 3:4, 3:5 → laços cada vez mais elaborados.

Aqui controlamos a razão com `rx` e `ry`. E um **deslocamento de fase lento** (`morph`) vai mudando a fase de X devagar, fazendo a figura **girar/abrir** — o aspecto "vivo" de um osciloscópio analógico real, onde nada fica perfeitamente parado.

### Modo YT e o disparo (trigger)

No modo **YT** (tempo no eixo X), o X é uma **varredura** (sobe de 0 a 319 e recomeça) e o Y segue a forma de onda. Mas há um problema clássico: se a varredura recomeça num instante qualquer, cada passagem mostra a onda numa fase diferente e a tela vira uma **malha borrada**.

A solução, que todo osciloscópio de verdade usa, é o **disparo (trigger)**: começar a varredura sempre no mesmo ponto da onda. Implementamos isso de forma simples — ao reiniciar a varredura, **zeramos também a fase da onda** (`yt_ph <= 0`). Resultado: a onda fica **parada e nítida**.

---

## 3. Bresenham — ligando os pontos (`beam_plotter.v`)

O `signal_gen` entrega pontos espaçados; precisamos desenhar a **reta** entre um ponto e o próximo, pixel a pixel. O algoritmo de **Bresenham** faz isso usando **apenas somas, subtrações e comparações** — nada de multiplicação ou divisão, perfeito para hardware.

A ideia é manter um "erro acumulado" que decide, a cada passo, se andamos em X, em Y, ou nos dois:

```verilog
e2 = 2*err;
if (e2 > -ady) begin err <= err - ady; cx <= cx + sx; end
if (e2 <  adx) begin err <= err + adx; cy <= cy + sy; end
```

Quando o salto entre dois pontos é grande demais (acima de `MAX_SEG`), tratamos como **retração** (pen-up) e **não** desenhamos a reta — é o que evita um risco atravessando a tela quando a varredura do modo YT "volta" do fim para o começo. Num CRT real, o feixe também é apagado durante a retração.

### Handshake valid/ready

O plotter e o `scope_engine` conversam por um **handshake valid/ready**: o plotter mostra um pixel e só avança quando o engine **aceita**. Isso garante que **nenhum pixel é perdido**, mesmo que o engine esteja ocupado apagando a tela. As saídas do plotter são **combinacionais** (refletem o pixel atual na hora), o que evita um atraso de 1 ciclo que duplicaria ou perderia pixels — um bug sutil que só aparece quando você simula com cuidado.

---

## 4. 🔑 O brilho ∝ velocidade (o coração analógico)

Esta é a parte que faz o resultado parecer **analógico de verdade**.

Num CRT, o brilho de um ponto depende de **quanta energia** o feixe depositou ali, que por sua vez depende de **quanto tempo** o feixe ficou ali. Onde a trajetória é **lenta** (as pontas, os retornos de uma Lissajous), o feixe demora mais e o fósforo brilha **muito**. Onde é **rápida** (os trechos retos no meio), o brilho é **fraco**.

Como medir "velocidade" em hardware barato? Truque: o `beam_plotter` já sabe o **comprimento** do segmento entre dois pontos (o `max(|dx|,|dy|)` de Bresenham). Como cada segmento é desenhado no mesmo intervalo de tempo, **comprimento grande = feixe rápido = pouco brilho**, e vice-versa:

```verilog
// segmentos curtos (feixe lento) → brilho alto
if      (steps <= 1)  bright = 15;
else if (steps <= 2)  bright = 12;
else if (steps <= 4)  bright = 9;
...
else                  bright = 2;   // segmentos longos (feixe rápido) → brilho baixo
```

É **uma tabelinha de seis linhas** — e é exatamente isso que separa uma figura que parece um Tektronix de uma que parece um print de calculadora. Repare nas pontas brilhantes das Lissajous do README: é a modulação do eixo Z acontecendo.

---

## 5. O fósforo: acender e apagar (`scope_engine.v` + `framebuffer.v`)

### O framebuffer cabe dentro do FPGA

Guardamos a tela numa memória de **320×240 pixels, 4 bits (16 níveis de brilho) cada** = 307.200 bits. Isso cabe folgado na **BSRAM** do GW2AR-18 (~828 kbit), então **não precisamos da SDRAM externa**. Isso simplifica muito o projeto e o torna 100% simulável. Depois escalamos 2× (320→640, 240→480) na hora de mostrar.

A memória é **dual-port** (duas portas independentes):
- **Porta A**: o vídeo **lê** para mostrar na tela.
- **Porta B**: o `scope_engine` **lê-modifica-escreve** (acende e apaga).

### Acender (DRAW) e apagar (DECAY) ao mesmo tempo

O `scope_engine` faz duas tarefas alternando na porta B:

- **DRAW**: quando o plotter entrega um pixel, soma brilho ali (saturando em 15). É o fósforo acendendo.
- **DECAY**: continuamente, um ponteiro varre **toda** a memória subtraindo 1 do brilho de cada pixel. É o fósforo esfriando.

O DRAW tem **prioridade**: quando há um pixel novo para desenhar, ele vem primeiro; nos ciclos livres, o engine vai apagando. Como a BSRAM tem **1 ciclo de latência** de leitura, cada operação é um *read-modify-write* de 2 ciclos (lê → calcula → escreve).

A velocidade do DECAY define a **persistência do fósforo**: apagar devagar = rastro longo (estilo radar); apagar rápido = traço nítido sem fantasma. É só mexer num parâmetro.

> Ao ligar, uma fase **CLEAR** zera toda a memória antes de começar — garante uma tela preta limpa, sem lixo de inicialização.

---

## 6. Cor e graticula (`colorizer.v`)

A intensidade de 4 bits vira uma cor RGB de **fósforo verde P31** (o verde clássico dos osciloscópios). Nos níveis mais altos somamos um pouco de vermelho e azul para o **pico** do rastro parecer "branco quente", como num CRT saturado.

Por baixo do rastro desenhamos a **graticula** — a grade do osciloscópio, com linhas a cada 64 pixels, eixos centrais mais fortes e uma borda. O rastro sempre vence a grade (usamos o maior verde), então a figura fica nítida por cima da grade.

---

## 7. Os clocks (`gowin_rpll.v`)

Precisamos de dois clocks a partir do cristal de **27 MHz**:

- **25.2 MHz** — clock de **pixel** para 640×480 @ 60 Hz (o padrão VESA é 25.175 MHz; 25.2 é perto o suficiente).
- **126 MHz** — exatamente **5×** o pixel, para o serializador TMDS (cada pixel vira 10 bits, enviados em 5 ciclos a taxa dupla — DDR).

Usamos o **rPLL** (PLL embutido do Gowin): `27 ÷ 3 × 14 = 126 MHz` (com a VCO interna em 1008 MHz, dentro da faixa válida). Depois um **CLKDIV ÷5** tira os 25.2 MHz do mesmo sinal, mantendo os dois clocks **alinhados em fase** — essencial para o serializador funcionar.

---

## 8. TMDS / DVI — falando a língua do HDMI (`tmds_encoder.v`)

O HDMI (no modo DVI) não envia os bits de cor "crus". Ele usa **TMDS — Transition Minimized Differential Signaling**, uma codificação **8b/10b**: cada byte de cor (8 bits) vira um símbolo de **10 bits** que faz duas coisas:

1. **Minimiza transições** — encadeando XOR ou XNOR, escolhemos a forma com menos "viradas" de 0↔1, o que reduz interferência eletromagnética no cabo.
2. **Equilibra o DC** — um contador de "disparidade" acompanha quantos 0s e 1s já foram enviados e, quando preciso, **inverte** o símbolo para manter o número de 0s e 1s equilibrado ao longo do tempo. O receptor precisa disso para recuperar o nível do sinal.

Fora da área visível (durante o *blanking*), em vez de cor enviamos um dos **4 tokens de controle**, que carregam os sincronismos **hsync** e **vsync**.

Esse módulo é **lógica pura** e por isso é o mais rigorosamente testado: o testbench faz **round-trip** (codifica e decodifica de volta, conferindo que o byte original volta intacto) em milhares de símbolos, e verifica que a disparidade DC permanece **limitada** (não cresce sem parar). Foi assim que pegamos um bug real: sem inicializar o contador de disparidade, o balanço DC quebrava.

---

## 9. Serialização e os pares diferenciais (`hdmi_serializer.v`)

Cada canal de cor são 10 bits por pixel, a 25.2 MHz → **252 Mbit/s** por canal. Para mandar isso por um único par de fios usamos a primitiva **OSER10** (serializador 10:1 em DDR, a 126 MHz) e o buffer **ELVDS_OBUF**, que transforma o sinal em um **par diferencial** (dois fios com sinais opostos) — o jeito que o HDMI espera receber. O canal de clock envia o padrão fixo `1111100000`.

> Estas são primitivas **específicas da Gowin**: na simulação elas são substituídas por modelos simples (`\`ifdef SIM`), o que permite simular o topo inteiro sem precisar das bibliotecas do fabricante. A lógica genérica (timing, framebuffer, DDS, TMDS) é toda simulável e testada.

---

## 10. O pipeline de vídeo e o alinhamento

Tem uma sutileza importante: a BSRAM tem **1 ciclo de latência** de leitura. Então, quando o `video_timing` produz a posição (x,y), o valor do pixel só sai do framebuffer **um ciclo depois**. Se não cuidarmos disso, a cor sairia "deslocada" e os sincronismos não casariam com a imagem.

A solução é **atrasar** a posição e os sincronismos em 1 ciclo (registradores `_d1`) para casar exatamente com o dado que sai da memória. Alinhar pipeline é o tipo de detalhe que não aparece num diagrama bonito, mas que faz a diferença entre uma imagem perfeita e uma imagem "tremida" — e é exatamente o tipo de coisa que a simulação ajuda a acertar antes de gravar no FPGA.

---

[⬅️ Voltar ao README](../README.md) · [🇬🇧 English version](theory_en.md)
