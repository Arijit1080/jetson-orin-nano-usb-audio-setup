"""Speak any text through the USB audio codec using Piper TTS.

Usage:
    python3 test-piper.py /path/to/voice.onnx "Hello world"
    python3 test-piper.py ~/piper/en_US-amy-medium.onnx "Hello YouTube."

Setup once:
    pip install piper-tts sounddevice numpy
    sudo apt install -y portaudio19-dev libportaudio2
    # download a voice from https://github.com/rhasspy/piper/blob/master/VOICES.md
"""
import sys
from pathlib import Path
import numpy as np
import sounddevice as sd

try:
    from piper import PiperVoice
except ImportError:
    sys.exit("✗ piper-tts not installed — run `pip install piper-tts`")


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)

    voice_path = Path(sys.argv[1]).expanduser()
    text = sys.argv[2]
    device = sys.argv[3] if len(sys.argv) > 3 else "USB PnP Audio Device"

    if not voice_path.exists():
        sys.exit(f"✗ voice file not found: {voice_path}")

    print(f"  voice : {voice_path.name}")
    print(f"  text  : {text!r}")
    print(f"  device: {device}")

    voice = PiperVoice.load(str(voice_path))
    chunks = [np.frombuffer(c.audio_int16_bytes, dtype=np.int16)
              for c in voice.synthesize(text)]
    audio = np.concatenate(chunks)

    sd.play(audio, samplerate=voice.config.sample_rate, device=device)
    sd.wait()
    print(f"✓ spoke {len(audio) / voice.config.sample_rate:.2f} s of audio")


if __name__ == "__main__":
    main()
