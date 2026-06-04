#!/usr/bin/env bash
# Verify the USB audio codec is properly set up.
# Runs all the diagnostic steps from the README and reports PASS / FAIL.
#
# Usage:  bash scripts/verify-audio.sh
#
# Exits 0 on full PASS, 1 if any check failed.

set -u
pass=0; fail=0

check() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf "  ✓ %s\n" "$name"; pass=$((pass+1))
    else
        printf "  ✗ %s\n" "$name"; fail=$((fail+1))
    fi
}

echo "Sparklers · USB audio codec self-check"
echo "──────────────────────────────────────"

# [1] kernel sees the USB audio device
check "lsusb sees a USB audio device" \
      bash -c "lsusb | grep -iE 'audio|c-media|jmtek|cmedia'"

# [2] ALSA enumerates a USB playback card
check "aplay -l reports a USB card" \
      bash -c "aplay -l 2>&1 | grep -i 'USB'"

# [3] ALSA enumerates a USB capture card
check "arecord -l reports a USB card" \
      bash -c "arecord -l 2>&1 | grep -i 'USB'"

# Find which card is the USB one
USB_CARD=$(aplay -l 2>/dev/null | awk '/USB/ {print $2; exit}' | tr -d ':')
USB_CARD="${USB_CARD:-0}"

# [4] mixer reports speaker control + isn't muted
if amixer -c "$USB_CARD" sget Speaker 2>/dev/null | grep -q "\[on\]"; then
    printf "  ✓ Speaker channel exists on card %s and is not muted\n" "$USB_CARD"
    pass=$((pass+1))
else
    printf "  ⚠ Speaker channel on card %s missing or muted — run: alsamixer -c %s\n" \
        "$USB_CARD" "$USB_CARD"
    fail=$((fail+1))
fi

# [5] sample WAV exists
SAMPLE=/usr/share/sounds/alsa/Front_Center.wav
check "ALSA sample WAV present at $SAMPLE" \
      test -f "$SAMPLE"

# [6] aplay sample WAV via plughw
check "aplay sample WAV via plughw:${USB_CARD},0 (silent test — listen!)" \
      aplay -q -D "plughw:${USB_CARD},0" "$SAMPLE"

# [7] arecord + playback roundtrip
TMP=$(mktemp --suffix=.wav)
trap 'rm -f "$TMP"' EXIT
if arecord -q -D "plughw:${USB_CARD},0" -d 2 -f cd "$TMP" 2>/dev/null \
        && [ -s "$TMP" ]; then
    printf "  ✓ arecord captured to %s (%d bytes)\n" "$TMP" "$(stat -c%s "$TMP")"
    pass=$((pass+1))
else
    printf "  ✗ arecord failed (check mic is plugged + capture not muted)\n"
    fail=$((fail+1))
fi

echo "──────────────────────────────────────"
total=$((pass + fail))
printf "  %d / %d PASS" "$pass" "$total"
if [ "$fail" -eq 0 ]; then
    printf "  —  your codec is ready for AI projects.\n"
    exit 0
else
    printf "  —  see the README's Troubleshooting section.\n"
    exit 1
fi
