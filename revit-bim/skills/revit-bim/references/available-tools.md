# Available MCP Tools (45)

Complete reference for all Revit MCP tools. All dimensions are in **millimeters** unless noted. The server converts to Revit's internal feet automatically.

---

## CREATE Tools (15)

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

### create_room

Create a room in the Revit model at a specified level. Rooms must be placed inside enclosed areas (bounded by walls or room separation lines).

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `level_name` | string | Yes | Target level name (e.g., "Level 1") |
| `location` | object | No | Placement point `{"x", "y"}` in mm. Auto-places if omitted |
| `name` | string | No | Room name (e.g., "Living Room") |
| `number` | string | No | Room number (e.g., "101") |

**Example:**
```json
{
  "level_name": "Ground Floor",
  "location": {"x": 5000, "y": 5000},
  "name": "Living Room",
  "number": "101"
}
```

---

### create_room_separation

Create room separation lines to define room boundaries where physical walls don't fully enclose a space.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `lines` | array | Yes | List of line segments, each with `start_point` and `end_point` `{"x", "y", "z"}` in mm |
| `level_name` | string | No | Target level name (defaults to active view's level) |
| `view_name` | string | No | Plan view name (defaults to active view) |

**Example:**
```json
{
  "lines": [
    {
      "start_point": {"x": 3000, "y": 5000, "z": 0},
      "end_point": {"x": 7000, "y": 5000, "z": 0}
    }
  ],
  "level_name": "Ground Floor"
}
```

---

### create_duct

Create a duct between two points. Requires a project with mechanical families loaded (MEP template).

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `start_point` | object | Yes | `{"x", "y", "z"}` in mm |
| `end_point` | object | Yes | `{"x", "y", "z"}` in mm |
| `system_type` | string | No | System type name (e.g., "Supply Air"). Auto-detects if omitted |
| `duct_type` | string | No | Duct type name (e.g., "Round Duct"). Auto-detects if omitted |
| `level_name` | string | No | Level name. Defaults to nearest level |
| `diameter` | float | No | Round duct diameter in mm |
| `width` | float | No | Rectangular duct width in mm |
| `height` | float | No | Rectangular duct height in mm |

**Example — 300mm round supply duct:**
```json
{
  "start_point": {"x": 0, "y": 0, "z": 3000},
  "end_point": {"x": 5000, "y": 0, "z": 3000},
  "system_type": "Supply Air",
  "diameter": 300,
  "level_name": "Ground Floor"
}
```

---

### create_pipe

Create a pipe between two points. Requires a project with plumbing families loaded (MEP template).

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `start_point` | object | Yes | `{"x", "y", "z"}` in mm |
| `end_point` | object | Yes | `{"x", "y", "z"}` in mm |
| `system_type` | string | No | System type name (e.g., "Domestic Hot Water"). Auto-detects if omitted |
| `pipe_type` | string | No | Pipe type name (e.g., "Copper"). Auto-detects if omitted |
| `level_name` | string | No | Level name. Defaults to nearest level |
| `diameter` | float | No | Pipe diameter in mm |

**Example — 25mm hot water pipe:**
```json
{
  "start_point": {"x": 0, "y": 0, "z": 1000},
  "end_point": {"x": 3000, "y": 0, "z": 1000},
  "system_type": "Domestic Hot Water",
  "diameter": 25,
  "level_name": "Ground Floor"
}
```

---

### create_mep_system

Create a mechanical or piping system to group ducts or pipes for organization and analysis.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `system_type` | string | Yes | `"mechanical"` or `"piping"` |
| `system_name` | string | Yes | Display name (e.g., "Level 1 Supply Air") |
| `element_ids` | array[int] | No | Duct/pipe element IDs to add to the system |

**Example:**
```json
{
  "system_type": "mechanical",
  "system_name": "Level 1 Supply Air",
  "element_ids": [123456, 123457, 123458]
}
```

---

### create_detail_line

Create a detail line for view-specific 2D annotation. Must be created in a plan, section, or detail view.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `start_point` | object | Yes | `{"x", "y", "z"}` in mm |
| `end_point` | object | Yes | `{"x", "y", "z"}` in mm |
| `view_name` | string | No | Target view name (defaults to active view) |
| `line_style` | string | No | Line style name (e.g., "Medium Lines"). Uses default if omitted |

**Example:**
```json
{
  "start_point": {"x": 0, "y": 0, "z": 0},
  "end_point": {"x": 5000, "y": 0, "z": 0},
  "view_name": "Ground Floor Plan",
  "line_style": "Medium Lines"
}
```

---

### create_view

Create a new view in the Revit model. Supports floor plans, ceiling plans, sections, elevations, and 3D views.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `view_type` | string | Yes | `"floor_plan"`, `"ceiling_plan"`, `"section"`, `"elevation"`, or `"3d"` |
| `name` | string | Yes | Display name for the new view |
| `level_name` | string | Cond. | Required for `floor_plan` and `ceiling_plan` |
| `section_box` | object | Cond. | Required for `section` — origin, direction, up, width, height, depth |

**Example — floor plan:**
```json
{
  "view_type": "floor_plan",
  "name": "Ground Floor - Furniture Layout",
  "level_name": "Ground Floor"
}
```

**Example — section:**
```json
{
  "view_type": "section",
  "name": "Section A-A",
  "section_box": {
    "origin": {"x": 7500, "y": 5000, "z": 2000},
    "direction": {"x": 0, "y": 1, "z": 0},
    "up": {"x": 0, "y": 0, "z": 1},
    "width": 15000,
    "height": 8000,
    "depth": 10000
  }
}
```

---

## QUERY Tools (12)

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

### get_element_properties

Get all properties and parameters of a Revit element — category, family, type, and complete parameter list.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `element_id` | int | Yes | Revit element ID to inspect |
| `include_type_params` | bool | No | Include type parameters (default: true) |

**Use when:** Inspecting element details, checking parameter values before modifying.

---

## MODIFY Tools (8)

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

### set_parameter

Set a single parameter value on a Revit element. Auto-detects the parameter's storage type and converts the value accordingly.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `element_id` | int | Yes | Target element ID |
| `parameter_name` | string | Yes | Parameter name (e.g., "Comments", "Mark") |
| `value` | string | Yes | New value — auto-converted to correct type |

**Example:**
```json
{
  "element_id": 123456,
  "parameter_name": "Comments",
  "value": "Updated via MCP"
}
```

---

### tag_elements

Tag elements with annotation symbols in a view. Works with walls, doors, windows, rooms, and other taggable categories.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `element_ids` | array[int] | Yes | Element IDs to tag |
| `view_name` | string | No | View to place tags in (defaults to active view) |
| `tag_type_name` | string | No | Tag family type name (auto-detects if omitted) |
| `add_leader` | bool | No | Show leader line (default: false) |
| `orientation` | string | No | `"horizontal"` or `"vertical"` (default: "horizontal") |
| `offset` | object | No | Tag offset from element `{"x", "y"}` in mm |

**Example:**
```json
{
  "element_ids": [123456, 123457],
  "add_leader": false,
  "orientation": "horizontal"
}
```

---

### transform_elements

Move, copy, rotate, or mirror elements. All coordinates in mm, angles in degrees.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `element_ids` | array[int] | Yes | Element IDs to transform |
| `operation` | string | Yes | `"move"`, `"copy"`, `"rotate"`, or `"mirror"` |
| `vector` | object | Cond. | `{"x", "y", "z"}` in mm — required for move/copy |
| `axis_point` | object | Cond. | `{"x", "y", "z"}` in mm — required for rotate |
| `angle` | float | Cond. | Degrees — required for rotate |
| `mirror_plane` | object | Cond. | Required for mirror: `{"origin": {"x","y","z"}, "normal": {"x","y","z"}}` |

**Example — move 2000mm east:**
```json
{
  "element_ids": [123456],
  "operation": "move",
  "vector": {"x": 2000, "y": 0, "z": 0}
}
```

**Example — rotate 45° around a point:**
```json
{
  "element_ids": [123456],
  "operation": "rotate",
  "axis_point": {"x": 5000, "y": 5000, "z": 0},
  "angle": 45
}
```

---

### set_active_view

Switch the active view in Revit to the specified view. Use `list_revit_views` first to find available view names.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `view_name` | string | Yes | Name of the view to activate |

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

## INTEROP Tools (2)

### export_ifc

Export the Revit model to IFC format. Supports IFC2x3 and IFC4.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `file_path` | string | Yes | Output file path (must end in `.ifc`) |
| `ifc_version` | string | No | `"IFC2x3"` (default) or `"IFC4"` |
| `export_base_quantities` | bool | No | Include IFC base quantities (default: true) |
| `view_name` | string | No | Export only elements visible in this view |

**Example:**
```json
{
  "file_path": "C:\\Export\\model.ifc",
  "ifc_version": "IFC4"
}
```

---

### link_file

Link or import an external file into the Revit model. Supports DWG, DXF, DGN, and RVT.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `file_path` | string | Yes | Path to the file (DWG, DXF, DGN, or RVT) |
| `mode` | string | No | `"link"` (default, maintains connection) or `"import"` (embeds copy) |
| `position` | object | No | Placement offset `{"x", "y", "z"}` in mm |

**Example:**
```json
{
  "file_path": "C:\\CAD\\site_plan.dwg",
  "mode": "link"
}
```

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
| Create | 15 | create_level, create_line_based_element, create_surface_based_element, place_family, create_grid, create_structural_framing, create_sheet, create_schedule, create_room, create_room_separation, create_duct, create_pipe, create_mep_system, create_detail_line, create_view |
| Query | 12 | get_revit_status, get_revit_model_info, list_levels, get_current_view_info, get_current_view_elements, list_revit_views, get_revit_view, list_families, list_family_categories, get_selected_elements, list_category_parameters, get_element_properties |
| Modify | 8 | delete_elements, modify_element, color_splash, clear_colors, tag_walls, set_parameter, tag_elements, transform_elements, set_active_view |
| Analyze | 4 | ai_element_filter, export_room_data, get_material_quantities, analyze_model_statistics |
| Document | 3 | create_dimensions, export_document, create_schedule |
| Interop | 2 | export_ifc, link_file |
| Advanced | 1 | execute_revit_code |
| **Total** | **45** | |
