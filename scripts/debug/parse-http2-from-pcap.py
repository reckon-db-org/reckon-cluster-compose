#!/usr/bin/env python3
"""Parse HTTP/2 frames from a pcap of a gRPC session.

Reads the raw TCP stream for the client side (192.168.1.11:50051 ->
host port) and decodes frame headers. Useful for debugging server
flushes that look intact on the wire but aren't surfaced by the
grpc client.

Usage: python3 parse-http2-from-pcap.py <pcap-file>
"""
import struct
import subprocess
import sys
from collections import Counter

FRAME_TYPES = {
    0x0: "DATA",
    0x1: "HEADERS",
    0x2: "PRIORITY",
    0x3: "RST_STREAM",
    0x4: "SETTINGS",
    0x5: "PUSH_PROMISE",
    0x6: "PING",
    0x7: "GOAWAY",
    0x8: "WINDOW_UPDATE",
    0x9: "CONTINUATION",
}


def reassemble(pcap, server_to_client=True):
    """Use tcpdump to dump the raw application bytes for one direction."""
    if server_to_client:
        filt = "src host 192.168.1.11 and src port 50051"
    else:
        filt = "dst host 192.168.1.11 and dst port 50051"
    # -r read file, -nn no names, -x hex (no ascii), -X both
    # We want just the TCP payload bytes — easiest path is to use
    # tshark, but it's not installed locally. Fall back to tcpdump
    # and pull payload bytes manually.
    out = subprocess.run(
        ["tcpdump", "-r", pcap, "-nn", "-x", filt],
        capture_output=True, text=True
    ).stdout
    blob = bytearray()
    for line in out.splitlines():
        # Continuation lines look like "        0x0010:  ..."
        if "0x" in line and ":" in line and " " in line:
            try:
                _, rest = line.split(":", 1)
                hex_groups = rest.strip().split()
                # Each group is up to 4 hex chars = 2 bytes
                for g in hex_groups:
                    for i in range(0, len(g), 2):
                        b = int(g[i:i+2], 16)
                        blob.append(b)
            except Exception:
                continue
    return bytes(blob)


def find_frames(blob, start_offset=0):
    """Skim for plausible HTTP/2 frames in the byte stream.

    HTTP/2 frame: 3B length | 1B type | 1B flags | 4B (R+stream).
    We treat any 9-byte window that yields a sensible (type, length)
    as a frame and try to advance by length+9. Returns a list of
    (stream_id, type_name, length, flags).
    """
    frames = []
    pos = start_offset
    # Skip TCP/IP headers — we have raw payload but it's stitched
    # from many packets without alignment. Best-effort: scan for the
    # HTTP/2 preface ("PRI * HTTP/2.0...") first to anchor.
    preface = b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
    idx = blob.find(preface)
    if idx >= 0:
        pos = idx + len(preface)
    while pos + 9 <= len(blob):
        length = (blob[pos] << 16) | (blob[pos + 1] << 8) | blob[pos + 2]
        ftype = blob[pos + 3]
        flags = blob[pos + 4]
        stream_id = struct.unpack(">I", blob[pos + 5:pos + 9])[0] & 0x7FFFFFFF
        if ftype not in FRAME_TYPES or length > 65536:
            pos += 1
            continue
        frames.append({
            "offset": pos,
            "length": length,
            "type": FRAME_TYPES[ftype],
            "flags": flags,
            "stream_id": stream_id,
        })
        pos += 9 + length
    return frames


def main(pcap):
    print(f"== Server -> Client ==")
    s2c = reassemble(pcap, server_to_client=True)
    print(f"  total payload bytes: {len(s2c)}")
    frames_s2c = find_frames(s2c)
    print(f"  frames parsed: {len(frames_s2c)}")
    counter = Counter((f["type"], f["stream_id"]) for f in frames_s2c)
    for (t, sid), n in counter.most_common():
        print(f"    {t} stream={sid}: {n}")

    print(f"\n== Client -> Server ==")
    c2s = reassemble(pcap, server_to_client=False)
    print(f"  total payload bytes: {len(c2s)}")
    frames_c2s = find_frames(c2s)
    print(f"  frames parsed: {len(frames_c2s)}")
    counter = Counter((f["type"], f["stream_id"]) for f in frames_c2s)
    for (t, sid), n in counter.most_common():
        print(f"    {t} stream={sid}: {n}")

    # Focus on subscribe stream — RPC streams use odd-numbered IDs
    # starting at 1 (client-initiated).
    print(f"\n== Subscribe-stream candidates (s2c, stream-id != 0) ==")
    by_stream = {}
    for f in frames_s2c:
        if f["stream_id"] != 0:
            by_stream.setdefault(f["stream_id"], []).append(f)
    for sid, fs in sorted(by_stream.items()):
        types = Counter(f["type"] for f in fs)
        total_bytes = sum(f["length"] for f in fs)
        print(f"  stream {sid}: {dict(types)} (total {total_bytes} bytes)")

    # Look for RST_STREAM or GOAWAY frames from EITHER side
    print(f"\n== Stream resets / GOAWAYs (both directions) ==")
    for direction, frames in [("s->c", frames_s2c), ("c->s", frames_c2s)]:
        for f in frames:
            if f["type"] in ("RST_STREAM", "GOAWAY"):
                print(f"  [{direction}] {f}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/home/rl/Downloads/grpc-cap.pcap")
