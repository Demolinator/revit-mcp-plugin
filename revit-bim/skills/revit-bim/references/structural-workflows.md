# Structural Workflows (Tier 2)

IronPython code templates for advanced structural operations using `execute_revit_code`. These cover operations beyond `create_grid` and `create_structural_framing`.

## Important: IronPython 2.7 Constraints

All code sent via `execute_revit_code` runs in IronPython 2.7 inside Revit. You MUST:
- Use `.format()` for strings — NO f-strings
- NO type hints
- Use `element.Id.Value` — NOT `.IntegerValue`
- Wrap mutations in `DB.Transaction`

## Create Foundation

```python
doc = __revit__.ActiveUIDocument.Document

# Find foundation types
found_types = FilteredElementCollector(doc).OfCategory(BuiltInCategory.OST_StructuralFoundation).OfClass(FamilySymbol).ToElements()

if not found_types:
    result = "No foundation types found — load foundation families"
else:
    symbol = found_types[0]
    levels = FilteredElementCollector(doc).OfCategory(BuiltInCategory.OST_Levels).WhereElementIsNotElementType().ToElements()
    base_level = sorted(levels, key=lambda l: l.Elevation)[0]

    t = Transaction(doc, "Create Foundation")
    t.Start()

    if not symbol.IsActive:
        symbol.Activate()
        doc.Regenerate()

    # Place isolated footing at a point
    point = XYZ(0, 0, 0)  # feet
    foundation = doc.Create.NewFamilyInstance(
        point, symbol, base_level, Structure.StructuralType.Footing
    )

    t.Commit()
    result = "Created foundation ID: {}".format(foundation.Id.Value)
```

## Create Brace / Diagonal Member

```python
doc = __revit__.ActiveUIDocument.Document

# Find structural framing types (used for braces)
framing_types = FilteredElementCollector(doc).OfCategory(BuiltInCategory.OST_StructuralFraming).OfClass(FamilySymbol).ToElements()

if not framing_types:
    result = "No framing types found"
else:
    symbol = framing_types[0]
    levels = FilteredElementCollector(doc).OfCategory(BuiltInCategory.OST_Levels).WhereElementIsNotElementType().ToElements()
    level = levels[0]

    t = Transaction(doc, "Create Brace")
    t.Start()

    if not symbol.IsActive:
        symbol.Activate()
        doc.Regenerate()

    # Diagonal brace from bottom of column to top of adjacent column
    start = XYZ(0, 0, 0)       # feet - base of column A
    end = XYZ(20, 0, 13.12)    # feet - top of column B (4m = 13.12ft)

    curve = Line.CreateBound(start, end)
    brace = doc.Create.NewFamilyInstance(
        curve, symbol, level, Structure.StructuralType.Brace
    )

    t.Commit()
    result = "Created brace ID: {}".format(brace.Id.Value)
```

## Query Structural Analytical Model

```python
doc = __revit__.ActiveUIDocument.Document

# Get structural columns with analytical info
columns = FilteredElementCollector(doc).OfCategory(BuiltInCategory.OST_StructuralColumns).WhereElementIsNotElementType().ToElements()

col_info = []
for col in columns:
    try:
        col_id = col.Id.Value
        loc = col.Location
        if hasattr(loc, 'Point'):
            pt = loc.Point
            col_info.append("Column {} at ({:.1f}, {:.1f}, {:.1f}) ft".format(
                col_id, pt.X, pt.Y, pt.Z
            ))
    except:
        continue

result = "Found {} structural columns:\n{}".format(
    len(col_info),
    "\n".join(col_info[:20])
)
```

## Structural Element Summary

```python
doc = __revit__.ActiveUIDocument.Document

categories = [
    ("Columns", BuiltInCategory.OST_StructuralColumns),
    ("Framing", BuiltInCategory.OST_StructuralFraming),
    ("Foundations", BuiltInCategory.OST_StructuralFoundation),
    ("Walls (Structural)", BuiltInCategory.OST_Walls),
]

summary = []
for name, bic in categories:
    try:
        count = FilteredElementCollector(doc).OfCategory(bic).WhereElementIsNotElementType().GetElementCount()
        summary.append("{}: {}".format(name, count))
    except:
        summary.append("{}: error".format(name))

result = "Structural Summary:\n" + "\n".join(summary)
```
