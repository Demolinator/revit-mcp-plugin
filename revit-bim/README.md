# Revit BIM Plugin

Natural-language building design and BIM management for Autodesk Revit 2024/2025/2026.

Architects, structural engineers, and MEP engineers describe what they want in plain English — Claude creates, modifies, and analyzes BIM elements in the live Revit model.

## Commands

| Command | Description |
|---------|-------------|
| `/revit-bim:design-building` | Multi-phase interactive building design workflow |
| `/revit-bim:create-element` | Create a specific BIM element from natural language |
| `/revit-bim:query-model` | Query and inspect the current Revit model |
| `/revit-bim:modify-model` | Modify, delete, or update elements |
| `/revit-bim:analyze-model` | Analyze model statistics, rooms, materials |

## MCP Tools (45)

| Category | Tools |
|----------|-------|
| **Create** (15) | `create_level`, `create_line_based_element`, `create_surface_based_element`, `place_family`, `create_grid`, `create_structural_framing`, `create_sheet`, `create_schedule`, `create_room`, `create_room_separation`, `create_duct`, `create_pipe`, `create_mep_system`, `create_detail_line`, `create_view` |
| **Query** (12) | `get_revit_status`, `get_revit_model_info`, `list_levels`, `list_families`, `list_family_categories`, `get_revit_view`, `list_revit_views`, `get_current_view_info`, `get_current_view_elements`, `get_selected_elements`, `list_category_parameters`, `get_element_properties` |
| **Modify** (9) | `delete_elements`, `modify_element`, `color_splash`, `clear_colors`, `tag_walls`, `set_parameter`, `tag_elements`, `transform_elements`, `set_active_view` |
| **Analyze** (4) | `ai_element_filter`, `export_room_data`, `get_material_quantities`, `analyze_model_statistics` |
| **Document** (2) | `create_dimensions`, `export_document` |
| **Interop** (2) | `export_ifc`, `link_file` |
| **Advanced** (1) | `execute_revit_code` |

## Building Design Sequence

When creating buildings, follow this order (Revit hosting relationships require it):

1. Levels — floor-to-floor heights
2. Grids — column grid layout
3. Columns — at grid intersections
4. Beams — connecting columns
5. Exterior walls — building envelope
6. Interior walls — room partitions
7. Doors/Windows — placed on walls
8. Floors — slabs at each level
9. Roof — top enclosure
10. Documentation — dimensions, tags, schedules

## Unit Handling

All tools accept **millimeters (mm)**. The server converts to Revit's internal feet.

| From | To mm |
|------|-------|
| meters | x 1000 |
| feet | x 304.8 |
| inches | x 25.4 |

## Requirements

- Autodesk Revit 2024, 2025, or 2026
- pyRevit installed and loaded with Routes enabled (see main README for install steps)
- Windows 10/11
