---
description: Analyze the Revit model for statistics, rooms, materials, and element queries
allowed-tools: ["mcp__revit__analyze_model_statistics", "mcp__revit__export_room_data", "mcp__revit__get_material_quantities", "mcp__revit__ai_element_filter", "mcp__revit__get_current_view_elements", "mcp__revit__create_schedule"]
argument-hint: [what to analyze, e.g., "model statistics", "room areas", "material quantities"]
---

Analyze the Revit model and present findings in clear, structured tables.

## Determine Analysis Type

Based on `$ARGUMENTS`:

**"statistics" / "stats" / "overview" / "element counts":**
- Call `analyze_model_statistics`
- Present: element counts per category, totals
- Highlight key metrics: total elements, most common category

**"rooms" / "room data" / "areas" / "spaces":**
- Call `export_room_data`
- Present: Room Name, Number, Level, Area (sq m), Perimeter (mm), Department
- Calculate totals: total area, rooms per level

**"materials" / "quantities" / "takeoff" / "material quantities":**
- Call `get_material_quantities` (optionally filter by categories)
- Present: Material Name, Area (sq m), Volume (cu m), Element Count
- Highlight: total materials, largest volumes

**"filter" / "find" / specific element queries:**
- Call `ai_element_filter` with category, type, visibility, or bounding box filters
- Present matching elements with IDs, types, levels, dimensions

**"schedule" / "create a schedule":**
- Call `create_schedule` with appropriate category and fields
- Report: schedule name, fields, row count

## Output Format

- Use markdown tables for all structured data
- Include summary totals at the bottom of tables
- Round areas to 2 decimal places, volumes to 3
- If results exceed 20 rows, show top 20 with total count noted
