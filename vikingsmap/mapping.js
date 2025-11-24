/*
 * Simplified biome → region type mapping
 */
export function mapRegionToIcon(biome, elevation) {
    biome = (biome || "").toUpperCase();

    if (elevation > 0.75) return 'mountains';
    if (elevation >= 0.55) {
        if (biome.includes('FOREST') || biome === 'TAIGA') return 'hill_forest';
        return 'hills';
    }
    if (biome === 'OCEAN') return 'ocean';
    if (biome === 'LAKE') return 'lake';
    if (biome.includes('FOREST') || biome === 'TAIGA') return 'forest';
    return 'grassland';
}

/**
 * For debugging/export: list of all categories
 */
export function getAllIconTypes() {
    return ['ocean', 'lake', 'mountains', 'hills', 'hill_forest', 'forest', 'grassland'];
}
