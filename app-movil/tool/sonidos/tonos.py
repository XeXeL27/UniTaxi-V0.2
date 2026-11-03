"""Aviso de nuevo servicio (arpegio de campana, dos veces) y confirmacion corta (dos notas)."""
import math, struct, sys, wave
SR = 44100

def campana(f, t, decae):
    # Parciales de campana pequena: fundamental, octava y un parcial inarmonico brillante.
    env = math.exp(-t / decae) * min(1.0, t / 0.004)
    return env * (math.sin(2*math.pi*f*t) + 0.45*math.sin(2*math.pi*2*f*t)*math.exp(-t/(decae*0.5))
                  + 0.25*math.sin(2*math.pi*2.76*f*t)*math.exp(-t/(decae*0.3)))

def marimba(f, t, decae):
    env = math.exp(-t / decae) * min(1.0, t / 0.003)
    return env * (math.sin(2*math.pi*f*t) + 0.3*math.sin(2*math.pi*4*f*t)*math.exp(-t/(decae*0.25)))

def render(notas, dur, ruta, instrumento):
    n = int(SR*dur); out = [0.0]*n
    for inicio, f, decae, vol in notas:
        a = int(inicio*SR)
        for i in range(a, n):
            t = (i-a)/SR
            if t > decae*7: break
            out[i] += vol*instrumento(f, t, decae)
    for i in range(n):
        t = i/SR
        if t > dur-0.05: out[i] *= max(0.0, (dur-t)/0.05)
    pico = max(abs(v) for v in out)
    with wave.open(ruta, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(v/pico*0.9*32767)) for v in out))

arpegio = [880.0, 1108.73, 1318.51, 1760.0]
notas = []
for r, base in enumerate([0.0, 0.62]):
    for k, f in enumerate(arpegio):
        notas.append((base + k*0.085, f, 0.22 if k < 3 else 0.38, 0.8 if k < 3 else 1.0))
render(notas, 1.45, 'nuevo_servicio.wav', campana)
render([(0.0, 659.25, 0.07, 0.8), (0.09, 987.77, 0.12, 1.0)], 0.42, 'confirmacion.wav', marimba)
