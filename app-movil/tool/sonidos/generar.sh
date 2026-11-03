#!/usr/bin/env bash
# Genera los audios de aviso hechos por sintesis (moto_encendiendo, nuevo_servicio, confirmacion) y los
# copia a assets/sonidos y a android res/raw. Necesita python3 y ffmpeg. Si se cambia un audio que ya
# esta publicado, darle OTRO nombre (el sonido de un canal de Android queda fijo al crearlo).
set -euo pipefail
cd "$(dirname "$0")"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
python3 -I moto.py "$TMP/moto.wav"
(cd "$TMP" && python3 -I "$OLDPWD/tonos.py")
ffmpeg -v error -y -i "$TMP/moto.wav" -af "highpass=f=130,equalizer=f=1000:t=q:w=1:g=3,lowpass=f=6000,aecho=0.8:0.5:18:0.18,aresample=44100,volume=9dB,alimiter=limit=0.89:attack=2:release=40" -ac 1 -c:a libmp3lame -b:a 128k "$TMP/moto_encendiendo.mp3"
ffmpeg -v error -y -i "$TMP/nuevo_servicio.wav" -af "alimiter=limit=0.89,volume=-1dB" -ac 1 -c:a libmp3lame -b:a 128k "$TMP/nuevo_servicio.mp3"
ffmpeg -v error -y -i "$TMP/confirmacion.wav" -af "volume=-3dB" -ac 1 -c:a libmp3lame -b:a 128k "$TMP/confirmacion.mp3"
for f in moto_encendiendo nuevo_servicio confirmacion; do
  cp "$TMP/$f.mp3" ../../assets/sonidos/
  cp "$TMP/$f.mp3" ../../android/app/src/main/res/raw/
done
echo "Listo. Revisar la duracion en SonidoAviso (lib/core/sonido.dart) si cambio."
