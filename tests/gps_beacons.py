# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 boredhero
import importlib.util
import pathlib
import unittest

spec = importlib.util.spec_from_file_location('gps_beacons', pathlib.Path(__file__).resolve().parents[1] / 'tools/gps_beacons.py')
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)


class Coordinates(unittest.TestCase):
    def test_corrects_only_position(self):
        original = '{group="farm",role="gps",pos={y=74,x=1784,z=3791,},version=1,}'
        old, changed = tool.correction(original, (1776, 74, 3791))
        self.assertEqual(old, (1784, 74, 3791))
        self.assertEqual(changed, '{group="farm",role="gps",pos={x=1776,y=74,z=3791,},version=1,}')
        self.assertIsNone(tool.correction(changed, (1776, 74, 3791)))

    def test_ignores_workers(self):
        self.assertIsNone(tool.correction('{role="worker",pos={x=1,y=2,z=3}}', (4, 5, 6)))

    def test_negative_coordinates_and_invalid_position(self):
        self.assertEqual(tool.position('z=-5,x=-3,y=2,'), (-3, 2, -5))
        with self.assertRaises(ValueError):
            tool.correction('{role="gps",pos={x=1,y=2}}', (4, 5, 6))


if __name__ == '__main__':
    unittest.main()
