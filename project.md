# Vikings Map Generator - Project Documentation

## Overview
A Godot-based map generator for a Viking-themed strategy game, featuring procedural terrain generation, region management, and castle placement mechanics.

## Technical Architecture

### Scene Structure
```
Main (Node2D)
├── Map (Node2D) - MapGenerator script
│   ├── Regions (Node2D) - Land region containers
│   │   ├── Region{ID} (Node2D) - Individual region containers
│   │   │   ├── Polygon (Polygon2D) - Region shape with grass texture
│   │   │   ├── RegionPoint (Node2D) - Ownership indicator (optional)
│   │   │   ├── Castle (Sprite2D) - Castle building (optional)
│   │   │   └── Borders (Node2D) - Border lines
│   ├── Ocean (Node2D) - Ocean region polygons
│   └── Frame (Node2D) - Ocean frame around map
├── Camera2D - CameraController script
├── ClickManager (Node) - Input handling and castle placement
├── GameManager (Node) - Turn management and game state
├── Background (Sprite2D) - Background image
└── Players (Node2D) - Player armies and units
```

### Z-Index Hierarchy
**Layer Management System:**
- **Background**: -100 (Background image)
- **Ocean Frame**: -50 (Ocean border frame)
- **Terrain**: 0 (Land and ocean polygons)
- **Biome Icons**: 50 (Mountain, hill, forest icons)
- **Buildings**: 100 (Castles, structures)
- **Armies**: 125-145 (Military units)
- **Region Points**: 150-151 (Ownership indicators)
  - Outer circle: 150
  - Inner circle: 151
- **Move Arrows**: 200 (Direction indicators for army movement)

### Coordinate System
- **Map coordinates**: 0-1000 x 0-1000 (scaled by polygon_scale)
- **World coordinates**: Converted from screen coordinates via camera
- **Polygon scale**: Configurable scaling factor (default: 2.0)

## Game Logic

### Game Management System
**Turn-Based Mechanics:**
- **Turn Counter**: Tracks current turn number
- **Player Rotation**: Cycles through players (1, 2, 3, 4...)
- **Movement Reset**: All armies get fresh movement points each turn
- **Turn Advancement**: Press Enter to end current turn

**Functions:**
- `next_turn()`: Advance to next turn and reset army movement
- `reset_movement_points()`: Reset all army movement points
- `get_current_turn()`: Get current turn number
- `get_current_player()`: Get current player number

### Castle Placement System
**Workflow:**
1. **Castle Placing Mode**: Enabled by default on game start
2. **Player Progression**: Automatically cycles through players (1, 2, 3, 4...)
3. **Region Selection**: Click on land region to place castle
4. **Ownership Claiming**: 
   - Castle region becomes owned by player
   - Neighboring regions are automatically claimed
   - Region points become visible with player colors

**Functions:**
- `set_castle_starting_position(region_id, player_id)`
- `set_region_ownership(region_id, player_id)`
- `get_neighbor_regions(region_id)`

### Region Management
**Ownership Tracking:**
- `region_ownership`: Dictionary mapping region_id → player_id
- `castle_starting_positions`: Dictionary mapping player_id → region_id
- `region_graph`: Adjacency graph for neighbor lookups

**Visual Indicators:**
- **Region Points**: Color-coded circles showing ownership
  - Player 1: Red
  - Player 2: Blue
  - Player 3: Green
  - Player 4: Yellow
- **Castle Sprites**: Placed at region centers
- **No polygon tinting**: Original textures preserved

### Input Handling
**Mouse Controls:**
- **Left Click**: Place castle (in castle placing mode)
- **Shift + Left Drag**: Pan camera
- **Mouse Wheel**: Zoom in/out

**Keyboard Controls:**
- **WASD/Arrow Keys**: Pan camera
- **Q/E**: Zoom in/out
- **R**: Reset camera to center
- **Enter**: End current turn and advance to next player

**Touch Controls (macOS):**
- **Two-finger pan**: Move camera
- **Pinch gesture**: Zoom in/out

## Data Flow

### Map Generation Pipeline
1. **JSON Loading**: Load region/edge data from data files
2. **Coordinate Scaling**: Apply polygon_scale to all coordinates
3. **Node Creation**: Build map structure with regions, ocean, frame
4. **Texture Application**: Apply grass, sea, coast textures
5. **Icon Placement**: Add biome icons based on region type
6. **Border Drawing**: Create noisy border lines between regions

### Castle Placement Pipeline
1. **Click Detection**: Convert screen coordinates to world coordinates
2. **Region Hit Testing**: Find clicked region using polygon collision
3. **Ownership Check**: Verify region is unowned
4. **Castle Placement**: Set starting position and claim regions
5. **Visual Update**: Place castle sprite and show region points
6. **Player Progression**: Move to next player

## Configuration

### Map Generator Settings
```gdscript
@export var data_file_path: String = "data9.json"
@export var polygon_scale: float = 2.0
@export var ocean_frame_width: float = 500.0
@export var noisy_edges_enabled: bool = true
@export var show_region_colors: bool = false
@export var show_region_graph: bool = false
@export var show_region_points: bool = false
```

### Camera Controller Settings
```gdscript
@export var pan_speed: float = 2.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.1
@export var max_zoom: float = 5.0
@export var smooth_pan: bool = true
@export var smooth_zoom: bool = true
```

## File Structure
```
vikings/
├── main.tscn - Main scene
├── map_generator.gd - Map generation and rendering
├── camera_controller.gd - Camera movement and controls
├── click_manager.gd - Input handling and castle placement
├── game_manager.gd - Turn management and game state
├── region_manager.gd - Region ownership and game logic
├── region_points.gd - Region point creation and management
├── region_graph.gd - Adjacency graph utilities
├── biome_manager.gd - Biome color and icon management
├── utils.gd - Utility functions
├── data*.json - Map data files
├── images/ - Textures and icons
└── project.md - This documentation
```