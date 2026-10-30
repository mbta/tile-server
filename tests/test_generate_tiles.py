import json
import math
import tempfile
import threading
import unittest
from pathlib import Path
from queue import Queue

import mapnik

from etc.generate_tiles import RenderThread, slice_map


class TileRenderingTest(unittest.TestCase):
    def test_web_mercator_projection_and_rendering(self):
        with tempfile.TemporaryDirectory() as directory:
            mapfile = Path(directory) / "map.xml"
            mapfile.write_text(
                '<Map srs="+init=epsg:3857" background-color="white"></Map>'
            )
            renderer = RenderThread(
                directory, str(mapfile), Queue(), threading.Lock(), 1
            )
            point = renderer.transform.forward(mapnik.Coord(-71.06, 42.36))
            self.assertAlmostEqual(point.x, math.radians(-71.06) * 6378137, places=5)
            self.assertAlmostEqual(
                point.y,
                6378137 * math.log(math.tan(math.pi / 4 + math.radians(42.36) / 2)),
                places=5,
            )

            tile = Path(directory) / "tile.png"
            renderer.render_tile(str(tile), 0, 0, 0)
            self.assertTrue(tile.read_bytes().startswith(b"\x89PNG\r\n\x1a\n"))
            image = mapnik.Image.open(str(tile))
            self.assertEqual((image.width(), image.height()), (256, 256))

    def test_map_slices_preserve_coverage(self):
        self.assertEqual(slice_map(1, 0, "bus"), (-71.55, 42.05, -70.6, 42.65))
        self.assertEqual(slice_map(1, 0, "default"), (-72, 41.2, -69.8, 43))
        first = slice_map(2, 0, "default")
        second = slice_map(2, 1, "default")
        self.assertEqual(first[3], second[1])

    def test_style_projections_are_supported(self):
        root = Path(__file__).resolve().parents[1]
        for path in (
            root / "etc/osm-smartrak/style/project.osm2pgsql.mml",
            root / "etc/skate-style/project.osm2pgsql.mml",
        ):
            template = json.loads(path.read_text())
            projection = mapnik.Projection(template["srs"])
            for layer in template["Layer"]:
                with self.subTest(style=path, layer=layer["id"]):
                    transform = mapnik.ProjTransform(
                        mapnik.Projection(layer["srs"]), projection
                    )
                    point = transform.forward(mapnik.Coord(0, 0))
                    self.assertAlmostEqual(point.x, 0)
                    self.assertAlmostEqual(point.y, 0)


if __name__ == "__main__":
    unittest.main()
