---
description: Modify, delete, or update elements in the Revit model
allowed-tools: ["mcp__revit__modify_element", "mcp__revit__delete_elements", "mcp__revit__get_selected_elements", "mcp__revit__ai_element_filter", "mcp__revit__get_current_view_elements"]
argument-hint: [what to modify, e.g., "delete the selected walls", "set Mark to EW-01"]
---

Modify, delete, or update elements in the Revit model based on user instructions.

## Determine Action

Based on `$ARGUMENTS`:

**"delete" / "remove":**
1. Identify elements to delete — by selection (`get_selected_elements`), by filter (`ai_element_filter`), or by IDs
2. Confirm with the user before deleting (show count and types)
3. Call `delete_elements` with the element IDs
4. Report deleted count and any cascaded deletions (hosted elements)

**"modify" / "change" / "set" / "update":**
1. Identify the target element(s) — by selection, filter, or ID
2. Identify which parameters to change and new values
3. Call `modify_element` for each element
4. Report old and new values for confirmation

**"select" / "what's selected":**
1. Call `get_selected_elements`
2. Present: ID, Category, Type, Level, Key Parameters

**"find" / "filter":**
1. Call `ai_element_filter` with appropriate category and criteria
2. Present matching elements in a table

## Rules

- Always confirm destructive operations (delete) before executing
- Report cascaded deletions (e.g., deleting a wall also removes hosted doors)
- When modifying, show old values alongside new values
- If element IDs are needed but not provided, help the user find them via selection or filtering
