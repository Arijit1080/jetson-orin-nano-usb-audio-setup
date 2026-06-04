<h1 align="center">🎙️ USB Audio on Jetson Orin Nano — from scratch</h1>

<p align="center">
  <strong>Tested step-by-step guide for adding a Waveshare USB Audio Adapter (or any CM108/CM119-class USB dongle) to a Jetson Orin Nano.</strong><br>
  No kernel modules · no PulseAudio gymnastics · works in plain ALSA, Python, and Docker.
</p>

<p align="center">
  <em>Companion repo for the YouTube tutorial — every command in this README has been verified on a real Jetson Orin Nano running JetPack 6.2 (L4T R36.4).</em>
</p>

---

## Why this exists

The **Jetson Orin Nano Developer Kit has no audio jacks**. To play a sound or capture a microphone — for a voice assistant, TTS, speech-to-text, or any other AI project — you need to add audio hardware. The cheapest, fastest path is a class-compliant USB audio dongle. The [Waveshare USB Audio Adapter](https://www.waveshare.com/usb-to-audio.htm) (~$5) just works — no drivers, no kernel modules.

This repo walks you through everything from "plug it in" to "Python speaks through it" in about 10 minutes.

---

## What you need

| Item | Notes |
|---|---|
| Jetson Orin Nano (any JetPack 6.x) | Verified on JetPack 6.2, L4T R36.4 |
| **Waveshare USB Audio Adapter** | Or any CM108/CM119-based USB dongle |
| 3.5 mm speaker / headphones | Wired — Bluetooth is a different tutorial |
| 3.5 mm microphone | Optional, if you want input |

Total cost added to the Jetson: **~$5 dongle + whatever speakers you already have.**

---

## 1 · Plug it in

Plug the codec into **any USB-A port** on the Jetson (USB 2.0 is fine — this dongle pulls ~50 mA). Then plug:
- **Speaker / headphones** into the **green** jack
- **Microphone** into the **pink** jack (optional)

---

## 2 · Verify the kernel sees it

```bash
lsusb | grep -iE "audio|c-media|jmtek|cmedia"
```

You should see one of these (same chipset family, different OEM names):
```
Bus 001 Device 004: ID 0c76:1203 JMTek, LLC. USB PnP Audio Device
Bus 001 Device 005: ID 0d8c:0014 C-Media Electronics, Inc. Audio Adapter
```

> **On camera:** mention to viewers that the vendor name may show as **C-Media**, **JMTek**, or **Generic USB Audio** — they're all built around the same CM108 chipset.

For more detail, also check the kernel log:

```bash
sudo dmesg -T | grep -iE 'usb.*sound|c-media|jmtek|audio'
```

The `-T` flag adds timestamps. If `dmesg` shows nothing, **unplug and re-plug the dongle, then run again** — the kernel ring buffer is finite and the original attach message may have scrolled away.

---

## 3 · Confirm ALSA picked it up

```bash
aplay -l        # playback devices
arecord -l      # capture devices
```

Expected:
```
**** List of PLAYBACK Hardware Devices ****
card 0: Device [USB PnP Audio Device], device 0: USB Audio [USB Audio]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 1: HDA [NVIDIA Jetson Orin Nano HDA], device 3: HDMI 0 [HDMI 0]
  ...
```

**`card 0` = USB codec, `card 1` = HDMI.** We'll target card 0 throughout.

> **On camera:** call out that the codec became card 0 because it was plugged in *after* the on-board HDA loaded. This priority can flip if you reboot with the codec already attached.

---

## 4 · Play a test sound

JetPack ships sample WAV files at `/usr/share/sounds/alsa/`:

```bash
aplay -D plughw:0,0 /usr/share/sounds/alsa/Front_Center.wav
```

- `plughw:0,0` = card 0, device 0, with automatic format/rate conversion
- Drop `-D plughw:0,0` after step 7 below

**🔊 You should hear:** a woman's voice saying *"Front Center"*.

If silent, go to [Troubleshooting](#10--troubleshooting).

---

## 5 · Adjust volume with `alsamixer`

```bash
alsamixer -c 0      # -c 0 = card 0 = our USB codec
```

Inside `alsamixer`:
- Arrows → navigate
- ↑ / ↓ → adjust volume
- `M` → toggle mute (`MM` = muted, `00` = unmuted)
- `F6` → switch sound card (sanity check you're on the right one)
- `Esc` → exit

For scripts or YouTube screenshots, use the non-interactive `amixer`:

```bash
amixer -c 0 sget Speaker        # check playback level + mute state
amixer -c 0 sget Mic            # check mic level
amixer -c 0 sset Speaker 80%    # set playback to 80%
amixer -c 0 sset Mic 80% cap    # set capture to 80%, unmute
```

---

## 6 · Test the microphone

Record 5 seconds → play it back through the same dongle:

```bash
arecord -D plughw:0,0 -d 5 -f cd /tmp/test.wav
aplay -D plughw:0,0 /tmp/test.wav
```

**🔊** Speak into the mic during the 5-second window; you'll hear yourself a moment later.

You can verify it's a valid WAV with:

```bash
file /tmp/test.wav
# /tmp/test.wav: RIFF (little-endian) data, WAVE audio, Microsoft PCM, 16 bit, stereo 44100 Hz
```

---

## 7 · Make the USB codec the default

So you don't have to type `-D plughw:0,0` every time. Drop a single config file:

```bash
cp configs/asoundrc-example ~/.asoundrc        # using the file in this repo
# — or write it inline —
cat > ~/.asoundrc <<'EOF'
pcm.!default {
    type plug
    slave.pcm "hw:0,0"
}
ctl.!default {
    type hw
    card 0
}
EOF
```

Now everything that uses default ALSA → goes to the USB codec:

```bash
aplay /usr/share/sounds/alsa/Front_Center.wav     # no -D flag needed
```

---

## 8 · Use it from Python

This is what most viewers actually want. Two demos — both included as scripts in this repo:

### 8a · 440 Hz tone with `sounddevice` ([`scripts/test-tone.py`](scripts/test-tone.py))

```bash
sudo apt install -y portaudio19-dev libportaudio2
pip install sounddevice numpy
python3 scripts/test-tone.py
```

**🔊 You should hear:** a 0.6-second 440 Hz beep.

The key trick is `device="USB PnP Audio Device"` — `sounddevice` does substring matching, so you don't need the exact full name. List everything available with `print(sounddevice.query_devices())`.

### 8b · Real voice with [Piper TTS](https://github.com/rhasspy/piper) ([`scripts/test-piper.py`](scripts/test-piper.py))

```bash
pip install piper-tts

# download a voice (~70 MB)
mkdir -p ~/piper && cd ~/piper
curl -L -O https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium.onnx
curl -L -O https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium.onnx.json
cd -

python3 scripts/test-piper.py ~/piper/en_US-amy-medium.onnx "Hello YouTube, your Jetson can now speak."
```

**🔊 You should hear:** the typed sentence in a clear female voice (or whatever voice you downloaded — Piper has many languages incl. Hindi, Bengali, Tamil, French, German…). [Browse voices](https://github.com/rhasspy/piper/blob/master/VOICES.md).

---

## 9 · Send it through Docker

If your AI app runs in a container (Jarvis, voice agents, etc.), expose the codec in your `docker-compose.yml`:

```yaml
services:
  myapp:
    # ...
    devices:
      - /dev/snd:/dev/snd          # share ALSA devices
    group_add:
      - "29"                       # 'audio' group on JetPack 6.2
```

Inside the container, `sd.query_devices()` returns the same `USB PnP Audio Device` you see on the host. No driver work, no extra config.

---

## 10 · Troubleshooting

| Symptom | Fix |
|---|---|
| `aplay -l` doesn't show the device | Re-seat the dongle. Try a different USB port. Run `sudo dmesg -T \| tail` after re-plugging — you should see the USB attach line. |
| Sound plays through HDMI instead | Use `-D plughw:0,0` explicitly, or write the `~/.asoundrc` from step 7. |
| Sound is silent but no errors | `alsamixer -c 0` → make sure every channel shows `00` (not `MM`) and the volume bars are up. Headphone amplifier sometimes ships muted. |
| Crackling / distorted | Try `-r 48000` instead of `-r 44100`. The CM108 chipset prefers 48 kHz natively. |
| Python: `PortAudioError: Error opening Stream` | `pip install sounddevice` only installs the Python wrapper. You also need `sudo apt install portaudio19-dev libportaudio2`. |
| Docker: no audio in container | Add **both** `devices: - /dev/snd:/dev/snd` **and** `group_add: ["29"]` to your compose file. |
| Multiple USB audio devices | Pass a more specific substring to `device=...` in sounddevice, or use `hw:N,0` where N comes from `aplay -l`. |
| `dmesg` empty | Codec was plugged in before boot — unplug + re-plug, then `sudo dmesg -T \| tail`. |

---

## 🧪 Self-check script

Don't trust the README — run [`scripts/verify-audio.sh`](scripts/verify-audio.sh) on your Jetson and it will exercise every step automatically and report PASS / FAIL:

```bash
bash scripts/verify-audio.sh
```

Expected output:
```
[1] lsusb sees codec                              ✓
[2] aplay -l reports a USB card                   ✓
[3] arecord -l reports a USB card                 ✓
[4] amixer Speaker not muted                      ✓
[5] aplay sample WAV via plughw:0,0               ✓
[6] arecord + playback roundtrip                  ✓
[7] /usr/share/sounds/alsa/ samples present       ✓

  7 / 7 PASS — your codec is ready for AI projects.
```

---

## 📂 Repo layout

```
.
├── README.md                  ← this file
├── scripts/
│   ├── verify-audio.sh        ← run me to self-check the whole setup
│   ├── test-tone.py           ← 440 Hz beep via sounddevice
│   └── test-piper.py          ← Piper TTS demo
└── configs/
    └── asoundrc-example       ← drop in ~/.asoundrc to make USB codec the default
```

---

## 📺 Companion YouTube video

*Link added after publishing.* The video walks through every step on camera, including the "money shot" where the Jetson first speaks.

---

## 📝 License

MIT — copy, fork, modify, use in your own tutorials freely.

## 🙏 Credits

- [Waveshare](https://www.waveshare.com/usb-to-audio.htm) for the dongle
- [Piper TTS](https://github.com/rhasspy/piper) for the voice engine
- NVIDIA for the Orin Nano + JetPack
