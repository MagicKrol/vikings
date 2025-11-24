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

import SimplexNoise  from 'simplex-noise';
import Delaunator    from 'delaunator';
import Poisson       from 'poisson-disk-sampling';
import {generateInteriorBoundaryPoints} from "./dual-mesh/create.js";
import {TriangleMesh} from "./dual-mesh/index.js";
import {WorldMap}         from './map.js';
import * as Draw     from './draw';
import * as Colormap from './colormap';
import * as urlUtils from 'url-search-utils';
import {makeRandInt, makeRandFloat} from '@redblobgames/prng';
import {mapRegionToIcon} from './mapping.js';

let defaultUiState = {
    seed: 187,
    variant: 0,
    size: 'medium',
    'noisy-fills': true,
    'noisy-edges': true,
    borders: false,
    icons: true,
    biomes: false,
    lighting: false,
    'north-temperature': 0,
    'south-temperature': 0,
    rainfall: 0,
    canvasSize: 0,
    persistence: 0, /* 0 means "normal" persistence value of 1/2 */
    'coast-band-thickness': 0,
    'water-coast-band-thickness': 0,
    'land-gamma': 1.0,
    'land-shape': 'continent',    // continent | linked
    'mountain-density': 0.35,
};

let uiState = {};
Object.assign(uiState, defaultUiState);

/** Generate boundary points around the edges of the map.

  I normally recommend using generateInteriorBoundaryPoints()
  but for the public version of mapgen2, changing the boundary
  point algorithm makes the maps not match previously generated
  maps. So I am using the older boundary point function here to
  maintain map output compatibility.
 */
function compat_addBoundaryPoints(spacing, size) {
    let N = Math.ceil(size/spacing);
    let points = [];
    for (let i = 0; i <= N; i++) {
        let t = (i + 0.5) / (N + 1);
        let w = size * t;
        let offset = Math.pow(t - 0.5, 2);
        points.push([offset, w], [size-offset, w]);
        points.push([w, offset], [w, size-offset]);
    }
    return points;
}
const COMPATIBILITY_WITH_OLD_MAP_SHAPES = true;

let _mapCache = [];
function getMap(size) {
    const spacing = {
        xxtiny: 80,
        xtiny: 55,
        tiny: 38,
        small: 26,
        medium: 18,
        large: 12.8,
        huge: 9,
    };
    if (!_mapCache[size]) {
        // NOTE: the seeds here are constant so that I can reuse the same
        // mesh and noisy edges for all maps, but you could get more variety
        // by creating a new TriangleMesh object each time
        const bounds = {left: 0, top: 0, width: 1000, height: 1000};
        let points = COMPATIBILITY_WITH_OLD_MAP_SHAPES
            ? compat_addBoundaryPoints(spacing[size], 1000)
            : generateInteriorBoundaryPoints(bounds, spacing[size]);
        let numBoundaryPoints = points.length;
        let generator = new Poisson({
            shape: [bounds.width, bounds.height],
            minDistance: spacing[size],
        }, makeRandFloat(12345));
        for (let p of points) { generator.addPoint(p); }
        points = generator.fill();

        let init = {points, delaunator: Delaunator.from(points), numBoundaryPoints};
        init = TriangleMesh.addGhostStructure(init);
        let mesh = new TriangleMesh(init);

        _mapCache[size] = new WorldMap(
            new TriangleMesh(mesh),
            {amplitude: 0.2, length: 1, seed: 12345},
            makeRandInt
        );
        console.log(`Map size "${size}" has ${_mapCache[size].mesh.numRegions} regions`);
    }
    return _mapCache[size];
}


/**
 * Manage drawing with requestAnimationFrame
 *
 * 1. Each frame call one function from the queue.
 * 2. If the queue empties, stop calling requestAnimationFrame.
 */
const processingPerFrameInMs = 1000/60;
let requestAnimationFrameId = null;
let requestAnimationFrameQueue = [];
function requestAnimationFrameHandler() {
    requestAnimationFrameId = null;
    let timeStart = performance.now();
    while (requestAnimationFrameQueue.length > 0
           && performance.now() - timeStart < processingPerFrameInMs) {
        let f = requestAnimationFrameQueue.shift();
        f();
    }
    if (requestAnimationFrameQueue.length > 0) {
        requestAnimationFrameId = requestAnimationFrame(requestAnimationFrameHandler);
    }
}


/* map icons */
const mapIconsConfig = {left: 9, top: 4, filename: "map-icons.png"};
mapIconsConfig.image = new Image();
mapIconsConfig.image.onload = draw;
mapIconsConfig.image.src = mapIconsConfig.filename;

let _lastUiState = {};
function draw() {
    let map = getMap(uiState.size);
    let noisyEdges = uiState['noisy-edges'],
        borders = uiState['borders'],
        noisyFills = uiState['noisy-fills'];
    
    let canvas = document.getElementById('map');
    let ctx = canvas.getContext('2d');

    let size = Math.min(canvas.parentNode.clientWidth, canvas.parentNode.clientHeight);
    if (size != uiState.canvasSize) {
        // Don't assign to width,height if the size hasn't changed because
        // it will blank out the canvas and we'd like to reuse the previous draw
        uiState.canvasSize = size;
        canvas.style.width = size + 'px';
        canvas.style.height = size + 'px';
        size = 1024;
        if (window.devicePixelRatio && window.devicePixelRatio != 1) {
            size *= window.devicePixelRatio;
        }
        canvas.width = size;
        canvas.height = size;
    }
    
    let noise = new SimplexNoise(makeRandFloat(uiState.seed));
    let persistence = Math.pow(1/2, 1 + uiState.persistence);
    let islandShapeAmplitudes = Array.from({length: 5}, (_,octave) => Math.pow(persistence, octave));
    let biomeBias = {
        north_temperature: uiState['north-temperature'],
        south_temperature: uiState['south-temperature'],
        moisture: uiState.rainfall,
    };
    const clamp01 = (v) => Math.max(0, Math.min(1, v));
    const sizeProfile = {
        xxtiny: {continents: 1, inlandSea: 0.10, mountainBonus: 0.0, land: 0.50, lakes: 0.08},
        xtiny:  {continents: 1, inlandSea: 0.12, mountainBonus: 0.05, land: 0.52, lakes: 0.10},
        tiny:   {continents: 1, inlandSea: 0.18, mountainBonus: 0.08, land: 0.55, lakes: 0.12},
        small:  {continents: 1, inlandSea: 0.24, mountainBonus: 0.10, land: 0.58, lakes: 0.13},
        medium: {continents: 2, inlandSea: 0.30, mountainBonus: 0.14, land: 0.62, lakes: 0.14},
        large:  {continents: 3, inlandSea: 0.36, mountainBonus: 0.22, land: 0.66, lakes: 0.16},
        huge:   {continents: 4, inlandSea: 0.42, mountainBonus: 0.28, land: 0.70, lakes: 0.18},
    };
    const profile = sizeProfile[uiState.size] || sizeProfile.medium;
    const landShapeMode = uiState['land-shape'] || 'continent';
    const continents = (landShapeMode === 'continent') ? 1 : profile.continents;
    const inlandSea = clamp01(profile.inlandSea + Math.max(0, -uiState.persistence) * 0.2 + (landShapeMode === 'linked' ? 0.05 : 0));
    const shapeOptions = {
        round: 0.5,
        inflate: 0.4,
        amplitudes: islandShapeAmplitudes,
        mode: landShapeMode,
        continents,
        connect: true,
        inlandSea,
        bridgeBias: (landShapeMode === 'continent') ? 0.35 : 0.50,
        splitBias: (landShapeMode === 'continent') ? 0.12 : 0.22,
        maxBridgeLength: (landShapeMode === 'continent') ? 260 : 220,
        bridgeRadius: (landShapeMode === 'continent') ? 3 : 5,
        lakeFrequency: (landShapeMode === 'continent') ? profile.lakes : profile.lakes + 0.04,
        lakeSize: 2,
        landFraction: profile.land,
        macroSeeds: (landShapeMode === 'continent') ? 1 : profile.continents,
        warpStrength: (landShapeMode === 'continent') ? 0.15 : 0.25,
        warpScale: 0.9,
        seawayFrequency: (landShapeMode === 'continent') ? 0.05 : 0.12,
        seed: uiState.seed + uiState.variant * 101,
    };
    const requestedMountains = clamp01(uiState['mountain-density']);
    const mountainDensity = clamp01(requestedMountains + profile.mountainBonus);
    const ridgeStrength = 0.16 + 0.90 * mountainDensity;
    const ridgeSharpness = 1.12 + 0.40 * mountainDensity;
    const peakBumps = Math.max(1, Math.round(continents * (2 + mountainDensity * 5)));
    const elevationOptions = {
        landGamma: uiState['land-gamma'],
        ridgeStrength,
        ridgeScale: (landShapeMode === 'continent') ? 1.2 : 1.05,
        ridgeSharpness,
        mountainDensity,
        peakBumps,
        ridgeCount: continents + Math.round(mountainDensity * 4),
        valleyStrength: 0.10 + 0.25 * (1 - mountainDensity),
        noise,
    };
    const thinForests = (uiState.size === 'large' || uiState.size === 'huge');
    let colormap = new Colormap.Discrete();
    let queue = [];
    if ((!noisyEdges || uiState.size === 'large' || uiState.size === 'huge' || uiState.size === 'xxtiny' || uiState.size === 'xtiny')
        && (_lastUiState.seed !== uiState.seed
            || _lastUiState.size !== uiState.size
            || _lastUiState.canvasSize !== uiState.canvasSize)) {
        // Noisy edges are slow enough that it'd be nice to have a
        // quick approximation drawn first, but if the last time we
        // drew something was with the same essential parameters let's
        // reuse the drawing from last time
        queue.push(() => Draw.approximateIslandShape(ctx, 1000, 1000, noise, {round: 0.5, inflate: 0.4, amplitudes: islandShapeAmplitudes.slice(0, 3)}));
        // TODO: the if() test is too convoluted; rewrite that expression
    }
    Object.assign(_lastUiState, uiState);

    queue.push(
        () => map.calculate({
            noise: noise,
            drainageSeed: uiState.variant,
            riverSeed: uiState.variant,
            biomeBias: biomeBias,
            shape: shapeOptions,
            elevation: elevationOptions,
            biome: thinForests ? {
                reduceForests: {
                    density: clamp01(0.65 - 0.20 * mountainDensity),
                    scale: 1.6,
                    sharpness: 1.35,
                    elevPenalty: 0.35,
                }
            } : {},
        }),
        () => {
            Draw.background(ctx, colormap);
            Draw.noisyRegions(ctx, map, colormap, noisyEdges);
            if (borders) { Draw.borders(ctx, map, colormap, noisyEdges); }
            // Draw the rivers early for better user experience
            Draw.rivers(ctx, map, colormap, noisyEdges, true);
        }
    );

    for (let phase = 0; phase < 16; phase++) {
        queue.push(() => Draw.noisyEdges(ctx, map, colormap, noisyEdges, phase));
    }

    // Have to draw the rivers and coastlines again because the noisy
    // edges might overwrite them, and these should take priority over
    // the other noisy edges. Otherwise it leaves little gaps that look
    // ugly when zoomed in.
    // Fill gaps between borders first so rivers & coastlines draw on top
    queue.push(() => Draw.gapEdges(ctx, map, colormap, noisyEdges));
    queue.push(() => Draw.rivers(ctx, map, colormap, noisyEdges, false));
    queue.push(() => Draw.coastlines(ctx, map, colormap, noisyEdges));
    queue.push(() => {
        if (uiState['coast-band-thickness'] > 0) {
            Draw.coastBands(ctx, map, colormap, noisyEdges, uiState['coast-band-thickness']);
        }
        if (uiState['water-coast-band-thickness'] > 0) {
            Draw.waterCoastBands(ctx, map, colormap, noisyEdges, uiState['water-coast-band-thickness']);
        }
    });

    if (noisyFills) {
        queue.push(() => Draw.noisyFill(ctx, 1000, 1000, makeRandInt(12345)));
    }

    if (uiState.icons) {
        queue.push(() => Draw.regionIcons(ctx, map, mapIconsConfig, makeRandInt(uiState.variant)));
    }
    
    if (uiState.lighting) {
        queue.push(() => Draw.lighting(ctx, 1000, 1000, map));
    }

    requestAnimationFrameQueue = queue.map(
        (layer, i) => () => {
            //console.time("layer "+i);
            ctx.save();
            ctx.scale(canvas.width / 1000, canvas.height / 1000);
            layer();
            ctx.restore();
            //console.timeEnd("layer "+i);
        });

    if (!requestAnimationFrameId) {
        requestAnimationFrameId = requestAnimationFrame(requestAnimationFrameHandler);
    }
}


function initUi() {
    function oninput(element) { element.addEventListener('input', getUiState); }
    function onclick(element) { element.addEventListener('click', getUiState); }
    function onchange(element) { element.addEventListener('change', getUiState); }
    document.querySelectorAll("input[type='radio']").forEach(onclick);
    document.querySelectorAll("input[type='checkbox']").forEach(onclick);
    document.querySelectorAll("input[type='number']").forEach(onchange);
    document.querySelectorAll("input[type='range']").forEach(oninput);

    // HACK: on touch devices use touch event to make the slider feel better
    document.querySelectorAll("input[type='range']").forEach((slider) => {
        function handleTouch(e) {
            let rect = slider.getBoundingClientRect();
            let min = parseFloat(slider.getAttribute('min')),
                max = parseFloat(slider.getAttribute('max')),
                step = parseFloat(slider.getAttribute('step')) || 1;
            let value = (e.changedTouches[0].clientX - rect.left) / rect.width;
            value = min + value * (max - min);
            value = Math.round(value / step) * step;
            if (value < min) { value = min; }
            if (value > max) { value = max; }
            slider.value = value;
            slider.dispatchEvent(new Event('input'));
            e.preventDefault();
            e.stopPropagation();
        };
        slider.addEventListener('touchmove', handleTouch, {passive: true});
        slider.addEventListener('touchstart', handleTouch, {passive: true});
    });

    // Extract JSON of current map
    const extractBtn = document.getElementById('extract');
    if (extractBtn) {
        extractBtn.addEventListener('click', () => {
            const map = getMap(uiState.size);
            // Make sure data matches current UI state
            const noise = new SimplexNoise(makeRandFloat(uiState.seed));
            const persistence = Math.pow(1/2, 1 + uiState.persistence);
            const islandShapeAmplitudes = Array.from({length: 5}, (_,octave) => Math.pow(persistence, octave));
            const biomeBias = {
                north_temperature: uiState['north-temperature'],
                south_temperature: uiState['south-temperature'],
                moisture: uiState.rainfall,
            };
            map.calculate({
                noise,
                drainageSeed: uiState.variant,
                riverSeed: uiState.variant,
                biomeBias,
                shape: {round: 0.5, inflate: 0.4, amplitudes: islandShapeAmplitudes},
            });

            const mesh = map.mesh;
            const regions = [];
            const s_out = [];
            for (let r = 0; r < mesh.numSolidRegions; r++) {
                mesh.s_around_r(r, s_out);
                const polygon = [];
                for (let s of s_out) {
                    const t = mesh.t_outer_s(s);
                    polygon.push([mesh.x_of_t(t), mesh.y_of_t(t)]);
                }
                regions.push({
                    id: r,
                    center: [mesh.x_of_r(r), mesh.y_of_r(r)],
                    polygon,
                    biome: mapRegionToIcon(map.biome_r[r], map.elevation_r[r]),
                    elevation: map.elevation_r[r],
                    temperature: map.temperature_r[r],
                    moisture: map.moisture_r[r],
                    water: !!map.water_r[r],
                    ocean: !!map.ocean_r[r],
                    coast: !!map.coast_r[r],
                    edges: [], // to be filled below
                });
            }

            // Build undirected edge list with region mapping and endpoints
            const edges = [];
            const sideToEdgeId = new Array(mesh.numSides).fill(-1);
            for (let s = 0; s < mesh.numSolidSides; s++) {
                const r0 = mesh.r_begin_s(s), r1 = mesh.r_end_s(s);
                if (r0 > r1) { continue; } // process undirected edge once
                const t0 = mesh.t_inner_s(s), t1 = mesh.t_outer_s(s);
                const id = edges.length;
                edges.push({
                    id,
                    start: [mesh.x_of_t(t0), mesh.y_of_t(t0)],
                    end: [mesh.x_of_t(t1), mesh.y_of_t(t1)],
                    region1: r0,
                    region2: r1,
                    region1_center: [mesh.x_of_r(r0), mesh.y_of_r(r0)],
                    region2_center: [mesh.x_of_r(r1), mesh.y_of_r(r1)],
                });
                sideToEdgeId[s] = id;
                sideToEdgeId[mesh.s_opposite_s(s)] = id;
            }

            // Fill region.edge lists using the side→edge mapping
            for (let r = 0; r < mesh.numSolidRegions; r++) {
                mesh.s_around_r(r, s_out);
                regions[r].edges = s_out.map((s) => sideToEdgeId[s]);
            }

            const uniqueSides = (predicate) => {
                const items = [];
                for (let s = 0; s < mesh.numSolidSides; s++) {
                    const r0 = mesh.r_begin_s(s), r1 = mesh.r_end_s(s);
                    if (r0 > r1) { continue; } // undirected once
                    if (!predicate(s, r0, r1)) { continue; }
                    const poly = [];
                    const inner = mesh.t_inner_s(s);
                    poly.push([mesh.x_of_t(inner), mesh.y_of_t(inner)]);
                    const noisy = (map.lines_s && map.lines_s[s]) ? map.lines_s[s] : null;
                    if (noisy) {
                        for (let p of noisy) poly.push([p[0], p[1]]);
                    } else {
                        const outer = mesh.t_outer_s(s);
                        poly.push([mesh.x_of_t(outer), mesh.y_of_t(outer)]);
                    }
                    items.push({side: s, r0, r1, polyline: poly});
                }
                return items;
            };

            const rivers = uniqueSides((s) => (map.flow_s[s] > 0 || map.flow_s[mesh.s_opposite_s(s)] > 0));
            const coasts = uniqueSides((_s, r0, r1) => map.ocean_r[r0] !== map.ocean_r[r1]);

            const exportData = {
                meta: {
                    seed: uiState.seed,
                    variant: uiState.variant,
                    size: uiState.size,
                    persistence: uiState.persistence,
                    biomeBias,
                    noisyEdge: {length: 1, amplitude: 0.2, seed: 12345},
                },
                bounds: {width: 1000, height: 1000},
                regions,
                edges,
                rivers,
                coasts,
            };

            const blob = new Blob([JSON.stringify(exportData)], {type: 'application/json'});
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `mapdata-${uiState.seed}-${uiState.size}.json`;
            document.body.appendChild(a);
            a.click();
            a.remove();
            URL.revokeObjectURL(url);
        });
    }
}

function setUiState() {
    document.getElementById('seed').value = uiState.seed;
    document.getElementById('variant').value = uiState.variant;
    const sizeElement = document.querySelector("input#size-" + uiState.size);
    if (sizeElement) sizeElement.checked = true;
    const landShapeElement = document.querySelector("input#land-shape-" + uiState['land-shape']);
    if (landShapeElement) landShapeElement.checked = true;
    document.querySelector("input#noisy-edges").checked = uiState['noisy-edges'];
    document.querySelector("input#borders").checked = uiState['borders'];
    document.querySelector("input#noisy-fills").checked = uiState['noisy-fills'];
    document.querySelector("input#icons").checked = uiState.icons;
    document.querySelector("input#biomes").checked = uiState.biomes;
    document.querySelector("input#lighting").checked = uiState.lighting;
    document.querySelector("input#north-temperature").value = uiState['north-temperature'];
    document.querySelector("input#south-temperature").value = uiState['south-temperature'];
    document.querySelector("input#rainfall").value = uiState.rainfall;
    document.querySelector("input#persistence").value = uiState.persistence;
    document.querySelector("input#coast-band-thickness").value = uiState['coast-band-thickness'];
    document.querySelector("input#water-coast-band-thickness").value = uiState['water-coast-band-thickness'];
    document.querySelector("input#land-gamma").value = uiState['land-gamma']; // NEW
    const mountainEl = document.querySelector("input#mountain-density");
    if (mountainEl) mountainEl.value = uiState['mountain-density'];
}

function getUiState() {
    uiState.seed = document.getElementById('seed').valueAsNumber;
    uiState.variant = document.getElementById('variant').valueAsNumber;
    uiState.size = document.querySelector("input[name='size']:checked").value;
    uiState['land-shape'] = document.querySelector("input[name='land-shape']:checked")?.value || 'continent';
    uiState['noisy-edges'] = document.querySelector("input#noisy-edges").checked;
    uiState['borders'] = document.querySelector("input#borders").checked;
    uiState['noisy-fills'] = document.querySelector("input#noisy-fills").checked;
    uiState.icons = document.querySelector("input#icons").checked;
    uiState.biomes = document.querySelector("input#biomes").checked;
    uiState.lighting = document.querySelector("input#lighting").checked;
    uiState['north-temperature'] = document.querySelector("input#north-temperature").valueAsNumber;
    uiState['south-temperature'] = document.querySelector("input#south-temperature").valueAsNumber;
    uiState.rainfall = document.querySelector("input#rainfall").valueAsNumber;
    uiState.persistence = document.querySelector("input#persistence").valueAsNumber;
    uiState['coast-band-thickness'] = document.querySelector("input#coast-band-thickness").valueAsNumber;
    uiState['water-coast-band-thickness'] = document.querySelector("input#water-coast-band-thickness").valueAsNumber;
    uiState['land-gamma'] = document.querySelector("input#land-gamma").valueAsNumber;
    uiState['mountain-density'] = document.querySelector("input#mountain-density")?.valueAsNumber || uiState['mountain-density'];
    setUrlFromState();
    draw();
}

function setSeed(seed) {
    uiState.seed = seed & 0x7fffffff;
    setUiState();
    getUiState();
}

function setVariant(variant) {
    uiState.variant = ((variant % 10) + 10) % 10;
    setUiState();
    getUiState();
}

window.prevSeed = function() { setSeed(uiState.seed - 1); };
window.nextSeed = function() { setSeed(uiState.seed + 1); };
window.prevVariant = function() { setVariant(uiState.variant - 1); };
window.nextVariant = function() { setVariant(uiState.variant + 1); };


let _setUrlFromStateTimeout = null;
function _setUrlFromState() {
    _setUrlFromStateTimeout = null;
    let fragment = urlUtils.stringifyParams(uiState, {}, {
        'canvasSize': 'exclude',
        'noisy-edges': 'include-if-falsy',
        'noisy-fills': 'include-if-falsy',
    });
    let url = window.location.pathname + "#" + fragment;
    window.history.replaceState({}, null, url);
    document.getElementById('url').setAttribute('href', window.location.href);
}
function setUrlFromState() {
    // Rate limit the url update because some browsers (like Safari
    // iOS) throw an error if you change the url too quickly.
    if (_setUrlFromStateTimeout === null) {
        _setUrlFromStateTimeout = setTimeout(_setUrlFromState, 500);
    }
}
    
function getStateFromUrl() {
    const bool = (value) => value === 'true';
    let hashState = urlUtils.parseQuery(
        window.location.hash.slice(1),
        {
            'seed': 'number',
            'variant': 'number',
            'noisy-edges': bool,
            'noisy-fills': bool,
            'icons': bool,
            'biomes': bool,
            'lighting': bool,
            'borders': bool,
            'north-temperature': 'number',
            'south-temperature': 'number',
            'rainfall': 'number',
            'persistence': 'number',
            'coast-band-thickness': 'number',
            'water-coast-band-thickness': 'number',
            'land-gamma': 'number',
            'mountain-density': 'number',
        }
    );
    Object.assign(uiState, defaultUiState);
    Object.assign(uiState, hashState);
    if (hashState.temperature) {
        // backwards compatibility -- I changed the url from
        // &temperature= to separate north and south parameters
        uiState['north-temperature'] = uiState.temperature;
        uiState['south-temperature'] = uiState.temperature;
        delete uiState.temperature;
    }
    setUrlFromState();
    setUiState();
    draw();
}
window.addEventListener('hashchange', getStateFromUrl);
window.addEventListener('resize', draw);

initUi();
getStateFromUrl();
setUiState();
