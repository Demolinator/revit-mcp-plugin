# Documentation Workflows (Tier 2)

IronPython code templates for advanced documentation operations using `execute_revit_code`. These cover operations beyond `create_dimensions`, `tag_walls`, `create_sheet`, `create_schedule`, and `export_document`.

## Important: IronPython 2.7 Constraints

All code sent via `execute_revit_code` runs in IronPython 2.7 inside Revit. You MUST:
- Use `.format()` for strings — NO f-strings
- NO type hints
- Use `element.Id.Value` — NOT `.IntegerValue`
- Wrap mutations in `DB.Transaction`

## Apply View Template

```python
doc = __revit__.ActiveUIDocument.Document

# Get all view templates
views = FilteredElementCollector(doc).OfClass(View).ToElements()
templates = [v for v in views if v.IsTemplate]

if not templates:
    result = "No view templates found"
else:
    # List available templates
    template_names = []
    for tmpl in templates:
        try:
            template_names.append("{}: {}".format(tmpl.Id.Value, tmpl.Name))
        except:
            continue

    # Apply first template to active view
    active_view = doc.ActiveView
    target_template = templates[0]

    t = Transaction(doc, "Apply View Template")
    t.Start()
    active_view.ViewTemplateId = target_template.Id
    t.Commit()

    result = "Applied template '{}' to view '{}'\nAvailable templates:\n{}".format(
        target_template.Name,
        active_view.Name,
        "\n".join(template_names)
    )
```

## Create Revision Cloud

```python
doc = __revit__.ActiveUIDocument.Document

active_view = doc.ActiveView

# Get or create a revision
revisions = FilteredElementCollector(doc).OfCategory(BuiltInCategory.OST_Revisions).WhereElementIsNotElementType().ToElements()

if not revisions:
    t = Transaction(doc, "Create Revision")
    t.Start()
    revision = Revision.Create(doc)
    revision.Description = "Design Update"
    t.Commit()
else:
    revision = revisions[-1]  # Use latest revision

t = Transaction(doc, "Create Revision Cloud")
t.Start()

# Create a rectangular cloud boundary
from System.Collections.Generic import List
curves = List[Curve]()
p1 = XYZ(0, 0, 0)
p2 = XYZ(10, 0, 0)
p3 = XYZ(10, 10, 0)
p4 = XYZ(0, 10, 0)

curves.Add(Line.CreateBound(p1, p2))
curves.Add(Line.CreateBound(p2, p3))
curves.Add(Line.CreateBound(p3, p4))
curves.Add(Line.CreateBound(p4, p1))

cloud = RevisionCloud.Create(doc, active_view, revision.Id, curves)

t.Commit()
result = "Created revision cloud ID: {}".format(cloud.Id.Value)
```

## Place a View on a Sheet

```python
doc = __revit__.ActiveUIDocument.Document

# Find a sheet and a view to place
sheets = FilteredElementCollector(doc).OfClass(ViewSheet).ToElements()
floor_plans = FilteredElementCollector(doc).OfClass(ViewPlan).ToElements()

placeable_views = [v for v in floor_plans if not v.IsTemplate and Viewport.CanAddViewToSheet(doc, sheets[0].Id, v.Id)] if sheets and floor_plans else []

if not sheets:
    result = "No sheets found — create a sheet first"
elif not placeable_views:
    result = "No views available to place on sheet"
else:
    sheet = sheets[0]
    view = placeable_views[0]

    t = Transaction(doc, "Place View on Sheet")
    t.Start()

    # Place at center of sheet
    center = XYZ(1.0, 0.75, 0)  # Approximate center in feet
    viewport = Viewport.Create(doc, sheet.Id, view.Id, center)

    t.Commit()
    result = "Placed '{}' on sheet {} (viewport ID: {})".format(
        view.Name, sheet.SheetNumber, viewport.Id.Value
    )
```

## List All Sheets with Views

```python
doc = __revit__.ActiveUIDocument.Document

sheets = FilteredElementCollector(doc).OfClass(ViewSheet).ToElements()

sheet_info = []
for sheet in sheets:
    try:
        viewports = sheet.GetAllViewports()
        view_names = []
        for vp_id in viewports:
            vp = doc.GetElement(vp_id)
            if vp:
                view = doc.GetElement(vp.ViewId)
                if view:
                    view_names.append(view.Name)

        sheet_info.append("{} - {} ({} views: {})".format(
            sheet.SheetNumber,
            sheet.Name,
            len(view_names),
            ", ".join(view_names) if view_names else "empty"
        ))
    except:
        continue

result = "Sheets ({}):\n{}".format(
    len(sheet_info),
    "\n".join(sheet_info) if sheet_info else "No sheets found"
)
```

## Print Setup Configuration

```python
doc = __revit__.ActiveUIDocument.Document

# Get print manager
print_mgr = doc.PrintManager

result_lines = []
result_lines.append("Print Manager Info:")
result_lines.append("  Printer: {}".format(print_mgr.PrinterName))

try:
    result_lines.append("  Print Range: {}".format(print_mgr.PrintRange))
    result_lines.append("  Combined: {}".format(print_mgr.CombinedFile))
except:
    pass

# List available print settings
settings = FilteredElementCollector(doc).OfClass(PrintSetting).ToElements()
for s in settings[:10]:
    try:
        result_lines.append("  Setting: {}".format(s.Name))
    except:
        continue

result = "\n".join(result_lines)
```
