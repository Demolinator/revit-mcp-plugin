---
description: Design a building interactively from scratch
allowed-tools: ["mcp__revit__create_line_based_element", "mcp__revit__create_surface_based_element", "mcp__revit__create_level", "mcp__revit__create_grid", "mcp__revit__create_structural_framing", "mcp__revit__place_family", "mcp__revit__create_sheet", "mcp__revit__create_schedule", "mcp__revit__create_dimensions", "mcp__revit__tag_walls", "mcp__revit__export_document", "mcp__revit__get_revit_status", "mcp__revit__list_levels", "mcp__revit__list_families", "mcp__revit__list_family_categories", "mcp__revit__get_current_view_info", "mcp__revit__get_current_view_elements", "mcp__revit__delete_elements", "mcp__revit__modify_element", "mcp__revit__color_splash", "mcp__revit__clear_colors", "mcp__revit__analyze_model_statistics", "mcp__revit__export_room_data", "mcp__revit__ai_element_filter", "mcp__revit__get_selected_elements", "mcp__revit__get_material_quantities", "mcp__revit__list_category_parameters", "mcp__revit__get_revit_model_info", "mcp__revit__get_revit_view", "mcp__revit__list_revit_views", "mcp__revit__execute_revit_code"]
argument-hint: [building description]
---

Guide the user through designing a complete building in Revit. This is an interactive, multi-step workflow.

## Phase 1: Understand the Brief

Ask the user what they want to build. Gather:
- Building type (residential, commercial, institutional, mixed-use)
- Approximate footprint dimensions (length x width in meters)
- Number of floors
- Key spaces needed (rooms, lobbies, corridors)
- Any style or material preferences

If the user provided a description via `$ARGUMENTS`, use that as the starting brief. Ask only for missing details.

## Phase 2: Verify Revit Connection

Call `get_revit_status` to confirm Revit is connected and a project is open. If it fails, tell the user to open Revit with pyRevit loaded and a project open.

## Phase 3: Query Available Types

Call `list_families` and `list_family_categories` to discover available types for:
- Walls (exterior and interior types)
- Structural columns
- Doors and windows
- Floors and roofs

Present a summary of available types to the user. Let them choose or recommend defaults.

## Phase 4: Create Elements in Sequence

Follow the building design sequence strictly:

1. **Levels** — Define floor-to-floor heights using `create_level`
2. **Grids** — Establish the structural grid using `create_grid`
3. **Columns** — Place at grid intersections using `place_family`
4. **Beams** — Connect columns using `create_structural_framing`
5. **Exterior walls** — Trace the building perimeter using `create_line_based_element`
6. **Interior walls** — Partition rooms using `create_line_based_element`
7. **Doors** — Place on walls using `place_family`
8. **Windows** — Place on exterior walls using `place_family`
9. **Floors** — Create floor slabs using `create_surface_based_element`
10. **Roof** — Create roof using `create_surface_based_element`

After each major step, tell the user what was created and ask if they want adjustments before continuing.

## Phase 5: Documentation

1. Call `create_dimensions` to add key dimensions
2. Call `tag_walls` to add wall tags
3. Call `create_schedule` to create element schedules (wall, door, window)
4. Call `create_sheet` to create drawing sheets
5. Call `export_document` to export views to PDF or PNG
6. Call `color_splash` to visualize element categories

## Phase 6: Summary

Present a final summary:
- Total elements created by category (walls, columns, doors, windows, floors)
- Building dimensions
- Floor area per level
- Call `analyze_model_statistics` for element counts
- Suggest next steps (add furniture, MEP systems, refine details)

## Rules

- All dimensions in mm. Convert user input from meters/feet as needed.
- Batch similar elements into single tool calls.
- Explain each step before executing it.
- If a tool call fails, diagnose the issue and suggest a fix. Do not silently skip elements.
