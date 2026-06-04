"""Play a 0.6-second 440 Hz tone through the USB audio codec.

Usage:
    python3 test-tone.py                          # default: USB PnP Audio Device
    python3 test-tone.py "USB Audio"              # match a different substring
    python3 test-tone.py --list                   # list every audio device
"""
import sys
import numpy as np
import sounddevice as sd


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--list":
        print(sd.query_devices())
        return
    target = sys.argv[1] if len(sys.argv) > 1 else "USB PnP Audio Device"

    matches = [d for d in sd.query_devices()
               if target.lower() in d["name"].lower()
               and d["max_output_channels"] > 0]
    if not matches:
        print(f"✗ no playback device matches '{target}'")
        print("  available output devices:")
        for d in sd.query_devices():
            if d["max_output_channels"] > 0:
                print(f"    {d['name']}")
        sys.exit(1)
    print(f"  using: {matches[0]['name']}")

    sr = 44100
    duration_s = 0.6
    freq_hz = 440
    t = np.linspace(0, duration_s, int(sr * duration_s), endpoint=False)
    tone = (0.18 * np.sin(2 * np.pi * freq_hz * t)).astype(np.float32)

    sd.play(tone, samplerate=sr, device=target)
    sd.wait()
    print(f"✓ played {duration_s} s @ {freq_hz} Hz through codec")


if __name__ == "__main__":
    main()
