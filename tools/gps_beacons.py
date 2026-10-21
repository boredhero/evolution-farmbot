#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 boredhero
"""Audit GPS coordinates against live CC computers through localhost RCON."""
import argparse
import datetime
import pathlib
import re
import shutil
import socket
import struct


class Rcon:
    def __init__(self, properties):
        self.sock = socket.create_connection(('127.0.0.1', int(properties.get('rcon.port', '25575'))), timeout=10)
        self.serial = 0
        self.request(3, properties['rcon.password'])

    def read(self, size):
        data = b''
        while len(data) < size:
            part = self.sock.recv(size - len(data))
            if not part:
                raise RuntimeError('RCON disconnected')
            data += part
        return data

    def request(self, kind, text):
        self.serial += 1
        serial = self.serial
        body = struct.pack('<ii', serial, kind) + text.encode() + b'\0\0'
        self.sock.sendall(struct.pack('<i', len(body)) + body)
        while True:
            size, = struct.unpack('<i', self.read(4))
            if not 10 <= size <= 4 * 1024 * 1024:
                raise RuntimeError('Invalid RCON packet')
            body = self.read(size)
            response_id, response_kind = struct.unpack('<ii', body[:8])
            if response_id == -1:
                raise RuntimeError('RCON authentication failed')
            if response_id == serial and (kind != 3 or response_kind == 2):
                return body[8:-2].decode(errors='replace')

    def command(self, text):
        return self.request(2, text)


def position(text):
    values = dict(re.findall(r'\b([xyz])\s*=\s*(-?\d+)', text))
    if set(values) != {'x', 'y', 'z'}:
        raise ValueError('GPS config needs x, y and z')
    return tuple(int(values[axis]) for axis in 'xyz')


def correction(config, actual):
    if not re.search(r'\brole\s*=\s*["\']gps["\']', config):
        return None
    match = re.search(r'\bpos\s*=\s*\{([^{}]*)\}', config)
    if not match:
        raise ValueError('GPS config has no position')
    previous = position(match[1])
    if previous == actual:
        return None
    x, y, z = actual
    updated = config[:match.start()] + f'pos={{x={x},y={y},z={z},}}' + config[match.end():]
    return previous, updated


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--server-dir', type=pathlib.Path, required=True)
    parser.add_argument('--apply', action='store_true', help='Back up and correct loaded GPS beacons; pause workers first')
    args = parser.parse_args()
    root = args.server_dir.resolve()
    properties = {}
    for line in (root / 'server.properties').read_text().splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            key, value = line.split('=', 1)
            properties[key.strip()] = value.strip()
    world = root / properties.get('level-name', 'world') / 'computercraft/computer'
    rcon = Rcon(properties)
    try:
        listing = rcon.command('computercraft dump')
        live = re.findall(r'^#(\d+)\s*\|\s*([YN])\s*\|\s*(-?\d+),\s*(-?\d+),\s*(-?\d+)\s*$', listing, re.M)
        if not live:
            raise RuntimeError('No loaded computers found; no changes made')
        plans = []
        for number, on, x, y, z in live:
            config = world / number / 'farm/config'
            if not config.is_file():
                continue
            original = config.read_text()
            if not re.search(r'\brole\s*=\s*["\']gps["\']', original):
                continue
            actual = (int(x), int(y), int(z))
            change = correction(original, actual)
            if change:
                previous, updated = change
                print(f'GPS #{number}: {previous} -> {actual}')
                plans.append((number, on, config, original, updated))
            else:
                print(f'GPS #{number}: correct at {actual}')
        print('Only loaded computers are audited. Unloaded beacons cannot be checked.')
        if not args.apply or not plans:
            if plans:
                print('Pause workers, then rerun with --apply to correct these beacons.')
            return
        backup = root / 'farmbot-backups' / ('gps-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
        for number, on, config, original, updated in plans:
            if config.read_text() != original:
                raise RuntimeError(f'GPS #{number} config changed during audit; refusing overwrite')
            dest = backup / number / 'config'
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(config, dest)
            response = rcon.command('computercraft shutdown #' + number)
            if 'Shutdown 1/1' not in response:
                raise RuntimeError(f'Could not stop GPS #{number}; config unchanged')
            temporary = config.with_name('config.gps-tmp')
            temporary.write_text(updated)
            temporary.replace(config)
            if on == 'Y':
                response = rcon.command('computercraft turn-on #' + number)
                if 'Turned on 1/1' not in response:
                    raise RuntimeError(f'GPS #{number} corrected but restart failed')
        print(f'Corrected {len(plans)} beacons. Backups: {backup}')
        print('Recalibrate worker parking spots recorded with the previous incorrect GPS.')
    finally:
        rcon.sock.close()


if __name__ == '__main__':
    main()
