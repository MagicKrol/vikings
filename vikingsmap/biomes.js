/*
 * From http://www.redblobgames.com/maps/mapgen2/
 * Copyright 2017 Red Blob Games <redblobgames@gmail.com>
 * License: Apache v2.0 <http://www.apache.org/licenses/LICENSE-2.0.html>
 */

import * as util from './util';

function biome(ocean, water, coast, temperature, moisture) {
    if (ocean) {
        return 'OCEAN';
    } else if (water) {
        if (temperature > 0.9) return 'MARSH';
        if (temperature < 0.2) return 'ICE';
        return 'LAKE';
    } else if (temperature < 0.2) {
        if (moisture > 0.50) return 'SNOW';
        else if (moisture > 0.33) return 'TUNDRA';
        else if (moisture > 0.16) return 'BARE';
        else return 'SCORCHED';
    } else if (temperature < 0.4) {
        if (moisture > 0.66) return 'TAIGA';
        else if (moisture > 0.33) return 'SHRUBLAND';
        else return 'TEMPERATE_DESERT';
    } else if (temperature < 0.7) {
        if (moisture > 0.92) return 'TEMPERATE_RAIN_FOREST';
        else if (moisture > 0.75) return 'TEMPERATE_DECIDUOUS_FOREST';
        else if (moisture > 0.16) return 'GRASSLAND';
        else return 'GRASSLAND';
    } else {
        if (moisture > 0.85) return 'TROPICAL_RAIN_FOREST';
        else if (moisture > 0.65) return 'TROPICAL_SEASONAL_FOREST';
        else if (moisture > 0.16) return 'GRASSLAND';
        else return 'GRASSLAND';
    }
}


/**
 * A coast region is land that has an ocean neighbor
 */
export function assign_coast_r(coast_r, mesh, ocean_r, water_r) {
    coast_r.length = mesh.numRegions;
    coast_r.fill(false);
    
    let r_out = [];
    for (let r1 = 0; r1 < mesh.numRegions; r1++) {
        mesh.r_around_r(r1, r_out);
        if (!water_r[r1]) {
            for (let r2 of r_out) {
                if (water_r[r2]) {
                    coast_r[r1] = true;
                    break;
                }
            }
        }
    }
    return coast_r;
};


/**
 * Temperature assignment
 *
 * Temperature is based on elevation and latitude.
 * The normal range is 0.0=cold, 1.0=hot, but it is not 
 * limited to that range, especially when using temperature bias.
 *
 * The northernmost parts of the map get bias_north added to them;
 * the southernmost get bias_south added; in between it's a blend.
 */
export function assign_temperature_r(
  temperature_r,
  mesh,
  elevation_r,
  bias_north, bias_south,
  opts = {} // { elevWeight?: number, elevGamma?: number }
) {
  const elevWeight = opts.elevWeight ?? 1.0; // 1.0 = old behavior
  const elevGamma  = opts.elevGamma  ?? 1.0;

  temperature_r.length = mesh.numRegions;
  for (let r = 0; r < mesh.numRegions; r++) {
    let latitude = mesh.y_of_r(r) / 1000;
    let delta_temperature = util.lerp(bias_north, bias_south, latitude);
    const elevTerm = elevWeight * Math.pow(Math.max(0, elevation_r[r]), elevGamma);
    temperature_r[r] = 1.0 - elevTerm + delta_temperature;
  }
  return temperature_r;
}

// --- Helpers to recognize forest-like biomes ---
function _isForestName(name) {
  if (!name) return false;
  return name === 'TAIGA' || name.indexOf('FOREST') >= 0;
}

/**
 * Reduce forest coverage by converting some forest biomes to GRASSLAND,
 * using clustered noise and an elevation penalty so grasslands form around mountains.
 *
 * @param biome_r        (in/out) array of biome names
 * @param mesh           TriangleMesh
 * @param elevation_r    region elevation [0..1]
 * @param noise          simplex noise (same object used elsewhere)
 * @param opts           { density, scale, sharpness, elevPenalty, hill, mountain }
 */
export function reduce_forest_clusters(
  biome_r, mesh, elevation_r, noise,
  opts = {}
) {
  const density     = (opts.density     ?? 0.35);
  const scale       = (opts.scale       ?? 1.8);
  const sharpness   = (opts.sharpness   ?? 1.4);
  const elevPenalty = (opts.elevPenalty ?? 0.4);
  const hill        = (opts.hill        ?? 0.60);
  const mountain    = (opts.mountain    ?? 0.75);

  const amps = [1/2, 1/4, 1/8];
  const clamp01 = (x) => Math.max(0, Math.min(1, x));

  let totalForests = 0;
  let converted    = 0;

  for (let r = 0; r < mesh.numRegions; r++) {
    if (!_isForestName(biome_r[r])) continue;
    totalForests++;

    const nx = (mesh.x_of_r(r) - 500) / 500;
    const ny = (mesh.y_of_r(r) - 500) / 500;
    const n  = (util.fbm_noise(noise, amps, nx*scale + 13.7, ny*scale - 9.1) + 1) * 0.5;
    const mask = Math.pow(n, sharpness);

    const e = elevation_r[r];
    const t = e <= hill ? 0 : e >= mountain ? 1 : (e - hill) / (mountain - hill);
    const keepThreshold = clamp01(density * (1 - elevPenalty * t));

    if (!(mask < keepThreshold)) {
      biome_r[r] = 'GRASSLAND';
      converted++;
    }
  }

  console.log(
    `[reduce_forest_clusters] forests before: ${totalForests}, converted: ${converted}, kept: ${totalForests - converted}`
  );

  return biome_r;
}



/**
 * Biomes assignment -- see the biome() function above
 */
export function assign_biome_r(
  biome_r,
  mesh,
  ocean_r, water_r, coast_r, temperature_r, moisture_r,
  noise = null,
  opts = {} // { moistureJitter?: number, temperatureJitter?: number, jitterScale?: number }
) {
  const mJ = opts.moistureJitter ?? 0.0;     // 0..1
  const tJ = opts.temperatureJitter ?? 0.0;  // 0..1
  const scale = opts.jitterScale ?? 1.5;

  const lerp = util.lerp;
  const clamp01 = (x) => Math.max(0, Math.min(1, x));
  const amps = [1/2, 1/4, 1/8];

  biome_r.length = mesh.numRegions;
  for (let r = 0; r < mesh.numRegions; r++) {
    let t = temperature_r[r], m = moisture_r[r];
    if (noise && (mJ > 0 || tJ > 0)) {
      const nx = (mesh.x_of_r(r) - 500) / 500;
      const ny = (mesh.y_of_r(r) - 500) / 500;
      const n1 = (util.fbm_noise(noise, amps, nx*scale + 37.1, ny*scale - 12.3) + 1) * 0.5;
      const n2 = (util.fbm_noise(noise, amps, nx*scale - 8.7,  ny*scale + 55.6) + 1) * 0.5;
      m = clamp01(lerp(m, n1, mJ));
      t = clamp01(lerp(t, n2, tJ));
    }
    biome_r[r] = biome(ocean_r[r], water_r[r], coast_r[r], t, m);
  }
  return biome_r;
}

