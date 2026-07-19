# Map Generator Parity

The Godot generator is checked against diagnostic fixtures produced by the JavaScript `vikingsmap` implementation.

## Generate a JavaScript fixture

From `/Users/magic/vikings_data/vikingsmap` run:

```bash
./export-diagnostics.sh 187 /Users/magic/vikings/tests/fixtures/mapgen-small-seed-187.diagnostics.json
```

An optional third argument contains normalized generator parameters:

```bash
./export-diagnostics.sh 454911730 /tmp/mapgen-parameters.json '{"size":"M","biomeSeed":424242,"forests":0.75,"hills":0.4,"mountains":0.65,"seaLevel":0.7}'
```

The output uses schema version `1` and includes the fixed mesh, sampled shape/elevation noise, water/ocean flags, elevations, drainage, rivers, moisture, temperature, biomes, final region types, noisy-edge samples, summaries, and the final map export.

Fixtures currently cover default seeds `187` and `1066987705`, plus seed `454911730` with non-default medium-map parameters.

The normalized UI values map to the original JavaScript parameters as follows:

- Forests `0.25..1` maps to rainfall/moisture bias `-0.5..1`.
- Hills `0..1` is an absolute terrain proportion: `0` flattens all land below the hill threshold, and higher values convert approximately that percentage of land regions into hills.
- Mountains `0..1` promotes that proportion of existing hill regions into mountains; `0` guarantees no mountains and it does not change moisture or biome classification.
- Sea level `0..1` maps to the old World sea land-fraction calculation.

The visible Biome seed is serialized as the compatibility `noiseSeed` field and controls the secondary seeded noise stream. Map seed remains the main land-shape seed.

Sea-level flooding is anchored to the processed map at `0.5`. Increasing the value only adds water and decreasing it only reveals water; connectivity and lake cleanup can no longer make submerged regions reappear.

## Run the Godot parity tests

From `/Users/magic/vikings` run:

```bash
godot4 --headless --path . --script tests/mapgen_parity_cli.gd
```

The test compares every diagnostic stage in order and reports the first mismatching path. Calculation values use a `0.00001` tolerance. Mesh and rendered-line coordinates use a `0.0002` tolerance because Godot `Vector2` stores 32-bit floats while JavaScript numbers are 64-bit.

JavaScript unassigned water-distance entries and the ghost-region temperature serialize as `null`. Godot uses internal sentinels for these values; `MapgenDiagnostics` normalizes them only in the diagnostic snapshot.
