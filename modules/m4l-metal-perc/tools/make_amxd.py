"""Verpackt metal_perc.maxpat als Max-for-Live-Instrument (.amxd, nicht eingefroren).

    python3 tools/make_amxd.py metal_perc.maxpat "Metal Perc.amxd"

Aufbau einer .amxd-Datei: Chunks aus 4-Byte-Kennung + 4-Byte-Länge (little endian)
  "ampf" (4) -> Gerätetyp "iiii" (Instrument)
  "meta" (4) -> 0
  "ptch" (n) -> Patcher-JSON
Das JSON ist dasselbe wie im .maxpat. seq_random.js wird nicht eingebettet und muss im selben
Ordner liegen. Nach dem ersten Öffnen in Live: Freeze Device, dann ist alles in einer Datei.
"""
import struct
import sys


def chunk(tag, payload):
    return tag + struct.pack("<I", len(payload)) + payload


def make_amxd(patch_json: bytes, device_type: bytes = b"iiii") -> bytes:
    return (chunk(b"ampf", device_type)
            + chunk(b"meta", struct.pack("<I", 0))
            + chunk(b"ptch", patch_json + b"\n\x00"))


def main():
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, "rb") as f:
        data = make_amxd(f.read())
    with open(dst, "wb") as f:
        f.write(data)
    print(f"{dst}: {len(data)} Bytes")


if __name__ == "__main__":
    main()
