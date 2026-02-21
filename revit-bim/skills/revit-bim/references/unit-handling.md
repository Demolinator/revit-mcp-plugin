# Unit Handling

Rules for converting between user-facing units and Revit MCP tool units.

## The Rule

All Revit MCP tools accept **millimeters (mm)** as input. The MCP server handles conversion to Revit's internal unit (feet) automatically.

## Conversion Table

| User Says | Interpretation | Value to Send (mm) |
|-----------|---------------|-------------------|
| "3 meters" | 3 m | 3000 |
| "3 m" | 3 m | 3000 |
| "200 mm" | 200 mm | 200 |
| "200 millimeters" | 200 mm | 200 |
| "10 feet" | 10 ft | 3048 |
| "10 ft" | 10 ft | 3048 |
| "10'" | 10 ft | 3048 |
| "12 inches" | 12 in | 304.8 |
| "12 in" | 12 in | 304.8 |
| '12"' | 12 in | 304.8 |
| "10'-6\"" | 10 ft 6 in | 3200.4 |
| "4.5 m high" | 4.5 m | 4500 |

## Conversion Formulas

```
meters to mm:       value * 1000
feet to mm:         value * 304.8
inches to mm:       value * 25.4
centimeters to mm:  value * 10
```

## Common Architectural Dimensions (mm)

### Heights
| Element | Typical | Range |
|---------|---------|-------|
| Residential floor-to-floor | 3000 | 2700-3600 |
| Commercial floor-to-floor | 4000 | 3500-5000 |
| Door height | 2100 | 2000-2400 |
| Window sill height | 900 | 600-1200 |
| Window head height | 2100 | 1800-2400 |
| Ceiling height | 2700 | 2400-3600 |

### Widths
| Element | Typical | Range |
|---------|---------|-------|
| Single door | 900 | 750-1000 |
| Double door | 1800 | 1500-2000 |
| Standard window | 1200 | 600-2400 |
| Corridor width | 1500 | 1200-2400 |
| Parking bay | 2500 | 2400-2700 |

### Thicknesses
| Element | Typical | Range |
|---------|---------|-------|
| Interior partition | 120 | 100-150 |
| Exterior wall | 250 | 200-400 |
| Structural wall | 300 | 200-500 |
| Floor slab | 200 | 150-300 |
| Roof slab | 200 | 150-250 |

### Structural Spacing
| Element | Typical | Range |
|---------|---------|-------|
| Column grid spacing | 6000 | 4000-9000 |
| Beam spacing | 3000 | 2000-6000 |

## Coordinate System

Revit uses a right-hand coordinate system:
- **X** — East (positive) / West (negative)
- **Y** — North (positive) / South (negative)
- **Z** — Up (positive) / Down (negative)

All coordinate values in mm.

## Default Assumptions

When the user does not specify units, assume:
- **Dimensions** (width, height, thickness): millimeters
- **Coordinates** (x, y, z positions): millimeters
- **Large round numbers** (e.g., "15 by 10"): meters (convert to mm)
- **Small numbers with no context** (e.g., "200 thick"): millimeters

When ambiguous, ask the user to clarify.
