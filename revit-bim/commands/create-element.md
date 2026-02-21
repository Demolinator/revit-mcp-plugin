---
description: Create a specific BIM element from a natural-language description
allowed-tools: ["mcp__revit__create_line_based_element", "mcp__revit__create_surface_based_element", "mcp__revit__create_level", "mcp__revit__create_grid", "mcp__revit__create_structural_framing", "mcp__revit__place_family", "mcp__revit__create_sheet", "mcp__revit__create_schedule", "mcp__revit__list_families", "mcp__revit__list_family_categories", "mcp__revit__list_levels", "mcp__revit__get_current_view_info"]
argument-hint: [element description, e.g., "a 6m concrete wall on Level 1"]
---

Create a specific BIM element in Revit from a natural-language description.

## Parse the Description

Extract from `$ARGUMENTS`:
- **Element type**: wall, column, beam, door, window, floor, roof, ceiling, level, grid, sheet, schedule
- **Dimensions**: length, width, height (convert to mm)
- **Position**: coordinates, grid references, relative positions ("at grid A1", "on the north wall")
- **Level**: which floor/level
- **Material/type**: concrete, brick, steel, glass, generic

## Select the Right Tool

| Element | Tool | Key |
|---------|------|-----|
| Wall, beam (line-based) | `create_line_based_element` | Needs start_point and end_point |
| Beam (structural) | `create_structural_framing` | Needs start_point and end_point |
| Column, door, window, furniture | `place_family` | Needs a single location point |
| Floor, roof, ceiling | `create_surface_based_element` | Needs a closed boundary polygon |
| Level | `create_level` | Needs elevation and optional name |
| Grid line | `create_grid` | Needs start_point and end_point |
| Drawing sheet | `create_sheet` | Needs sheet_number and sheet_name |
| Schedule | `create_schedule` | Needs category and optional fields |

## Find the Family Type

Call `list_families` to find a matching type.

Match the user's description to the closest available type:
- "concrete wall" -> look for types containing "Concrete" in the name
- "brick exterior" -> look for types containing "Brick" or "Exterior"
- "steel column" -> look for structural column types containing "Steel"
- If no exact match, use the first available type and tell the user what was used

## Build the Parameters

1. Convert all dimensions to mm
2. Set coordinates based on the user's description
3. If coordinates are ambiguous, call `get_current_view_info` for context, then ask the user
4. Set `level_name` based on the specified level
5. Use standard defaults for unspecified values:
   - Wall height: 3000 mm
   - Door: 900 x 2100 mm
   - Window: 1200 x 1500 mm
   - Floor-to-floor: 3000 mm (residential), 4000 mm (commercial)
   - Column: height = floor-to-floor

## Batch Creation

The create tools accept arrays of elements. If the user asks for multiple elements of the same type (e.g., "4 walls forming a rectangle"), batch them into a single tool call.

## Execute and Confirm

1. Tell the user exactly what will be created (type, dimensions, location)
2. Call the appropriate create tool
3. Report the result: element IDs, type used, final dimensions
4. If the tool fails, explain why and suggest corrections
