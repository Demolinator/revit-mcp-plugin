---
name: revit-bim
description: >
  Revit BIM expertise for all building professionals. Use when the user asks to
  design a building, create walls, add floors, place columns, route MEP systems,
  create structural framing, add dimensions, tag elements, create sheets,
  export drawings, query the model, analyze statistics, get material quantities,
  or any task involving Autodesk Revit, building information modeling,
  architectural design, structural engineering, MEP engineering, or
  construction documentation.
version: 2.0.0
---

# Revit BIM Design

Create, modify, and analyze building designs in Autodesk Revit 2024/2025/2026 through natural language. All building professionals — architects, structural engineers, MEP engineers, and interior designers — describe what they want, and elements are created automatically via 45 MCP tools connected to the live Revit model.

## Core Principles

- Think like a building professional. Follow real construction logic: structure before enclosure, enclosure before finishes.
- All tools accept millimeters (mm). The server converts to Revit internal feet automatically.
- Query before creating. Check available family types and current model state before placing elements.
- Batch where possible. Create tools accept arrays — group similar elements into a single call.

## Building Design Sequence

Follow this order when designing a building from scratch:

1. **Levels** — Define floor-to-floor heights (`create_level`)
2. **Grids** — Establish the column grid layout (`create_grid`)
3. **Columns** — Place structural columns at grid intersections (`place_family`)
4. **Beams** — Connect columns with structural beams (`create_structural_framing`)
5. **Exterior walls** — Building envelope along the perimeter (`create_line_based_element`)
6. **Interior walls** — Room partitions (`create_line_based_element`)
7. **Openings** — Doors and windows placed on walls (`place_family`)
8. **Floors** — Floor slabs at each level (`create_surface_based_element`)
9. **Roof** — Top enclosure (`create_surface_based_element`)
10. **Documentation** — Dimensions, tags, sheets, schedules (`create_dimensions`, `tag_walls`, `create_sheet`, `create_schedule`)

Detailed step-by-step workflow: `references/building-design-sequence.md`

## Available Tools (45)

| Category | Tools | Use For |
|----------|-------|---------|
| **Create** | `create_level`, `create_line_based_element`, `create_surface_based_element`, `place_family`, `create_grid`, `create_structural_framing`, `create_sheet`, `create_schedule`, `create_room`, `create_room_separation`, `create_duct`, `create_pipe`, `create_mep_system`, `create_detail_line`, `create_view` | Walls, floors, roofs, levels, families, grids, beams, sheets, schedules, rooms, ducts, pipes, MEP systems, detail lines, views |
| **Query** | `get_revit_status`, `get_revit_model_info`, `list_levels`, `list_families`, `list_family_categories`, `get_revit_view`, `list_revit_views`, `get_current_view_info`, `get_current_view_elements`, `get_selected_elements`, `list_category_parameters`, `get_element_properties` | Status, model info, levels, families, views, elements, selection, filtering, parameters |
| **Modify** | `delete_elements`, `modify_element`, `color_splash`, `clear_colors`, `tag_walls`, `set_parameter`, `tag_elements`, `transform_elements`, `set_active_view` | Delete, edit parameters, colorize, reset colors, tag, move/copy/rotate/mirror, switch views |
| **Analyze** | `ai_element_filter`, `export_room_data`, `get_material_quantities`, `analyze_model_statistics` | Element filtering, rooms, materials, model stats |
| **Document** | `create_dimensions`, `export_document` | Dimensions, export to PDF/PNG/DWG |
| **Interop** | `export_ifc`, `link_file` | IFC export, DWG/DXF/DGN/RVT linking |
| **Advanced** | `execute_revit_code` | Arbitrary IronPython — escape hatch for anything not covered |

Full tool reference with parameters: `references/available-tools.md`

## Three-Tier Tool Strategy

1. **Tier 1 — Dedicated Tools (45)**: Use these first. They handle validation, error messages, and unit conversion automatically. Now includes MEP (ducts, pipes, systems), rooms, views, transforms, parameters, IFC export, and file linking.
2. **Tier 2 — Skill-Guided `execute_revit_code`**: For operations without a dedicated tool (advanced structural, complex documentation). Use the reference files for IronPython code templates.
3. **Tier 3 — Raw `execute_revit_code`**: For truly novel operations. Write IronPython 2.7 code directly. Constraints: no f-strings, no type hints, `.format()` only.

Tier 2 reference files:
- `references/mep-workflows.md` — Duct, pipe, electrical circuit templates
- `references/structural-workflows.md` — Foundation, bracing, load analysis templates
- `references/documentation-workflows.md` — View templates, revisions, detail components

## Unit Handling

All Revit MCP tools expect millimeters (mm) as input. The server converts to Revit's internal feet automatically.

| User Says | Send to Tool |
|-----------|-------------|
| "3 meters" | 3000 (mm) |
| "200 mm" | 200 (mm) |
| "10 feet" | 3048 (mm) |
| "4.5 m high" | 4500 (mm) |

Detailed conversion rules: `references/unit-handling.md`

## Critical Constraints

- **Revit API is single-threaded.** Commands execute sequentially on the UI thread. Do not fire many calls in parallel.
- **A Revit project must be open.** All tools require an active document. If a tool fails with a connection error, ask the user to verify Revit is open with pyRevit loaded.
- **Query before creating.** Always call `list_families` or `list_family_categories` to find valid type names before creating elements.
- **Coordinate system.** Revit uses a right-hand coordinate system. X is east, Y is north, Z is up. All coordinates in mm.
- **Batch efficiently.** Create tools accept arrays. Group similar elements (e.g., all exterior walls) into one call.
- **pyRevit Routes port.** The server communicates with Revit on port 48884 (pyRevit default, not configurable).

## Interaction Style

When a building professional asks you to design something:

1. **Acknowledge** what they want in plain language
2. **Clarify** if dimensions, materials, or layout are ambiguous
3. **Explain** what you will create before doing it
4. **Execute** elements in the correct building design sequence
5. **Summarize** what was created with element counts and any issues
