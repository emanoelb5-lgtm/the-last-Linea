class_name LineaWorldRules
extends RefCounted
## Stable world coordinates/IDs, shared by streaming, gameplay and save validation.
const MOUNTAIN_RADIUS := 760.0
const MAP_LIMIT := 775.0
const CELL_SIZE := 8.0
const CHUNK_SIZE := 48.0
const CELLS_PER_CHUNK := 6
const GRID_HALF := 100
const GRID_WIDTH := GRID_HALF*2+1
const LEGACY_TREE_COUNT := 240
const MAX_TREE_ID := LEGACY_TREE_COUNT+GRID_WIDTH*GRID_WIDTH-1
const SAFE_RADIUS := 260.0
const DOOR_MIN_RADIUS := 410.0
