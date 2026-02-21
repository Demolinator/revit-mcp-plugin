# MEP Workflows (Tier 2)

IronPython code templates for MEP operations using `execute_revit_code`. These cover operations beyond the 31 dedicated tools.

## Important: IronPython 2.7 Constraints

All code sent via `execute_revit_code` runs in IronPython 2.7 inside Revit. You MUST:
- Use `.format()` for strings — NO f-strings
- NO type hints
- Use `element.Id.Value` — NOT `.IntegerValue`
- Wrap mutations in `DB.Transaction`

## Common MEP Categories

```python
# BuiltInCategory references for MEP
DB.BuiltInCategory.OST_DuctCurves        # Ducts
DB.BuiltInCategory.OST_PipeCurves         # Pipes
DB.BuiltInCategory.OST_Conduit            # Conduit
DB.BuiltInCategory.OST_CableTray          # Cable Tray
DB.BuiltInCategory.OST_MechanicalEquipment # AHUs, etc.
DB.BuiltInCategory.OST_PlumbingFixtures   # Sinks, toilets
DB.BuiltInCategory.OST_ElectricalFixtures # Outlets, switches
DB.BuiltInCategory.OST_LightingFixtures   # Light fixtures
DB.BuiltInCategory.OST_Sprinklers         # Fire sprinklers
```

## Create a Duct Run

```python
import clr
clr.AddReference('RevitAPI')
from Autodesk.Revit.DB import *
from Autodesk.Revit.DB.Mechanical import *

doc = __revit__.ActiveUIDocument.Document

# Find a duct type
duct_types = FilteredElementCollector(doc).OfClass(DuctType).ToElements()
if not duct_types:
    result = "No duct types found"
else:
    duct_type = duct_types[0]

    # Find a level
    levels = FilteredElementCollector(doc).OfCategory(BuiltInCategory.OST_Levels).WhereElementIsNotElementType().ToElements()
    level = levels[0]

    t = Transaction(doc, "Create Duct")
    t.Start()

    start = XYZ(0, 0, 10)  # feet
    end = XYZ(30, 0, 10)   # feet

    duct = Duct.Create(doc, duct_type.Id, level.Id, None, start, end)

    # Set width and height for rectangular ducts
    width_param = duct.LookupParameter("Width")
    height_param = duct.LookupParameter("Height")
    if width_param:
        width_param.Set(1.0)  # 1 foot = 304.8mm
    if height_param:
        height_param.Set(0.5)  # 0.5 feet

    t.Commit()
    result = "Created duct ID: {}".format(duct.Id.Value)
```

## Create a Pipe Run

```python
from Autodesk.Revit.DB.Plumbing import *

doc = __revit__.ActiveUIDocument.Document

pipe_types = FilteredElementCollector(doc).OfClass(PipeType).ToElements()
if not pipe_types:
    result = "No pipe types found"
else:
    pipe_type = pipe_types[0]
    levels = FilteredElementCollector(doc).OfCategory(BuiltInCategory.OST_Levels).WhereElementIsNotElementType().ToElements()
    level = levels[0]

    # Find MEP system type
    sys_types = FilteredElementCollector(doc).OfClass(PipingSystemType).ToElements()
    sys_type = sys_types[0] if sys_types else None

    t = Transaction(doc, "Create Pipe")
    t.Start()

    start = XYZ(0, 0, 8)   # feet
    end = XYZ(20, 0, 8)    # feet

    pipe = Pipe.Create(doc, sys_type.Id if sys_type else pipe_type.Id, pipe_type.Id, level.Id, start, end)

    # Set diameter
    diam_param = pipe.LookupParameter("Diameter")
    if diam_param:
        diam_param.Set(0.25)  # 0.25 feet = ~75mm

    t.Commit()
    result = "Created pipe ID: {}".format(pipe.Id.Value)
```

## Query MEP Systems

```python
doc = __revit__.ActiveUIDocument.Document

# Get all mechanical systems
systems = FilteredElementCollector(doc).OfCategory(BuiltInCategory.OST_MechanicalSystem).WhereElementIsNotElementType().ToElements()

system_info = []
for sys in systems:
    try:
        name = sys.Name if hasattr(sys, 'Name') else "Unknown"
        system_info.append("System: {} (ID: {})".format(name, sys.Id.Value))
    except:
        continue

result = "\n".join(system_info) if system_info else "No MEP systems found"
```

## Space and Zone Management

```python
doc = __revit__.ActiveUIDocument.Document

# Get all spaces (MEP spaces, not rooms)
spaces = FilteredElementCollector(doc).OfCategory(BuiltInCategory.OST_MEPSpaces).WhereElementIsNotElementType().ToElements()

space_data = []
for space in spaces:
    try:
        name = space.get_Parameter(BuiltInParameter.ROOM_NAME).AsString() or "Unnamed"
        number = space.get_Parameter(BuiltInParameter.ROOM_NUMBER).AsString() or ""
        area = space.get_Parameter(BuiltInParameter.ROOM_AREA).AsDouble() * 0.0929  # sqft to sqm
        space_data.append("{} {} - {:.1f} sqm".format(number, name, area))
    except:
        continue

result = "\n".join(space_data) if space_data else "No MEP spaces found"
```
