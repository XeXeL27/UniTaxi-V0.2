"""Sintesis del arranque de una moto monocilindrica de 4 tiempos (estilo Honda CB110).

Partes: motor de arranque (zumbido con el ritmo de la compresion), primeras explosiones
irregulares, ralenti alto, un acelerón corto y vuelta al ralenti. Cada explosion excita los
resonadores del escape; se suma ruido de combustion y el tic de las valvulas.
Salida: WAV mono 16 bits en argv[1].
"""
import math
import random
import struct
import sys
import wave

SR = 22050
DUR = 2.7
N = int(SR * DUR)
random.seed(110)


def rpm_en(t):
    """Revoluciones del motor (0 mientras solo gira el arranque)."""
    if t < 0.62:
        return 0.0
    puntos = [
        (0.62, 900), (0.72, 1900), (0.85, 2700), (1.00, 2300), (1.15, 1900),
        (1.30, 2000), (1.42, 4600), (1.62, 5000), (1.80, 3000), (2.05, 1900),
        (2.35, 1650), (2.70, 1600),
    ]
    for (t0, r0), (t1, r1) in zip(puntos, puntos[1:]):
        if t0 <= t <= t1:
            u = (t - t0) / (t1 - t0)
            u = u * u * (3 - 2 * u)
            return r0 + (r1 - r0) * u
    return puntos[-1][1]


def acelerador(t):
    """Carga del motor: las explosiones con el acelerador abierto suenan mas fuertes."""
    if 1.38 <= t <= 1.68:
        return 1.0
    if 1.68 < t <= 1.85:
        return 1.0 - (t - 1.68) / 0.17 * 0.6
    if 0.62 <= t <= 0.9:
        return 0.75
    return 0.45


# --- excitacion del escape: un impulso por explosion (una cada dos vueltas)
excitacion = [0.0] * N
ruido_comb = [0.0] * N
tics = [0.0] * N
fase = 0.0
primeras = 0
for n in range(N):
    t = n / SR
    rpm = rpm_en(t)
    if rpm <= 0:
        continue
    fase += rpm / 120.0 / SR * (1 + random.uniform(-0.04, 0.04))
    if fase >= 1.0:
        fase -= 1.0
        primeras += 1
        amp = acelerador(t) * random.uniform(0.82, 1.12)
        # Las primeras explosiones salen mas secas y desparejas.
        if primeras <= 3:
            amp *= random.uniform(1.1, 1.35)
        excitacion[n] += amp
        largo = int(SR * random.uniform(0.006, 0.012))
        for k in range(largo):
            if n + k < N:
                ruido_comb[n + k] += amp * random.uniform(-1, 1) * math.exp(-k / (largo / 3))
        # Tic de valvula a mitad del ciclo.
        m = n + int(SR * 0.5 * 120.0 / max(rpm, 1))
        if m < N:
            tics[m] += 0.12


def resonador(x, f, r, g):
    w = 2 * math.pi * f / SR
    a1, a2 = 2 * r * math.cos(w), -r * r
    y1 = y2 = 0.0
    out = [0.0] * len(x)
    for i, v in enumerate(x):
        y = a1 * y1 + a2 * y2 + g * v
        out[i] = y
        y2, y1 = y1, y
    return out


escape = [0.0] * N
for f, decaimiento_ms, g in [(105, 30, 0.7), (225, 20, 0.85), (430, 12, 0.7), (820, 6, 0.45), (1650, 3, 0.22)]:
    r = math.exp(-1.0 / (SR * decaimiento_ms / 1000.0))
    s = resonador(excitacion, f, r, g * (1 - r) * 6)
    for i in range(N):
        escape[i] += s[i]
hiss = resonador(ruido_comb, 900, 0.93, 0.25)
tic = resonador(tics, 4200, 0.90, 0.3)

# --- motor de arranque: zumbido con la compresion (~6 golpes por segundo)
arranque = [0.0] * N
fase_a = 0.0
for n in range(N):
    t = n / SR
    if t > 0.72:
        break
    envol = min(1.0, t / 0.03) * (1.0 if t < 0.58 else max(0.0, 1 - (t - 0.58) / 0.14))
    comp = 0.5 + 0.5 * math.cos(2 * math.pi * 6.2 * t)
    f = 520 - 120 * comp
    fase_a += f / SR
    onda = math.sin(2 * math.pi * fase_a) + 0.45 * math.sin(4 * math.pi * fase_a) + 0.2 * math.sin(6 * math.pi * fase_a)
    engrane = 0.25 * (1 if (fase_a * 3) % 1 < 0.5 else -1)
    zumbido = random.uniform(-1, 1) * 0.35
    arranque[n] = envol * (0.55 + 0.45 * (1 - comp)) * (0.5 * onda + engrane * 0.3 + zumbido)
# Golpes sordos de la compresion mientras gira el arranque.
golpes = [0.0] * N
t = 0.05
while t < 0.6:
    golpes[int(t * SR)] = 0.35
    t += 1 / 6.2
golpe = resonador(golpes, 120, math.exp(-1 / (SR * 0.02)), 0.012)

salida = []
for n in range(N):
    t = n / SR
    v = escape[n] * 1.0 + hiss[n] * 0.5 + tic[n] + arranque[n] * 0.2 + golpe[n]
    v = math.tanh(v * 1.6)
    if t > DUR - 0.35:
        v *= max(0.0, (DUR - t) / 0.35)
    salida.append(v)
pico = max(abs(v) for v in salida) or 1
with wave.open(sys.argv[1], 'wb') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(b''.join(struct.pack('<h', int(v / pico * 0.95 * 32767)) for v in salida))
