#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
phosphor_model.py - Modelo de referencia / Reference model

Reproduz em Python, com a MESMA matematica do hardware (Verilog), o caminho:
   DDS -> tracador (Bresenham + brilho ~ velocidade) -> fosforo -> paleta P31.
Serve para PROVAR o algoritmo e gerar uma PREVIA (.png) sem o FPGA.

Reproduces, in Python and with the SAME math as the hardware, the pipeline
DDS -> plotter (Bresenham + brightness ~ speed) -> phosphor -> P31 palette.
Used to PROVE the algorithm and render a PREVIEW (.png) without the FPGA.

Uso / usage:  python3 phosphor_model.py
"""
import os, math
import numpy as np
from PIL import Image, ImageFilter

FB_W, FB_H = 320, 240
STEP       = 96
INTENS_MAX = 15
SLOW       = 8192               # prescaler do morph (igual SLOW_BITS=13)

HERE = os.path.dirname(os.path.abspath(__file__))
HEX  = os.path.join(HERE, '..', 'src', 'sine_lut.hex')

def load_sine():
    vals = []
    if os.path.exists(HEX):
        for line in open(HEX):
            line = line.strip()
            if line:
                v = int(line, 16)
                vals.append(v - 256 if v >= 128 else v)
    if len(vals) != 256:
        vals = [int(round(120*math.sin(2*math.pi*i/256))) for i in range(256)]
    return vals
SINE = load_sine()

def decode_pattern(p):
    """Mesma decodificacao do signal_gen.v / same decode as signal_gen.v"""
    mode    = 1 if p in (6, 7) else 0
    rx      = 2 if p == 3 else (3 if p in (4, 5) else 1)
    ry      = {1: 2, 2: 3, 3: 3, 4: 4, 5: 5}.get(p, 1)
    wav_tri = (p == 7)
    morph   = (p <= 5)
    return mode, rx, ry, wav_tri, morph

def bright(steps):
    if steps <= 1:  return 15
    if steps <= 2:  return 12
    if steps <= 4:  return 9
    if steps <= 8:  return 6
    if steps <= 16: return 4
    return 2

def palette(I):
    g = (I << 4) | I
    r = 0 if I <= 9  else (I - 9)  * 28
    b = 0 if I <= 12 else (I - 12) * 24
    return min(r, 255), min(g, 255), min(b, 255)

def simulate(pattern, n_samples=9000):
    """Acumula o fosforo de uma figura (estado estavel) e devolve fb 320x240.

    Usamos acumulo por MAXIMO (cada pixel guarda o maior brilho de passagem),
    o que reproduz o regime permanente de um fosforo rapido: o brilho de cada
    ponto fica proporcional a 1/velocidade (eixo Z). O morph e LENTO, entao a
    figura aparece praticamente parada e fechada na previa.
    """
    fb = np.zeros((FB_H, FB_W), dtype=np.uint8)
    mode, rx, ry, wav_tri, morph = decode_pattern(pattern)
    ph_x = ph_y = yt_ph = 0
    slow = morph_off = 0
    sweep = 0
    cur_x, cur_y = 160, 120

    def draw_segment(x0, y0, x1, y1, amt):
        dx = abs(x1 - x0); dy = abs(y1 - y0)
        sx = 1 if x1 > x0 else -1
        sy = 1 if y1 > y0 else -1
        err = dx - dy
        if max(dx, dy) > 48:               # retracao / retrace
            return
        x, y = x0, y0
        while True:
            if 0 <= x < FB_W and 0 <= y < FB_H and amt > fb[y, x]:
                fb[y, x] = amt             # acumulo por MAXIMO / max-accumulate
            if x == x1 and y == y1:
                break
            e2 = 2 * err
            if e2 > -dy: err -= dy; x += sx
            if e2 <  dx: err += dx; y += sy

    for k in range(n_samples):
        ph_x = (ph_x + STEP * rx) & 0xFFFF
        ph_y = (ph_y + STEP * ry) & 0xFFFF
        slow = (slow + 1) % SLOW
        if slow == 0 and morph:
            morph_off = (morph_off + 1) & 0xFF
        if sweep >= 319:
            sweep = 0; yt_ph = 0          # disparo / trigger
        else:
            sweep += 2; yt_ph = (yt_ph + 819) & 0xFFFF

        ax = (ph_x >> 8) & 0xFF
        ay = (ph_y >> 8) & 0xFF
        sx_v = SINE[(ax + (morph_off if morph else 0)) & 0xFF]
        sy_v = SINE[ay]
        ay_yt = (yt_ph >> 8) & 0xFF
        sin_yt = SINE[ay_yt]
        tri_u = (255 - ay_yt) if (yt_ph >> 15) else ay_yt
        tri_s = tri_u * 2 - 128

        if mode == 1:                      # YT
            nx = sweep
            ny = 120 + (tri_s - (tri_s >> 3) if wav_tri else sin_yt - (sin_yt >> 3))
        else:                              # Lissajous
            nx = 160 + sx_v
            ny = 120 + (sy_v - (sy_v >> 3))
        nx = max(0, min(FB_W - 1, nx)); ny = max(0, min(FB_H - 1, ny))

        draw_segment(cur_x, cur_y, nx, ny, bright(max(abs(nx-cur_x), abs(ny-cur_y))))
        cur_x, cur_y = nx, ny
    return fb

def render(fb, glow=True):
    lut = np.array([palette(i) for i in range(16)], dtype=np.uint8)
    up  = np.kron(fb, np.ones((2, 2), dtype=np.uint8))      # 640x480
    rgb = lut[up]
    yy, xx = np.mgrid[0:480, 0:640]
    grid = np.zeros((480, 640), dtype=np.uint8)
    grid[(xx % 64 == 0) | (yy % 64 == 0)] = 34
    grid[(xx == 320) | (yy == 240)] = 70
    grid[(xx < 2) | (xx > 637) | (yy < 2) | (yy > 477)] = 70
    no_trace = (up == 0)
    img = np.zeros((480, 640, 3), dtype=np.uint8)
    img[..., 0] = np.where(no_trace, 0, rgb[..., 0])
    img[..., 1] = np.where(no_trace, grid, np.maximum(rgb[..., 1], grid))
    img[..., 2] = np.where(no_trace, 0, rgb[..., 2])
    out = Image.fromarray(img, 'RGB')
    if glow:
        blur = out.filter(ImageFilter.GaussianBlur(1.4))
        out = Image.blend(out, blur, 0.5)
        out = Image.eval(out, lambda v: min(255, int(v * 1.18)))
    return out

NAMES = ["Lissajous 1:1", "Lissajous 1:2", "Lissajous 1:3", "Lissajous 2:3",
         "Lissajous 3:4", "Lissajous 3:5", "YT senoidal", "YT triangular"]

def main():
    outdir = os.path.join(HERE, '..', 'docs', 'images')
    os.makedirs(outdir, exist_ok=True)
    render(simulate(3, 12000), glow=True).save(os.path.join(outdir, 'preview_lissajous.png'))
    print("salvo preview_lissajous.png")
    montage = Image.new('RGB', (320*4, 240*2), (0, 0, 0))
    for p in range(8):
        im = render(simulate(p), glow=True).resize((320, 240))
        montage.paste(im, ((p % 4)*320, (p // 4)*240))
        print("padrao %d (%s) ok" % (p, NAMES[p]))
    montage.save(os.path.join(outdir, 'preview_patterns.png'))
    print("salvo preview_patterns.png")

if __name__ == '__main__':
    main()
