# Bastion Isles

Fantasy/skypunk strategy prototype: grow a floating hex island, build towers whose powers come
from the biome beneath them, and survive waves of airships. Design: [docs/GDD.md](docs/GDD.md).

## Setup

1. Install **Godot 4.7** (the project uses GDScript).
2. Optional: the island is drawn as plain coloured hexes. Painted tile art can be switched on
   (`TerrainArt.force_colours = false` in `scripts/island/terrain_art.gd`), but it is a
   purchased pack and is **not** in this repository. Buy
   *Painted 2D Terrain Hexes: Basic Set* by David Baumgart on the Unity Asset Store, download it
   through Unity, and copy its PNGs into `assets/third_party/hex_terrain_basic/`:
   - `Tiles/*.png` → `tiles/`
   - `Under/*.png` → `under/`
   - `Decor/*.png` → `decor/`
   - `Samples/<Set Name>/*.png` → `samples/<set_name>/` (lowercase, spaces → `_`,
     e.g. `samples/medieval-fantasy_locations/`)
3. Open the project in Godot and run it (main scene: the main menu).

## Tests

```bash
godot --headless --path . -s tests/hex_math_test.gd
```

Balance simulation (no art needed): `godot --headless --path . -s tests/balance_sim.gd -- 8`
