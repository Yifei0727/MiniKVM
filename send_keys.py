#!/usr/bin/env python3
"""
CH340 + CH9329 USB Serial-to-HID Keyboard Sender for macOS
Default target text: 1234ABCD!@#$TEST
Zero external dependencies (uses standard library termios/os/select).
"""

import argparse
import glob
import os
import select
import sys
import termios
import time

# USB HID Keyboard Modifier: Left Shift = 0x02
SHIFT = 0x02

# USB HID Keyboard Usage IDs (Page 0x07, US QWERTY layout)
CHAR_MAP = {
    # Digits
    '1': (0x00, 0x1E), '2': (0x00, 0x1F), '3': (0x00, 0x20), '4': (0x00, 0x21),
    '5': (0x00, 0x22), '6': (0x00, 0x23), '7': (0x00, 0x24), '8': (0x00, 0x25),
    '9': (0x00, 0x26), '0': (0x00, 0x27),
    # Shifted digits
    '!': (SHIFT, 0x1E), '@': (SHIFT, 0x1F), '#': (SHIFT, 0x20), '$': (SHIFT, 0x21),
    '%': (SHIFT, 0x22), '^': (SHIFT, 0x23), '&': (SHIFT, 0x24), '*': (SHIFT, 0x25),
    '(': (SHIFT, 0x26), ')': (SHIFT, 0x27),
    # Whitespace & control
    '\n': (0x00, 0x28), '\r': (0x00, 0x28), '\t': (0x00, 0x2B), ' ': (0x00, 0x2C),
    # Punctuation
    '-': (0x00, 0x2D), '_': (SHIFT, 0x2D),
    '=': (0x00, 0x2E), '+': (SHIFT, 0x2E),
    '[': (0x00, 0x2F), '{': (SHIFT, 0x2F),
    ']': (0x00, 0x30), '}': (SHIFT, 0x30),
    '\\': (0x00, 0x31), '|': (SHIFT, 0x31),
    ';': (0x00, 0x33), ':': (SHIFT, 0x33),
    '\'': (0x00, 0x34), '"': (SHIFT, 0x34),
    '`': (0x00, 0x35), '~': (SHIFT, 0x35),
    ',': (0x00, 0x36), '<': (SHIFT, 0x36),
    '.': (0x00, 0x37), '>': (SHIFT, 0x37),
    '/': (0x00, 0x38), '?': (SHIFT, 0x38),
}

# Populate a-z and A-Z
for i in range(26):
    ch_lower = chr(ord('a') + i)
    ch_upper = chr(ord('A') + i)
    keycode = 0x04 + i
    CHAR_MAP[ch_lower] = (0x00, keycode)
    CHAR_MAP[ch_upper] = (SHIFT, keycode)

BAUD_MAP = {
    9600: termios.B9600,
    19200: termios.B19200,
    38400: termios.B38400,
    57600: termios.B57600,
    115200: termios.B115200,
}


def build_ch9329_packet(cmd: int, data: bytes = b"", addr: int = 0x00) -> bytes:
    """Builds a standard WCH CH9329 serial frame: 57 AB [ADDR] [CMD] [LEN] [DATA...] [SUM]"""
    frame = bytearray([0x57, 0xAB, addr, cmd, len(data)]) + bytearray(data)
    checksum = sum(frame) & 0xFF
    frame.append(checksum)
    return bytes(frame)


def build_key_packet(modifier: int = 0x00, keycode: int = 0x00, addr: int = 0x00) -> bytes:
    """Builds CMD_SEND_KB_GENERAL_DATA (0x02) with 8-byte HID keyboard report."""
    report = bytes([modifier, 0x00, keycode, 0x00, 0x00, 0x00, 0x00, 0x00])
    return build_ch9329_packet(0x02, report, addr=addr)


def open_serial(port: str, baudrate: int) -> int:
    """Opens a POSIX serial port in raw 8N1 mode without external dependencies."""
    if baudrate not in BAUD_MAP:
        raise ValueError(f"Unsupported baudrate {baudrate}. Choose from {list(BAUD_MAP.keys())}")
    fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    attrs = termios.tcgetattr(fd)
    attrs[0] = 0  # iflag
    attrs[1] = 0  # oflag
    attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL  # cflag
    attrs[3] = 0  # lflag
    attrs[4] = BAUD_MAP[baudrate]  # ispeed
    attrs[5] = BAUD_MAP[baudrate]  # ospeed
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    termios.tcflush(fd, termios.TCIOFLUSH)
    return fd


def read_response(fd: int, timeout: float = 0.12) -> bytes:
    """Reads available bytes from the serial port up to timeout."""
    buf = bytearray()
    deadline = time.time() + timeout
    while time.time() < deadline:
        r, _, _ = select.select([fd], [], [], max(0.005, deadline - time.time()))
        if r:
            try:
                chunk = os.read(fd, 64)
            except BlockingIOError:
                continue
            if chunk:
                buf.extend(chunk)
                if len(buf) >= 5 and len(buf) >= 5 + buf[4] + 1:
                    break
    return bytes(buf)


def probe_ch9329(port: str, candidate_bauds=(9600, 115200)):
    """Probes CH9329 using CMD_GET_INFO (0x01) to auto-detect baudrate and status."""
    info_pkt = build_ch9329_packet(0x01, b"")
    for baud in candidate_bauds:
        fd = None
        try:
            fd = open_serial(port, baud)
            os.write(fd, info_pkt)
            resp = read_response(fd, timeout=0.15)
            if len(resp) >= 14 and resp[0] == 0x57 and resp[1] == 0xAB and resp[3] == 0x81:
                ver = resp[5]
                usb_connected = resp[6] == 0x01
                locks = resp[7]
                return baud, {
                    "version": f"v{ver >> 4}.{ver & 0x0F}",
                    "usb_connected": usb_connected,
                    "num_lock": bool(locks & 0x01),
                    "caps_lock": bool(locks & 0x02),
                    "scroll_lock": bool(locks & 0x04),
                    "raw_response": resp.hex(" ").upper(),
                }
        except (PermissionError, FileNotFoundError):
            raise
        except Exception:
            pass
        finally:
            if fd is not None:
                try:
                    os.close(fd)
                except OSError:
                    pass
    return None, None


def send_text(
    port: str,
    baudrate: int,
    text: str,
    delay: float = 0.02,
    press_enter: bool = False,
    dry_run: bool = False,
):
    """Sends a text string as sequential USB HID key press & release packets."""
    fd = None if dry_run else open_serial(port, baudrate)
    release_pkt = build_key_packet(0x00, 0x00)
    try:
        for idx, ch in enumerate(text):
            if ch not in CHAR_MAP:
                print(f"[!] Skipping unsupported character: {repr(ch)}", file=sys.stderr)
                continue
            modifier, keycode = CHAR_MAP[ch]
            press_pkt = build_key_packet(modifier, keycode)

            if dry_run:
                print(
                    f"  [{idx + 1:02d}/{len(text):02d}] {repr(ch):4s} -> "
                    f"DOWN: {press_pkt.hex(' ').upper()} | UP: {release_pkt.hex(' ').upper()}"
                )
                continue

            # Key down
            os.write(fd, press_pkt)
            resp_down = read_response(fd, timeout=delay)
            time.sleep(delay)

            # Key up (release)
            os.write(fd, release_pkt)
            read_response(fd, timeout=delay)
            time.sleep(delay)

            status_str = resp_down.hex(" ").upper() if resp_down else "sent (no RX ACK)"
            print(
                f"  [{idx + 1:02d}/{len(text):02d}] Sent {repr(ch):4s} -> "
                f"{press_pkt.hex(' ').upper()} ({status_str})"
            )

        if press_enter:
            enter_pkt = build_key_packet(0x00, 0x28)
            if dry_run:
                print(f"  [+] <Enter> -> DOWN: {enter_pkt.hex(' ').upper()} | UP: {release_pkt.hex(' ').upper()}")
            else:
                os.write(fd, enter_pkt)
                time.sleep(delay)
                os.write(fd, release_pkt)
                time.sleep(delay)
                print("  [+] Sent <Enter>")
    finally:
        if fd is not None:
            try:
                os.write(fd, release_pkt)
            except OSError:
                pass
            os.close(fd)


def find_default_port() -> str:
    ports = sorted(glob.glob("/dev/cu.usbserial-*"))
    if "/dev/cu.usbserial-1410" in ports:
        return "/dev/cu.usbserial-1410"
    return ports[0] if ports else "/dev/cu.usbserial-1410"


def main():
    parser = argparse.ArgumentParser(description="Send HID keyboard input via CH340 + CH9329 serial port.")
    parser.add_argument(
        "text",
        nargs="?",
        default="1234ABCD!@#$TEST",
        help="Text string to type on the remote device (default: '1234ABCD!@#$TEST')",
    )
    parser.add_argument(
        "-p", "--port",
        default=find_default_port(),
        help="Serial port path (default: /dev/cu.usbserial-1410)",
    )
    parser.add_argument(
        "-b", "--baud",
        type=int,
        default=None,
        help="Baud rate (e.g. 9600 or 115200; default: auto-probe 9600/115200, fallback to 9600)",
    )
    parser.add_argument(
        "-d", "--delay",
        type=float,
        default=0.02,
        help="Delay in seconds between key down and key up (default: 0.02)",
    )
    parser.add_argument(
        "-e", "--enter",
        action="store_true",
        help="Send an Enter keystroke after the text",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print generated CH9329 HID frames without opening the serial port",
    )
    args = parser.parse_args()

    if args.dry_run:
        print(f"[*] Dry-run mode — generating frames for ({len(args.text)} chars): {args.text}")
        send_text(args.port, args.baud or 9600, args.text, delay=args.delay, press_enter=args.enter, dry_run=True)
        return

    print(f"[*] Target serial port: {args.port}")
    if not os.path.exists(args.port):
        print(f"[!] Error: Serial port {args.port} not found.", file=sys.stderr)
        sys.exit(1)

    baud = args.baud
    if baud is None:
        print("[*] Probing CH9329 baud rate and status (CMD_GET_INFO)...")
        detected_baud, info = probe_ch9329(args.port)
        if detected_baud:
            baud = detected_baud
            print(
                f"[+] Detected CH9329 ({info['version']}) @ {baud} bps | "
                f"Remote USB connected: {info['usb_connected']} | "
                f"CapsLock: {info['caps_lock']}"
            )
            if info["caps_lock"]:
                print("[!] Warning: Remote CapsLock is currently ON; letter case may be inverted on the remote OS.")
        else:
            baud = 9600
            print(f"[!] No CH9329 RX response (or 1-way TX cable); defaulting to {baud} bps (use -b 115200 if needed).")

    print(f"[*] Sending text ({len(args.text)} chars) @ {baud} bps: {args.text}")
    send_text(args.port, baud, args.text, delay=args.delay, press_enter=args.enter)
    print("[+] Done!")


if __name__ == "__main__":
    main()
