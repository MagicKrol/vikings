/*
 * From http://www.redblobgames.com/maps/mapgen2/
 * Copyright 2017 Red Blob Games
 * License: Apache v2.0 <http://www.apache.org/licenses/LICENSE-2.0.html>
 */

import { mapRegionToIcon } from './mapping.js';

/** Simple discrete colors for our internal categories */
export const discreteColors = {
    ocean: "#44447a",       // deep blue
    lake: "#336699",        // lake blue
    mountains: "#888888",   // grey
    hills: "#c2b280",       // light brown
    hill_forest: "#5a452a", // dark brown
    forest: "#228b22",      // dark green
    grassland: "#7cfc00",   // light green
};

// fallback smooth coloring for UI toggle
function smoothColoring(e, t, m) {
    if (e < 0.0) {
        return `rgb(${(48 + 48*e) | 0}, ${(64 + 64*e) | 0}, ${(127 + 128*e) | 0})`;
    }
    let white = (1-t) * (1-t);
    m = 1.0 - ((1-m)*(1-m));
    const red = 210 - 100*m, grn = 185 - 45*m, blu = 139 - 45*m;
    return `rgb(${(255 * white + red * (1-white)) | 0}, 
                ${(255 * white + grn * (1-white)) | 0}, 
                ${(255 * white + blu * (1-white)) | 0})`;
}

class Coloring {
    draw_coast_s(map, s) {
        return map.ocean_r[map.mesh.r_begin_s(s)] !== map.ocean_r[map.mesh.r_end_s(s)];
    }
    draw_lakeside_s(map, s) {
        const r0 = map.mesh.r_begin_s(s),
              r1 = map.mesh.r_end_s(s);
        return (map.water_r[r0] !== map.water_r[r1]
                && !map.ocean_r[r0]
                && map.biome_r[r0] !== 'ICE'
                && map.biome_r[r1] !== 'ICE');
    }
    draw_river_s(map, s) {
        const r0 = map.mesh.r_begin_s(s),
              r1 = map.mesh.r_end_s(s);
        return ((map.flow_s[s] > 0 || map.flow_s[map.mesh.s_opposite_s(s)] > 0)
                && !map.water_r[r0] && !map.water_r[r1]);
    }
    biome(_map, _r) {
        return "red";
    }
    side(map, s) {
        const r0 = map.mesh.r_begin_s(s),
              r1 = map.mesh.r_end_s(s);
        if (this.draw_coast_s(map, s)) {
            return { noisy: true, lineWidth: 3, strokeStyle: "#33335a" };
        } else if (this.draw_lakeside_s(map, s)) {
            return { noisy: true, lineWidth: 1.5, strokeStyle: "#225588" };
        } else if (this.draw_river_s(map, s)) {
            return {
                noisy: true,
                lineWidth: 2.0 * Math.sqrt(map.flow_s[s]),
                strokeStyle: "#225588",
            };
        } else {
            return {
                noisy: true,
                lineWidth: 1.0,
                strokeStyle: this.biome(map, r0),
            };
        }
    }
}

export class Discrete extends Coloring {
    biome(map, r) {
        const simplified = mapRegionToIcon(map.biome_r[r], map.elevation_r[r]);
        const color = discreteColors[simplified];
        if (!color) {
            console.warn("Unknown biome:", map.biome_r[r], "->", simplified);
        }
        return color || "#ff00ff"; // magenta fallback
    }
}

export class Smooth extends Coloring {
    biome(map, r) {
        if (map.water_r[r] && !map.ocean_r[r]) {
            return "#336699"; // lake color
        } else {
            return smoothColoring(
                map.elevation_r[r],
                Math.min(1, Math.max(0, map.temperature_r[r])),
                Math.min(1, Math.max(0, map.moisture_r[r]))
            );
        }
    }
}
