#!/usr/bin/env python3
"""Capture a real 320x200 VICE framebuffer from the assembled demo.

Requires VICE x64sc with its binary monitor (VICE 3.6+) and Python 3.
The program is loaded into the emulator, started through its documented
``SYS 4096`` BASIC entry point, and read back from VICE's indexed framebuffer.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import socket
import struct
import subprocess
import time
import zlib

ROOT = Path(__file__).resolve().parents[1]
PROGRAM = ROOT / "build" / "c64_pal_raster_logo_plasma.prg"


def packet(command: int, body: bytes, request_id: int) -> bytes:
    return b"\x02\x02" + struct.pack("<I", len(body)) + struct.pack("<I", request_id) + bytes((command,)) + body


def read_exact(connection: socket.socket, count: int) -> bytes:
    received = bytearray()
    while len(received) < count:
        chunk = connection.recv(count - len(received))
        if not chunk:
            raise RuntimeError("VICE closed the binary-monitor connection")
        received.extend(chunk)
    return bytes(received)


def response(connection: socket.socket, expected_type: int, request_id: int) -> bytes:
    while True:
        header = read_exact(connection, 12)
        if header[:2] != b"\x02\x02":
            raise RuntimeError(f"invalid VICE monitor header: {header.hex()}")
        length = struct.unpack_from("<I", header, 2)[0]
        response_type, error = header[6], header[7]
        received_id = struct.unpack_from("<I", header, 8)[0]
        body = read_exact(connection, length)
        if received_id == request_id:
            if error:
                raise RuntimeError(f"VICE monitor error {error:#x} for command {expected_type:#x}")
            if response_type != expected_type:
                raise RuntimeError(f"VICE returned response {response_type:#x}, expected {expected_type:#x}")
            return body


def load_and_start(port: int) -> None:
    payload = PROGRAM.read_bytes()
    load_address = struct.unpack_from("<H", payload, 0)[0]
    with socket.create_connection(("127.0.0.1", port), timeout=5) as connection:
        connection.settimeout(10)
        request_id = 1
        for offset in range(0, len(payload) - 2, 4096):
            chunk = payload[2 + offset:2 + offset + 4096]
            start = load_address + offset
            body = b"\x00" + struct.pack("<HHB", start, start + len(chunk) - 1, 0) + b"\x00\x00" + chunk
            connection.sendall(packet(0x02, body, request_id))
            response(connection, 0x02, request_id)
            request_id += 1
        command = b"SYS 4096\r"
        connection.sendall(packet(0x72, bytes((len(command),)) + command, request_id))
        response(connection, 0x72, request_id)
        request_id += 1
        connection.sendall(packet(0xAA, b"", request_id))
        response(connection, 0xAA, request_id)


def read_display(port: int) -> tuple[bytes, list[tuple[int, int, int]], int, int]:
    with socket.create_connection(("127.0.0.1", port), timeout=5) as connection:
        connection.settimeout(10)
        connection.sendall(packet(0x84, b"\x01\x00", 1))
        display = response(connection, 0x84, 1)
        connection.sendall(packet(0x91, b"\x01", 2))
        palette_reply = response(connection, 0x91, 2)

    fields = struct.unpack_from("<IHHHHHHBI", display, 0)
    field_length, debug_width, _, x_offset, y_offset, width, height, bits, data_length = fields
    if bits != 8 or data_length != debug_width * fields[2]:
        raise RuntimeError("VICE did not return an indexed framebuffer")
    framebuffer = display[field_length:field_length + data_length]
    cropped = bytearray()
    for y_coord in range(y_offset, y_offset + height):
        start = y_coord * debug_width + x_offset
        cropped.extend(framebuffer[start:start + width])

    count = struct.unpack_from("<H", palette_reply, 0)[0]
    offset = 2
    palette: list[tuple[int, int, int]] = []
    for _ in range(count):
        item_length = palette_reply[offset]
        if item_length != 3:
            raise RuntimeError("VICE returned an unexpected palette item")
        palette.append(tuple(palette_reply[offset + 1:offset + 4]))
        offset += item_length + 1
    return bytes(cropped), palette, width, height


def write_png(path: Path, pixels: bytes, palette: list[tuple[int, int, int]], width: int, height: int) -> None:
    raw = bytearray()
    for row in range(height):
        raw.append(0)
        for color in pixels[row * width:(row + 1) * width]:
            raw.extend(palette[color])

    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), level=9))
        + chunk(b"IEND", b"")
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="output PNG path")
    parser.add_argument("--seconds", type=float, default=2.0, help="runtime delay before capture")
    parser.add_argument("--x64sc", default=shutil.which("x64sc"), help="path to VICE x64sc")
    arguments = parser.parse_args()
    if not arguments.x64sc:
        raise SystemExit("x64sc was not found; install VICE or pass --x64sc PATH")
    subprocess.run(["make"], cwd=ROOT, check=True)
    port = 17650
    process = subprocess.Popen(
        [arguments.x64sc, "-sounddev", "dummy", "-binarymonitor", "-binarymonitoraddress", f"ip4://127.0.0.1:{port}"],
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        time.sleep(1.0)
        if process.poll() is not None:
            raise RuntimeError(f"VICE exited with code {process.returncode}")
        load_and_start(port)
        time.sleep(arguments.seconds)
        write_png(arguments.output, *read_display(port))
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


if __name__ == "__main__":
    main()
