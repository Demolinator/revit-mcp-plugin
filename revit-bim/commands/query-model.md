---
description: Query and analyze the current Revit model
allowed-tools: ["mcp__revit__get_revit_status", "mcp__revit__get_revit_model_info", "mcp__revit__list_levels", "mcp__revit__list_families", "mcp__revit__list_family_categories", "mcp__revit__get_revit_view", "mcp__revit__list_revit_views", "mcp__revit__get_current_view_info", "mcp__revit__get_current_view_elements", "mcp__revit__get_selected_elements", "mcp__revit__ai_element_filter", "mcp__revit__export_room_data", "mcp__revit__get_material_quantities", "mcp__revit__analyze_model_statistics", "mcp__revit__color_splash", "mcp__revit__clear_colors", "mcp__revit__list_category_parameters"]
argument-hint: [what to query, e.g., "all walls", "room areas", "model stats"]
---

Query the current Revit model and present results in clear, readable tables.

## Determine Query Type

Based on `$ARGUMENTS`, determine what the user wants:

**"status" / "connection" / no arguments:**
- Call `get_revit_status` to check connection
- Present: Revit version, project name, connection status

**"model info" / "project":**
- Call `get_revit_model_info`
- Present: project details, location, settings

**"view info" / "current view":**
- Call `get_current_view_info`
- Present: view name, type, scale, level

**"views" / "all views":**
- Call `list_revit_views`
- Present: list of views by type

**"levels" / "floors":**
- Call `list_levels`
- Present: level names, elevations

**"walls" / "doors" / "windows" / any element category:**
- Call `ai_element_filter` with the appropriate category (OST_Walls, OST_Doors, OST_Windows, etc.)
- Present results in a table: ID, Type, Level, Key Parameters

**"types" / "available types" / "family types":**
- Call `list_families` and/or `list_family_categories`
- Present: Family Name, Type Name, Category

**"selected" / "selection":**
- Call `get_selected_elements`
- Present details of selected elements

**"stats" / "summary" / "overview" / "model statistics":**
- Call `analyze_model_statistics`
- Present a summary table with element counts per category and totals

**"rooms" / "room data" / "areas":**
- Call `export_room_data`
- Present: Room Name, Number, Level, Area (sq m), Perimeter

**"materials" / "quantities" / "takeoff":**
- Call `get_material_quantities`
- Present: Material Name, Area (sq m), Volume (cu m), Element Count

**"color" / "visualize":**
- Ask what category and parameter to color by
- Call `color_splash`

**"clear colors" / "reset colors":**
- Call `clear_colors`

## Output Format

Present all results in markdown tables. Keep it concise. Highlight key numbers (total count, total area).

If the query returns many elements, summarize by type and show the first 20 with a note about the total count.
