# Building Design Sequence

Step-by-step workflow for designing a building from scratch in Revit. Follow this order to ensure structural integrity and proper element hosting.

## Why Order Matters

Revit elements have hosting relationships. Doors and windows need walls to exist first. Floors need a closed boundary defined by walls or gridlines. Following the correct sequence prevents errors and rework.

## Step 1: Define Levels

Levels establish floor-to-floor heights. Every other element references a level.

**Typical residential:**
- Ground Floor: 0 mm
- First Floor: 3000 mm
- Second Floor: 6000 mm
- Roof Level: 9000 mm

**Typical commercial:**
- Ground Floor: 0 mm
- Level 1: 4000 mm
- Level 2: 8000 mm
- Level 3: 12000 mm
- Roof Level: 16000 mm

**Tool:** `create_level` — batch all levels in a single call.

## Step 2: Establish Grid Layout

Grids define the structural bay spacing. Use a lettered/numbered system.

**Example 6x4 grid (6m x 8m bays):**
- Grids A through G (north-south, spaced 6000 mm)
- Grids 1 through 5 (east-west, spaced 8000 mm)

**Tool:** `create_grid` — batch all grid lines in one call.

## Step 3: Place Structural Columns

Columns go at grid intersections. Query available column types first.

**Workflow:**
1. Call `list_families` to find column family types
2. Pick an appropriate type (e.g., concrete rectangular 400x400)
3. Call `place_family` with positions at each grid intersection
4. Set level and height parameters

**Tool:** `place_family` — batch all columns in one call.

## Step 4: Add Structural Beams

Beams connect columns along grid lines.

**Workflow:**
1. Call `list_families` to find beam family types
2. Call `create_structural_framing` with start/end points at column positions
3. Set beam level at the upper floor level

**Tool:** `create_structural_framing` — batch all beams per level.

## Step 5: Create Exterior Walls

Walls form the building envelope. Place along the outermost grid lines.

**Workflow:**
1. Call `list_families` to find wall types
2. Pick exterior wall type (e.g., "Generic - 200mm")
3. Call `create_line_based_element` with wall segments tracing the building perimeter
4. Set level, height, and type_name

**Common wall thicknesses (controlled by type_name):**
- Interior partition: 100-150 mm
- Exterior wall: 200-300 mm
- Structural wall: 200-400 mm

**Tool:** `create_line_based_element` — batch all perimeter walls.

## Step 6: Add Interior Walls

Partition walls divide the floor plate into rooms.

**Workflow:**
1. Plan room layout based on the architect's program
2. Use thinner wall types for partitions
3. Call `create_line_based_element` with partition segments

**Tool:** `create_line_based_element`

## Step 7: Place Doors and Windows

Doors and windows are hosted on walls. Walls must exist first.

**Workflow:**
1. Call `list_families` to find door/window types
2. Call `place_family` with location on the wall line
3. The point should be on or very near the wall centerline

**Standard sizes:**
- Single door: 900 mm wide x 2100 mm high
- Double door: 1800 mm wide x 2100 mm high
- Standard window: 1200 mm wide x 1500 mm high
- Large window: 2400 mm wide x 1800 mm high

**Tool:** `place_family` — batch doors and windows separately.

## Step 8: Create Floor Slabs

Floors need a closed boundary (polygon of line segments).

**Workflow:**
1. Call `list_families` to find floor types
2. Define the floor boundary as a closed polygon (outer loop)
3. The boundary should follow the exterior wall lines
4. Call `create_surface_based_element` with the boundary

**Important:** The boundary must be closed — the last segment's end point must match the first segment's start point. Minimum 3 segments (triangle), typically 4+ for rectangular floors.

**Tool:** `create_surface_based_element`

## Step 9: Add Roof

The roof closes the top of the building.

**Workflow:**
1. Call `list_families` to find roof types
2. Define the roof boundary (similar to floors, but at roof level)
3. Call `create_surface_based_element` at the roof level

**Tool:** `create_surface_based_element`

## Step 10: Documentation

Add dimensions, tags, sheets, and schedules for construction documents.

**Workflow:**
1. Call `create_dimensions` to dimension key elements
2. Call `tag_walls` to auto-tag walls in the current view
3. Call `create_schedule` to create element schedules (wall schedule, door schedule)
4. Call `create_sheet` to create drawing sheets (A101, A102, etc.)
5. Call `export_document` to export views to PDF or PNG
6. Use `color_splash` to visualize element categories

**Tools:** `create_dimensions`, `tag_walls`, `create_schedule`, `create_sheet`, `export_document`, `color_splash`

## Quick Reference: Tool Selection by Element

| Element | Tool | Key Parameters |
|---------|------|---------------|
| Levels | `create_level` | elevation, name |
| Grids | `create_grid` | start_point, end_point, name |
| Walls | `create_line_based_element` | start_point, end_point, type_name, height, level_name |
| Beams | `create_structural_framing` | start_point, end_point, type_name, level_name |
| Columns | `place_family` | family_name, type_name, location, level_name |
| Doors | `place_family` | family_name, type_name, location, level_name |
| Windows | `place_family` | family_name, type_name, location, level_name |
| Floors | `create_surface_based_element` | boundary (closed polygon), type_name, level_name |
| Roofs | `create_surface_based_element` | boundary (closed polygon), type_name, level_name |
| Ceilings | `create_surface_based_element` | boundary (closed polygon), type_name, level_name |
| Sheets | `create_sheet` | sheet_number, sheet_name, title_block_name |
| Schedules | `create_schedule` | category, fields, schedule_name |
| Dimensions | `create_dimensions` | element_ids, dimension_type |
| Wall tags | `tag_walls` | use_leader, tag_type_name |
