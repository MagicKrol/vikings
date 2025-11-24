// From http://www.redblobgames.com/maps/mapgen2/
// Copyright 2017 Red Blob Games <redblobgames@gmail.com>
// License: Apache v2.0 <http://www.apache.org/licenses/LICENSE-2.0.html>

import * as util from './util';

const RND_SCALE = 1 << 30;
const makeRandFloat = (randInt) => () => randInt(RND_SCALE) / RND_SCALE;

function placeMacroSeeds(count, mode, randFloat) {
    if (count <= 1) return [[500, 500]];
    const seeds = [];
    if (mode === 'linked') {
        const radius = 240 + randFloat() * 80;
        for (let i = 0; i < count; i++) {
            const angle = (i / count) * Math.PI * 2 + randFloat() * 0.5;
            const jitter = 32 * (randFloat() - 0.5);
            seeds.push([
                500 + Math.cos(angle) * radius + jitter,
                500 + Math.sin(angle) * radius + jitter,
            ]);
        }
    } else {
        const margin = 140;
        const minDist = 220;
        const maxDist = 540;
        let attempts = 0;
        while (seeds.length < count && attempts < count * 30) {
            const x = margin + randFloat() * (1000 - 2 * margin);
            const y = margin + randFloat() * (1000 - 2 * margin);
            const distances = seeds.map(([cx, cy]) => Math.hypot(cx - x, cy - y));
            const ok = distances.every((d) => d > minDist) && distances.every((d) => d < maxDist);
            if (ok) seeds.push([x, y]);
            attempts++;
        }
        if (!seeds.length) seeds.push([500, 500]);
    }
    return seeds;
}

function landComponents(mesh, water_r) {
    const seen = new Uint8Array(mesh.numRegions);
    const r_out = [];
    const components = [];
    for (let r = 0; r < mesh.numRegions; r++) {
        if (seen[r] || water_r[r] || mesh.is_ghost_r(r)) continue;
        const stack = [r];
        const comp = [];
        seen[r] = 1;
        while (stack.length) {
            const cur = stack.pop();
            comp.push(cur);
            mesh.r_around_r(cur, r_out);
            for (let n of r_out) {
                if (seen[n] || water_r[n] || mesh.is_ghost_r(n)) continue;
                seen[n] = 1;
                stack.push(n);
            }
        }
        components.push(comp);
    }
    return components;
}

function connectToMainLand(mesh, water_r, components, opts, randFloat) {
    if (components.length <= 1) return;
    const totalLand = components.reduce((sum, c) => sum + c.length, 0);
    components.sort((a, b) => b.length - a.length);

    const main = components[0];
    const mainSet = new Set(main);
    const tinyCutoff = opts.minLandFraction ?? 0.003;
    const maxBridgeLength = opts.maxBridgeLength ?? 260;
    const bridgeRadius = opts.bridgeRadius ?? 3;

    const r_out = [];

    for (let i = 1; i < components.length; i++) {
        const comp = components[i];
        const fraction = comp.length / totalLand;
        if (fraction < tinyCutoff) {
            for (let r of comp) water_r[r] = true; // remove micro-islands
            continue;
        }

        const queue = comp.slice();
        const prev = new Int32Array(mesh.numRegions);
        prev.fill(-1);
        const visited = new Uint8Array(mesh.numRegions);
        for (let r of queue) visited[r] = 1;
        let goal = -1, qi = 0;

        while (qi < queue.length && goal < 0) {
            const cur = queue[qi++];
            mesh.r_around_r(cur, r_out);
            for (let n of r_out) {
                if (mesh.is_ghost_r(n) || visited[n]) continue;
                visited[n] = 1;
                prev[n] = cur;
                if (mainSet.has(n)) { goal = n; break; }
                queue.push(n);
            }
        }

        if (goal < 0) continue;

        // measure bridge length
        let length = 0;
        for (let r = prev[goal]; r !== -1 && !mainSet.has(r); r = prev[r]) length++;
        if (length > maxBridgeLength) {
            // too far; flood to sea
            for (let r of comp) water_r[r] = true;
            continue;
        }

        // carve a short corridor with some thickness
        let r = prev[goal];
        while (r !== -1 && !mainSet.has(r)) {
            const queue2 = [[r, 0]];
            const seenLocal = new Set();
            while (queue2.length) {
                const [cur, depth] = queue2.shift();
                if (seenLocal.has(cur)) continue;
                seenLocal.add(cur);
                water_r[cur] = false;
                mainSet.add(cur);
                main.push(cur);
                if (depth >= bridgeRadius) continue;
                mesh.r_around_r(cur, r_out);
                for (let n of r_out) {
                    if (mesh.is_ghost_r(n) || seenLocal.has(n)) continue;
                    if (!water_r[n]) continue;
                    if (depth > 0 && randFloat() < 0.25) continue;
                    queue2.push([n, depth + 1]);
                }
            }
            r = prev[r];
        }

        for (let land of comp) {
            if (!mainSet.has(land)) {
                mainSet.add(land);
                main.push(land);
            }
        }
    }
}

export function assign_water_r(
    water_r,
    mesh,
    noise,
    params,
    randInt = (n) => Math.floor(Math.random() * n)
) {
    const {
        round = 0.5,
        inflate = 0.4,
        amplitudes = [1/2, 1/4, 1/8, 1/16],
        mode = 'continent',       // continent | linked
        continents = 1,
        macroSeeds = null,        // overrides continents if set
        connect = true,           // keep land graph connected
        inlandSea = 0.0,          // carve interior water
        bridgeBias = 0.45,        // raises elevation along connectors
        minLandFraction = 0.003,  // remove micro land pieces
        splitBias = 0.0,          // encourage channels between centers
        maxBridgeLength = 260,
        bridgeRadius = 3,
        lakeFrequency = 0,
        lakeSize = 2,
        landFraction = 0.6,       // target land coverage
        warpStrength = 0.2,
        warpScale = 0.8,
        seawayFrequency = 0.0,
        seed = 0,
    } = params || {};

    const randFloat = makeRandFloat(randInt);
    const seedCount = Math.max(1, macroSeeds || continents);
    const centers = placeMacroSeeds(seedCount, mode, randFloat);
    const score_r = new Array(mesh.numRegions).fill(-Infinity);

    // Precompute link pairs for seaways
    const seawayPairs = [];
    if (centers.length > 1 && seawayFrequency > 0) {
        for (let i = 0; i < centers.length; i++) {
            seawayPairs.push([i, (i + 1) % centers.length]);
        }
    }

    water_r.length = mesh.numRegions;
    for (let r = 0; r < mesh.numRegions; r++) {
        if (mesh.is_ghost_r(r) || mesh.is_boundary_r(r)) {
            water_r[r] = true;
            continue;
        }
        const x = mesh.x_of_r(r);
        const y = mesh.y_of_r(r);

        // domain warp to fracture coasts
        const warpX = warpStrength * 80 * util.fbm_noise(noise, [1/2, 1/3], x/1000*warpScale + 11.3, y/1000*warpScale - 7.1);
        const warpY = warpStrength * 80 * util.fbm_noise(noise, [1/2, 1/3], x/1000*warpScale - 5.7, y/1000*warpScale + 9.9);

        let maxScore = -Infinity;
        let sumExp = 0;
        let nearest = Infinity, second = Infinity;

        for (let i = 0; i < centers.length; i++) {
            const [cx, cy] = centers[i];
            const nx = (x + warpX - cx) / 500;
            const ny = (y + warpY - cy) / 500;
            const distance = Math.max(Math.abs(nx), Math.abs(ny));
            const distAbs = Math.hypot(x - cx, y - cy);
            if (distAbs < nearest) { second = nearest; nearest = distAbs; }
            else if (distAbs < second) { second = distAbs; }

            const n = util.fbm_noise(noise, amplitudes, nx + seed*0.01, ny - seed*0.01);
            const shaped = util.lerp(n, 0.5, round);
            const score = shaped - (1.0 - inflate) * distance * distance;

            // log-sum-exp accumulate
            if (score > maxScore) {
                sumExp = sumExp * Math.exp(maxScore - score) + 1;
                maxScore = score;
            } else {
                sumExp += Math.exp(score - maxScore);
            }
        }

        const combined = maxScore + Math.log(sumExp);
        let finalScore = combined;

        if (inlandSea > 0) {
            const nx = (x - 500) / 500;
            const ny = (y - 500) / 500;
            const sea = (util.fbm_noise(noise, [1/2, 1/4], nx * 0.7 + 3.1, ny * 0.7 - 6.7) + 1) * 0.5;
            finalScore -= inlandSea * sea;
        }

        if (centers.length > 1 && splitBias > 0 && second < Infinity) {
            const closeness = util.clamp(1 - (second - nearest) / (second + 1e-6), 0, 1);
            finalScore -= splitBias * closeness;
        }

        score_r[r] = finalScore;
    }

    // seaways carved after scoring to break large flats
    if (seawayPairs.length && seawayFrequency > 0) {
        const corridorWidth = 55 + 30 * seawayFrequency;
        for (let [i, j] of seawayPairs) {
            if (randFloat() > seawayFrequency) continue;
            const [ax, ay] = centers[i];
            const [bx, by] = centers[j];
            for (let r = 0; r < mesh.numRegions; r++) {
                if (mesh.is_ghost_r(r) || mesh.is_boundary_r(r)) continue;
                const x = mesh.x_of_r(r), y = mesh.y_of_r(r);
                const abx = bx - ax, aby = by - ay;
                const len2 = abx*abx + aby*aby;
                const t = len2 === 0 ? 0 : ((x-ax)*abx + (y-ay)*aby) / len2;
                const clamped = util.clamp(t, 0, 1);
                const px = ax + clamped*abx, py = ay + clamped*aby;
                const d = Math.hypot(x - px, y - py);
                const channel = util.clamp(1 - d / corridorWidth, 0, 1);
                score_r[r] -= channel * 0.6;
            }
        }
    }

    // set sea level to hit target land fraction
    const interior = [];
    for (let r = 0; r < mesh.numRegions; r++) {
        if (mesh.is_ghost_r(r) || mesh.is_boundary_r(r)) continue;
        interior.push(score_r[r]);
    }
    if (interior.length) {
        interior.sort((a, b) => a - b);
        const idx = Math.max(0, Math.min(interior.length - 1, Math.floor((1 - landFraction) * interior.length)));
        const seaLevel = interior[idx];
        for (let r = 0; r < mesh.numRegions; r++) {
            if (mesh.is_ghost_r(r) || mesh.is_boundary_r(r)) {
                water_r[r] = true;
            } else {
                water_r[r] = score_r[r] < seaLevel;
            }
        }
    }

    // connectivity cleanup
    if (connect) {
        const components = landComponents(mesh, water_r);
        connectToMainLand(
            mesh,
            water_r,
            components,
            {minLandFraction, maxBridgeLength, bridgeRadius},
            randFloat
        );
    }

    // carve lakes to break up large flats
    if (lakeFrequency > 0) {
        const lakeRadius = Math.max(1, Math.round(lakeSize));
        const seeds = [];
        const r_out = [];
        for (let r = 0; r < mesh.numRegions; r++) {
            if (water_r[r] || mesh.is_ghost_r(r) || mesh.is_boundary_r(r)) continue;
            const nx = (mesh.x_of_r(r) - 500) / 500;
            const ny = (mesh.y_of_r(r) - 500) / 500;
            const n = (util.fbm_noise(noise, [1/2, 1/4, 1/8], nx * 0.9 + 7.1, ny * 0.9 - 13.3) + 1) * 0.5;
            if (n < lakeFrequency) seeds.push(r);
        }
        util.randomShuffle(seeds, randInt);
        const seen = new Uint8Array(mesh.numRegions);
        for (let seed of seeds) {
            if (seen[seed]) continue;
            const queue = [[seed, 0]];
            seen[seed] = 1;
            while (queue.length) {
                const [cur, dist] = queue.shift();
                water_r[cur] = true;
                if (dist >= lakeRadius) continue;
                mesh.r_around_r(cur, r_out);
                for (let n of r_out) {
                    if (water_r[n] || seen[n] || mesh.is_ghost_r(n)) continue;
                    seen[n] = 1;
                    queue.push([n, dist + 1]);
                }
            }
        }
    }

    return water_r;
}


/* a region is ocean if it is a water region connected to the ghost region,
   which is outside the boundary of the map; this could be any seed set but
   for islands, the ghost region is a good seed */
export function assign_ocean_r(ocean_r, mesh, water_r) {
    ocean_r.length = mesh.numRegions;
    ocean_r.fill(false);
    let stack = [mesh.r_ghost()];
    let r_out = [];
    while (stack.length > 0) {
        let r1 = stack.pop();
        mesh.r_around_r(r1, r_out);
        for (let r2 of r_out) {
            if (water_r[r2] && !ocean_r[r2]) {
                ocean_r[r2] = true;
                stack.push(r2);
            }
        }
    }
    return ocean_r;
};
