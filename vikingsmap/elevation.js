/*
 * From http://www.redblobgames.com/maps/mapgen2/
 * Copyright 2017 Red Blob Games <redblobgames@gmail.com>
 * License: Apache v2.0 <http://www.apache.org/licenses/LICENSE-2.0.html>
 */

import * as util from './util';

function add_peak_bumps(elevation_t, mesh, is_ocean_t, randInt, count, strength, radius) {
  if (count <= 0) return;
  const candidates = [];
  for (let t = 0; t < mesh.numSolidTriangles; t++) {
    if (!is_ocean_t(t)) candidates.push(t);
  }
  if (!candidates.length) return;
  util.randomShuffle(candidates, randInt);

  const visited = new Uint8Array(mesh.numTriangles);
  const queue = [];
  const s_out = [];
  const maxRadius = Math.max(2, radius|0);
  let picked = 0;

  for (let idx = 0; idx < candidates.length && picked < count; idx++) {
    const seed = candidates[idx];
    if (visited[seed]) continue;
    picked++;
    queue.length = 0;
    queue.push([seed, 0]);
    visited[seed] = 1;

    while (queue.length) {
      const [t, dist] = queue.shift();
      const fade = Math.max(0, 1 - dist / maxRadius);
      elevation_t[t] += strength * fade * fade;
      if (dist >= maxRadius) continue;
      mesh.s_around_t(t, s_out);
      for (let s of s_out) {
        const nt = mesh.t_outer_s(s);
        if (visited[nt] || is_ocean_t(nt)) continue;
        visited[nt] = 1;
        queue.push([nt, dist + 1]);
      }
    }
  }
}

/**
 * Coast corners are connected to coast sides, which have
 * ocean on one side and land on the other
 */
function find_t_coasts(mesh, ocean_r) {
    let t_coasts = [];
    for (let s = 0; s < mesh.numSides; s++) {
        let r0 = mesh.r_begin_s(s);
        let r1 = mesh.r_end_s(s);
        let t = mesh.t_inner_s(s);
        if (ocean_r[r0] && !ocean_r[r1]) {
            // It might seem that we also need to check !ocean_r[r0] && ocean_r[r1]
            // and it might seem that we have to add both t and its opposite but
            // each t vertex shows up in *four* directed sides, so we only have to test
            // one fourth of those conditions to get the vertex in the list once.
            t_coasts.push(t);
        }
    }
    return t_coasts;
}


/**
 * Elevation is based on breadth first search from the seed points,
 * which are the coastal graph nodes. Since breadth first search also
 * calculates the 'parent' pointers, return those for use as the downslope
 * graph. To handle lakes, which should have all corners at the same elevation,
 * there are two deviations from breadth first search:
 * 1. Instead of pushing to the end of the queue, push to the beginning.
 * 2. Like uniform cost search, check if the new distance is better than
 *    previously calculated distances. It is possible that one lake corner
 *    was reached with distance 2 and another with distance 3, and we need
 *    to revisit that node and make sure it's set to 2.
 */
export function assign_elevation_t(
  elevation_t, coastdistance_t, s_downslope_t,
  mesh,
  ocean_r, water_r, randInt,
  opts = {}          // <— NEW (optional)
) {
  const {
    landGamma = 1.0,
    oceanGamma = 1.0,     // >1.0 = flatter lowlands
    ridgeStrength = 0.0,  // 0..1 range-ish
    ridgeScale = 1.2,
    ridgeSharpness = 1.15,
    mountainDensity = 0.25,
    peakBumps = null,
    noise = null,
    ridgeCount = 3,
    valleyStrength = 0.0,
  } = opts;

  coastdistance_t.length = mesh.numTriangles;
  s_downslope_t.length = mesh.numTriangles;
  elevation_t.length = mesh.numTriangles;
  coastdistance_t.fill(null);
  s_downslope_t.fill(-1);
  
  const is_ocean_t = (t) => ocean_r[mesh.r_begin_s(3*t)];
  const is_lake_r = (r) => water_r[r] && !ocean_r[r];
  const is_lake_s = (s) => is_lake_r(mesh.r_begin_s(s)) || is_lake_r(mesh.r_end_s(s));

  let s_out = [];
  let t_queue = find_t_coasts(mesh, ocean_r);
  t_queue.forEach((t) => { coastdistance_t[t] = 0; });
  let minDistance = 1, maxDistance = 1;
  
  while (t_queue.length > 0) {
    let t_current = t_queue.shift();
    mesh.s_around_t(t_current, s_out);
    let iOffset = randInt(s_out.length);
    for (let i = 0; i < s_out.length; i++) {
      let s = s_out[(i + iOffset) % s_out.length];
      let lake = is_lake_s(s);
      let neighbor_t = mesh.t_outer_s(s);
      let newDistance = (lake ? 0 : 1) + coastdistance_t[t_current];
      if (coastdistance_t[neighbor_t] === null || newDistance < coastdistance_t[neighbor_t]) {
        s_downslope_t[neighbor_t] = mesh.s_opposite_s(s);
        coastdistance_t[neighbor_t] = newDistance;
        if (is_ocean_t(neighbor_t) && newDistance > minDistance) { minDistance = newDistance; }
        if (!is_ocean_t(neighbor_t) && newDistance > maxDistance) { maxDistance = newDistance; }
        if (lake) t_queue.unshift(neighbor_t); else t_queue.push(neighbor_t);
      }
    }
  }

  // 🔑 Steeper drop-off & more flats via exponent
  coastdistance_t.forEach((d, t) => {
    if (d == null) return; // safety
    const ocean = is_ocean_t(t);
    const denom = ocean ? (minDistance || 1) : (maxDistance || 1);
    let x = d / denom;                // normalize to [0,1]
    x = Math.pow(x, ocean ? oceanGamma : landGamma);
    let elev = ocean ? -x : x;
    elevation_t[t] = elev;
  });

  // multi-ridge overlay
  if (noise && ridgeStrength > 0) {
    const seeds = [];
    for (let t = 0; t < mesh.numSolidTriangles; t++) {
      if (!is_ocean_t(t)) seeds.push(t);
    }
    util.randomShuffle(seeds, randInt);
    const ridgeSeeds = seeds.slice(0, Math.max(1, ridgeCount));

    for (let t = 0; t < mesh.numTriangles; t++) {
      if (is_ocean_t(t)) continue;
      const x = (mesh.x_of_t(t) - 500) / 500;
      const y = (mesh.y_of_t(t) - 500) / 500;
      let maxTerm = -Infinity, sumExp = 0;
      for (let i = 0; i < ridgeSeeds.length; i++) {
        const sIdx = ridgeSeeds[i];
        const sx = (mesh.x_of_t(sIdx) - 500) / 500;
        const sy = (mesh.y_of_t(sIdx) - 500) / 500;
        const dx = x - sx, dy = y - sy;
        const dist = Math.hypot(dx, dy);
        const base = util.fbm_noise(noise, [1/2, 1/4, 1/8], x * ridgeScale + 31.7 + i*3.3, y * ridgeScale - 12.9 - i*4.1);
        const ridged = Math.sign(base) * Math.pow(Math.abs(base), ridgeSharpness);
        const term = ridged - dist * 0.8;
        if (term > maxTerm) {
          sumExp = sumExp * Math.exp(maxTerm - term) + 1;
          maxTerm = term;
        } else {
          sumExp += Math.exp(term - maxTerm);
        }
      }
      const ridgeBoost = ridgeStrength * (maxTerm + Math.log(sumExp)) * Math.max(0, elevation_t[t]);
      elevation_t[t] += ridgeBoost;
    }
  }

  // valleys to cut passes
  if (noise && valleyStrength > 0) {
    for (let t = 0; t < mesh.numTriangles; t++) {
      if (is_ocean_t(t)) continue;
      const nx = (mesh.x_of_t(t) - 500) / 500 * 0.9 + 17.3;
      const ny = (mesh.y_of_t(t) - 500) / 500 * 0.9 - 5.4;
      const val = util.fbm_noise(noise, [1/2, 1/4, 1/8], nx, ny);
      elevation_t[t] -= valleyStrength * val * Math.max(0, elevation_t[t]);
    }
  }

  const bumps = peakBumps === null
    ? Math.max(1, Math.round(mountainDensity * 6))
    : peakBumps;
  if (bumps > 0) {
    const bumpStrength = 0.10 + 0.28 * mountainDensity;
    const bumpRadius = 4 + Math.round(mountainDensity * 4);
    add_peak_bumps(elevation_t, mesh, is_ocean_t, randInt, bumps, bumpStrength, bumpRadius);
  }

  for (let t = 0; t < elevation_t.length; t++) {
    if (elevation_t[t] > 1.25) elevation_t[t] = 1.25;
    if (elevation_t[t] < -1) elevation_t[t] = -1;
  }
}


/** 
 * Set r elevation to the average of the t elevations. There's a
 * corner case though: it is possible for an ocean region (r) to be
 * surrounded by coastline corners (t), and coastlines are set to 0
 * elevation. This means the region elevation would be 0. To avoid
 * this, I subtract a small amount for ocean regions. */
export function assign_elevation_r(elevation_r, mesh, elevation_t, ocean_r) {
    const max_ocean_elevation = -0.01;
    elevation_r.length = mesh.numRegions;
    let t_out = [];
    for (let r = 0; r < mesh.numRegions; r++) {
        mesh.t_around_r(r, t_out);
        let elevation = 0.0;
        for (let t of t_out) {
            elevation += elevation_t[t];
        }
        elevation_r[r] = elevation/t_out.length;
        if (ocean_r[r] && elevation_r[r] > max_ocean_elevation) {
            elevation_r[r] = max_ocean_elevation;
        }
    }
    return elevation_r;
};


/**
 * Redistribute elevation values so that lower elevations are more common
 * than higher elevations. Specifically, we want elevation Z to have frequency
 * (1-Z), for all the non-ocean regions.
 */
// TODO: this messes up lakes, as they will no longer all be at the same elevation
export function redistribute_elevation_t(elevation_t, mesh) {
    // NOTE: This is the same algorithm I used in 2010, because I'm
    // trying to recreate that map generator to some extent. I don't
    // think it's a great approach for other games but it worked well
    // enough for that one.
    
    // SCALE_FACTOR increases the mountain area. At 1.0 the maximum
    // elevation barely shows up on the map, so we set it to 1.1.
    const SCALE_FACTOR = 1.1;

    let t_nonocean = [];
    for (let t = 0; t < mesh.numSolidTriangles; t++) {
        if (elevation_t[t] > 0.0) {
            t_nonocean.push(t);
        }
    }
    
    t_nonocean.sort((t1, t2) => elevation_t[t1] - elevation_t[t2]);

    for (let i = 0; i < t_nonocean.length; i++) {
        // Let y(x) be the total area that we want at elevation <= x.
        // We want the higher elevations to occur less than lower
        // ones, and set the area to be y(x) = 1 - (1-x)^2.
        let y = i / (t_nonocean.length-1);
        // Now we have to solve for x, given the known y.
        //  *  y = 1 - (1-x)^2
        //  *  y = 1 - (1 - 2x + x^2)
        //  *  y = 2x - x^2
        //  *  x^2 - 2x + y = 0
        // From this we can use the quadratic equation to get:
        let x = Math.sqrt(SCALE_FACTOR) - Math.sqrt(SCALE_FACTOR*(1-y));
        if (x > 1.0) x = 1.0;
        elevation_t[t_nonocean[i]] = x;
    }
};
