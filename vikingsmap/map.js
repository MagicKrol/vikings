/*
 * From http://www.redblobgames.com/maps/mapgen2/
 * Copyright 2017 Red Blob Games <redblobgames@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *      http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import * as util       from './util';
import * as Water      from './water';
import * as Elevation  from './elevation';
import * as Rivers     from './rivers';
import * as Moisture   from './moisture';
import * as Biomes     from './biomes';
import * as NoisyEdges from './noisy-edges';

/**
 * Map generator
 *
 * Map coordinates are 0 ≤ x ≤ 1000, 0 ≤ y ≤ 1000.
 *
 * mesh: TriangleMesh
 * noisyEdgeOptions: {length, amplitude, seed}
 * makeRandInt: function(seed) -> function(N) -> an int from 0 to N-1
 */
export class WorldMap {
    constructor(mesh, noisyEdgeOptions, makeRandInt) {
        this.mesh = mesh;
        this.makeRandInt = makeRandInt;
        this.lines_s = NoisyEdges.assign_lines_s(
            [],
            this.mesh,
            noisyEdgeOptions,
            this.makeRandInt(noisyEdgeOptions.seed)
        );

        this.water_r = [];
        this.ocean_r = [];
        this.coastdistance_t = [];
        this.elevation_t = [];
        this.s_downslope_t = [];
        this.elevation_r = [];
        this.flow_s = [];
        this.waterdistance_r = [];
        this.moisture_r = [];
        this.coast_r = [];
        this.temperature_r = [];
        this.biome_r = [];
    }

    calculate(options) {
        options = Object.assign({
            noise: null, // required: function(nx, ny) -> number from -1 to +1
            shape: {round: 0.5, inflate: 0.4, amplitudes: [1/2, 1/4, 1/8, 1/16]},
            numRivers: 30,
            drainageSeed: 0,
            riverSeed: 0,
            noisyEdge: {length: 1, amplitude: 0.2, seed: 0},
            biomeBias: {north_temperature: 0, south_temperature: 0, moisture: 0},
            elevation: { landGamma: 1.0 },
            biome: {
              coastalMoisture: 0.6,     // how strong coasts act as humid sources
              coastStart: 1,            // BFS starting distance for coast seeds
              coastExponent: 0.4,       
              tempElevWeight: 0.4,      // <1.0 weakens “mountains = cold”
              tempElevGamma: 1.0,
              moistureJitter: 0.4,      // add randomness
              temperatureJitter: 0.2,
              jitterScale: 1.5
            }
        }, options);

        options.shape = Object.assign({
            mode: 'continent',
            continents: 1,
            connect: true,
            inlandSea: 0,
            bridgeBias: 0.45,
            splitBias: 0.0,
            maxBridgeLength: 260,
            bridgeRadius: 3,
            lakeFrequency: 0,
            lakeSize: 2,
            minLandFraction: 0.003,
            landFraction: 0.5,
            macroSeeds: 1,
            warpStrength: 0.0,
            warpScale: 1.0,
            seawayFrequency: 0.0,
        }, options.shape);

        options.elevation = Object.assign({
            landGamma: 1.0,
            ridgeStrength: 0.0,
            ridgeScale: 1.2,
            ridgeSharpness: 1.15,
            mountainDensity: 0.25,
            peakBumps: null,
            ridgeCount: 3,
            valleyStrength: 0.0,
        }, options.elevation);
        if (!options.elevation.noise && options.noise) {
            options.elevation.noise = options.noise;
        }

        options.biome = Object.assign({
            coastalMoisture: 0.6,
            coastStart: 1,
            coastExponent: 0.4,
            tempElevWeight: 0.4,
            tempElevGamma: 1.0,
            moistureJitter: 0.4,
            temperatureJitter: 0.2,
            jitterScale: 1.5,
            reduceForests: false,
        }, options.biome);

        // --- Water + elevation ---
        const shapeSeed = options.shape.seed ?? options.drainageSeed ?? 0;
        Water.assign_water_r(
            this.water_r,
            this.mesh,
            options.noise,
            options.shape,
            this.makeRandInt(shapeSeed)
        );
        Water.assign_ocean_r(this.ocean_r, this.mesh, this.water_r);
        
        Elevation.assign_elevation_t(
            this.elevation_t, this.coastdistance_t, this.s_downslope_t,
            this.mesh,
            this.ocean_r, this.water_r, this.makeRandInt(options.drainageSeed),
            options.elevation   
        );
        if (options.elevation.landGamma === 1.0) {
            Elevation.redistribute_elevation_t(this.elevation_t, this.mesh);
        }
        Elevation.assign_elevation_r(this.elevation_r, this.mesh, this.elevation_t, this.ocean_r);

        // --- Rivers ---
        this.t_spring = Rivers.find_t_spring(this.mesh, this.water_r, this.elevation_t);
        util.randomShuffle(this.t_spring, this.makeRandInt(options.riverSeed));
        this.t_river = this.t_spring.slice(0, options.numRivers);
        Rivers.assign_flow_s(this.flow_s, this.mesh, this.s_downslope_t, this.t_river);

        // --- Moisture ---
        const freshSeeds = Moisture.find_moisture_r_seeds(this.mesh, this.flow_s, this.ocean_r, this.water_r);
        const coastSeeds = (options.biome.coastalMoisture > 0)
          ? Moisture.find_coastland_r(this.mesh, this.ocean_r, this.water_r)
          : null;

        Moisture.assign_moisture_r(
            this.moisture_r, this.waterdistance_r,
            this.mesh,
            this.water_r, freshSeeds,
            coastSeeds ? {
              coastSeeds,
              coastStart: options.biome.coastStart,
              exponent: options.biome.coastExponent
            } : undefined
        );
        Moisture.redistribute_moisture_r(
            this.moisture_r, this.mesh, this.water_r,
            options.biomeBias.moisture, 1 + options.biomeBias.moisture
        );

        // --- Temperature + Biomes ---
        Biomes.assign_coast_r(this.coast_r, this.mesh, this.ocean_r, this.water_r);
        Biomes.assign_temperature_r(
            this.temperature_r,
            this.mesh,
            this.elevation_r,
            options.biomeBias.north_temperature,
            options.biomeBias.south_temperature,
            {
              elevWeight: options.biome.tempElevWeight,
              elevGamma: options.biome.tempElevGamma
            }
        );
        Biomes.assign_biome_r(
            this.biome_r,
            this.mesh,
            this.ocean_r, this.water_r, this.coast_r,
            this.temperature_r, this.moisture_r,
            options.noise,
            {
              moistureJitter: options.biome.moistureJitter,
              temperatureJitter: options.biome.temperatureJitter,
              jitterScale: options.biome.jitterScale
            }
        );

        if (options.biome.reduceForests) {
            const reduceOpts = (options.biome.reduceForests === true) ? {} : options.biome.reduceForests;
            Biomes.reduce_forest_clusters(
                this.biome_r, this.mesh, this.elevation_r, options.noise,
                Object.assign({
                    density: 0.70,      // lower = fewer forests
                    scale: 1.8,         // cluster size
                    sharpness: 1.35,    // blob edges
                    elevPenalty: 0.35,  // fewer forests near mountains
                    hill: 0.60,
                    mountain: 0.75,
                }, reduceOpts)
            );
        }
    }
}
