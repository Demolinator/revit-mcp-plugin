# Available MCP Tools (31)

Complete reference for all Revit MCP tools. All dimensions are in **millimeters** unless noted. The server converts to Revit's internal feet automatically.

---

## CREATE Tools (8)

### create_level

Create building levels (floor elevations). Levels must exist before placing walls, floors, or other level-dependent elements.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `levels` | array | Yes | List of level definitions |
| `levels[].elevation` | float | Yes | Elevation in mm from project origin |
| `levels[].name` | string | No | Level name, e.g. "Ground Floor" (auto-assigned if omitted) |

**Example:**
```json
{
  "levels": [
    {"elevation": 0, "name": "Ground Floor"},
    {"elevation": 4000, "name": "First Floor"},
    {"elevation": 8000, "name": "Roof Level"}
  ]
}
```

---

### create_line_based_element

Create walls, beams, and other line-based elements. Supports batch creation.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `elements` | array | Yes | List of element definitions |
| `elements[].element_type` | string | Yes | `"wall"` or `"beam"` |
| `elements[].start_point` | object | Yes | `{"x", "y", "z"}` in mm |
| `elements[].end_point` | object | Yes | `{"x", "y", "z"}` in mm |
| `elements[].type_name` | string | No | Family type name, e.g. "Generic - 200mm" |
| `elements[].level_name` | string | No | Target level name (defaults to first level) |
| `elements[].height` | float | No | Height in mm (defaults to 3000) |
| `elements[].offset` | float | No | Offset from base level in mm (defaults to 0) |
| `elements[].structural` | bool | No | Mark as structural (defaults to false) |
| `elements[].name` | string | No | Description for reference |

**Example — two walls:**
```json
{
  "elements": [
    {
      "element_type": "wall",
      "start_point": {"x": 0, "y": 10000, "z": 0},
      "end_point": {"x": 15000, "y": 10000, "z": 0},
      "height": 3000,
      "level_name": "Ground Floor",
      "name": "exterior wall north"
    },
    {
      "element_type": "wall",
      "start_point": {"x": 15000, "y": 10000, "z": 0},
      "end_point": {"x": 15000, "y": 0, "z": 0},
      "height": 3000,
      "level_name": "Ground Floor",
      "name": "exterior wall east"
    }
  ]
}
```

---

### create_surface_based_element

Create floors, roofs, ceilings, and other surface-based elements. Supports batch creation.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `elements` | array | Yes | List of element definitions |
| `elements[].element_type` | string | Yes | `"floor"`, `"roof"`, or `"ceiling"` |
| `elements[].boundary` | array | Yes | Array of `{"p0": Point, "p1": Point}` segments forming a closed polygon (min 3 segments) |
| `elements[].type_name` | string | No | Family type name |
| `elements[].level_name` | string | No | Target level name |
| `elements[].offset` | float | No | Offset from level in mm (defaults to 0) |
| `elements[].name` | string | No | Description for reference |

**Example — rectangular floor 15m x 10m:**
```json
{
  "elements": [{
    "element_type": "floor",
    "level_name": "Ground Floor",
    "name": "ground floor slab",
    "boundary": [
      {"p0": {"x": 0, "y": 0, "z": 0}, "p1": {"x": 15000, "y": 0, "z": 0}},
      {"p0": {"x": 15000, "y": 0, "z": 0}, "p1": {"x": 15000, "y": 10000, "z": 0}},
      {"p0": {"x": 15000, "y": 10000, "z": 0}, "p1": {"x": 0, "y": 10000, "z": 0}},
      {"p0": {"x": 0, "y": 10000, "z": 0}, "p1": {"x": 0, "y": 0, "z": 0}}
    ]
  }]
}
```

**Important:** The boundary must be closed — the last segment's `p1` must equal the first segment's `p0`.

---

### place_family

Place a family instance (column, door, window, furniture, fixture) at a specific location.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `family_name` | string | Yes | Family name, e.g. "Single-Flush" |
| `type_name` | string | No | Type name within the family |
| `x` | float | No | X coordinate (defaults to 0) |
| `y` | float | No | Y coordinate (defaults to 0) |
| `z` | float | No | Z coordinate (defaults to 0) |
| `rotation` | float | No | Rotation angle in degrees (defaults to 0) |
| `level_name` | string | No | Target level name |
| `properties` | object | No | Additional properties to set on the instance |

**Use when:** Placing columns, doors, windows, furniture, or any point-based family.

**Example:**
```json
{
  "family_name": "Single-Flush",
  "type_name": "0915 x 2134mm",
  "x": 7500, "y": 0, "z": 0,
  "level_name": "Ground Floor"
}
```

---

### create_grid

Create grid lines for the structural column layout. Supports batch creation.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `grids` | array | Yes | List of grid definitions |
| `grids[].start_point` | object | Yes | `{"x", "y", "z"}` in mm |
| `grids[].end_point` | object | Yes | `{"x", "y", "z"}` in mm |
| `grids[].name` | string | No | Grid line name (auto-assigned: A, B, C... or 1, 2, 3...) |

**Example:**
```json
{
  "grids": [
    {"start_point": {"x": 0, "y": -1000, "z": 0}, "end_point": {"x": 0, "y": 11000, "z": 0}, "name": "A"},
    {"start_point": {"x": 6000, "y": -1000, "z": 0}, "end_point": {"x": 6000, "y": 11000, "z": 0}, "name": "B"},
    {"start_point": {"x": 12000, "y": -1000, "z": 0}, "end_point": {"x": 12000, "y": 11000, "z": 0}, "name": "C"}
  ]
}
```

---

### create_structural_framing

Create structural beams and framing elements. Supports batch creation.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `elements` | array | Yes | List of beam definitions |
| `elements[].start_point` | object | Yes | `{"x", "y", "z"}` in mm |
| `elements[].end_point` | object | Yes | `{"x", "y", "z"}` in mm |
| `elements[].type_name` | string | No | Beam family type name |
| `elements[].level_name` | string | No | Target level name |
| `elements[].name` | string | No | Description for reference |

**Example:**
```json
{
  "elements": [
    {
      "start_point": {"x": 0, "y": 0, "z": 4000},
      "end_point": {"x": 6000, "y": 0, "z": 4000},
      "level_name": "First Floor",
      "name": "beam A1-B1"
    }
  ]
}
```

---

### create_sheet

Create a drawing sheet for construction documentation.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `sheet_number` | string | No | Sheet number, e.g. "A101" (auto-assigned if omitted) |
| `sheet_name` | string | No | Sheet title (defaults to "Unnamed Sheet") |
| `title_block_name` | string | No | Title block family name (uses first available if omitted) |

**Example:**
```json
{
  "sheet_number": "A101",
  "sheet_name": "Ground Floor Plan"
}
```

---

### create_schedule

Create a schedule (quantity takeoff view) for a category.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `category` | string | Yes | BuiltInCategory name, e.g. `"OST_Walls"`, `"OST_Rooms"` |
| `fields` | array | No | Parameter names to include as columns |
| `schedule_name` | string | No | Schedule view name (auto-generated if omitted) |

**Example:**
```json
{
  "category": "OST_Walls",
  "fields": ["Family and Type", "Length", "Area", "Mark"],
  "schedule_name": "Wall Schedule"
}
```

---

## QUERY Tools (11)

### get_revit_status

Check if the Revit MCP API is active and responding.

**Parameters:** None.

**Use when:** Starting a session, verifying connectivity.

---

### get_revit_model_info

Get comprehensive information about the current Revit model (title, path, phases, location).

**Parameters:** None.

---

### list_levels

Get all levels in the current Revit model with names and elevations.

**Parameters:** None.

**Use when:** Before creating elements — check which levels exist.

---

### get_current_view_info

Get details about the active Revit view (name, type, scale, detail level, discipline).

**Parameters:** None.

**Use when:** Before placing annotations, checking which view is active.

---

### get_current_view_elements

Get all elements visible in the currently active view with IDs, types, categories, and locations.

**Parameters:** None.

**Use when:** Understanding what's in the current view before making changes.

---

### list_revit_views

Get a list of all exportable views in the model.

**Parameters:** None.

---

### get_revit_view

Export a specific Revit view as an image.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `view_name` | string | Yes | Name of the view to export |

---

### list_families

Get available family types in the project, optionally filtered.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `contains` | string | No | Filter by name substring |
| `limit` | int | No | Max results (defaults to 50) |

**Use when:** Before creating elements — find valid family/type names.

---

### list_family_categories

Get all family categories available in the model.

**Parameters:** None.

---

### get_selected_elements

Get details of elements currently selected in the Revit UI.

**Parameters:** None.

**Use when:** The user says "modify this" or "what's selected".

---

### list_category_parameters

Get available parameters for elements in a given category.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `category_name` | string | Yes | Category name, e.g. "Walls", "Doors" |

**Use when:** Before coloring or modifying elements — discover available parameters.

---

## MODIFY Tools (5)

### delete_elements

Delete one or more elements from the model. Cascade-deletes hosted elements.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `element_ids` | array[int] | Yes | Revit element IDs to delete |

**Example:**
```json
{"element_ids": [123456, 123457]}
```

---

### modify_element

Change parameter values on a Revit element.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `element_id` | int | Yes | Revit element ID |
| `parameters` | object | Yes | Parameter name to new value pairs |

**Example:**
```json
{
  "element_id": 123456,
  "parameters": {"Mark": "EW-01", "Comments": "Updated via MCP"}
}
```

---

### color_splash

Color elements in a category based on parameter values. Each unique value gets a distinct color.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `category_name` | string | Yes | Category, e.g. "Walls", "Rooms" |
| `parameter_name` | string | Yes | Parameter to group by |
| `use_gradient` | bool | No | Gradient instead of random colors (defaults to false) |
| `custom_colors` | array[string] | No | Custom hex color palette, e.g. `["#FF0000", "#00FF00"]` |

---

### clear_colors

Remove all color overrides from elements in a category.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `category_name` | string | Yes | Category to clear colors from |

---

### tag_walls

Tag all untagged walls in the current view.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `use_leader` | bool | No | Show leader lines (defaults to false) |
| `tag_type_name` | string | No | Specific wall tag family type name |

---

## ANALYZE Tools (4)

### ai_element_filter

Filter and find elements by category, type, visibility, and spatial bounds. Combine filters for precise results.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `category` | string | No | BuiltInCategory name, e.g. `"OST_Walls"` |
| `type_name` | string | No | Filter by type name (partial match) |
| `visible_in_view` | bool | No | Only visible elements (defaults to false) |
| `bounding_box_min` | object | No | Spatial filter min corner `{"x", "y", "z"}` in mm |
| `bounding_box_max` | object | No | Spatial filter max corner `{"x", "y", "z"}` in mm |
| `max_elements` | int | No | Max results (defaults to 50) |

**Example — find all exterior walls visible in current view:**
```json
{
  "category": "OST_Walls",
  "type_name": "Exterior",
  "visible_in_view": true
}
```

---

### export_room_data

Export data for all rooms: names, numbers, levels, areas (sq m), perimeters (mm), departments.

**Parameters:** None.

---

### get_material_quantities

Get aggregated material quantities (areas and volumes) for cost estimation and takeoffs.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `categories` | array[string] | No | Filter by categories, e.g. `["OST_Walls", "OST_Floors"]` (defaults to all) |

---

### analyze_model_statistics

Get element counts grouped by category for model health checks and progress tracking.

**Parameters:** None.

---

## DOCUMENT Tools (3)

### create_dimensions

Create dimension annotations for elements in the current view.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `element_ids` | array[int] | Yes | Element IDs to dimension |
| `dimension_type` | string | No | `"linear"`, `"aligned"`, or `"angular"` (defaults to "linear") |

---

### export_document

Export a view or sheet to PDF, image, or DWG format.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `view_name` | string | No | View or sheet name (defaults to active view) |
| `format` | string | No | `"pdf"`, `"png"`, `"jpg"`, or `"dwg"` (defaults to "pdf") |
| `resolution` | int | No | DPI for image formats (defaults to 300, ignored for PDF/DWG) |

---

## ADVANCED Tools (1)

### execute_revit_code

Execute IronPython 2.7 code directly in Revit's context. Use as an escape hatch when no dedicated tool fits.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `code` | string | Yes | IronPython 2.7 code to execute |
| `description` | string | No | Description of what the code does |

**Available in code context:**
- `doc` — Active Revit document
- `DB` — Revit API Database namespace
- `revit` — pyRevit module
- `print()` — Output text (returned in response)

**IronPython 2.7 rules:**
- Use `.format()` for strings — NO f-strings
- NO type hints
- Use `element.Id.Value` — NOT `.IntegerValue`
- Wrap mutations in `DB.Transaction`

**Use sparingly.** Prefer dedicated tools. See Tier 2 reference files for pre-built IronPython templates:
- `mep-workflows.md` — Ducts, pipes, MEP systems
- `structural-workflows.md` — Foundations, braces, analytical model
- `documentation-workflows.md` — View templates, revision clouds, print setup

---

## Tool Count by Category

| Category | Count | Tools |
|----------|-------|-------|
| Create | 8 | create_level, create_line_based_element, create_surface_based_element, place_family, create_grid, create_structural_framing, create_sheet, create_schedule |
| Query | 11 | get_revit_status, get_revit_model_info, list_levels, get_current_view_info, get_current_view_elements, list_revit_views, get_revit_view, list_families, list_family_categories, get_selected_elements, list_category_parameters |
| Modify | 5 | delete_elements, modify_element, color_splash, clear_colors, tag_walls |
| Analyze | 4 | ai_element_filter, export_room_data, get_material_quantities, analyze_model_statistics |
| Document | 3 | create_dimensions, export_document, create_schedule |
| Advanced | 1 | execute_revit_code |
| **Total** | **31** | |
