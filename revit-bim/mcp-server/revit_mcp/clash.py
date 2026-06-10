# -*- coding: UTF-8 -*-
"""
Clash / Interference Detection Module for Revit MCP

Detects hard clashes (geometric interferences) between building elements using
Revit's native ElementIntersectsElementFilter — the same intersection logic
Revit's built-in Interference Check uses.

Best-practice notes (see ElementIntersectsElementFilter docs):
  - It is a *slow* filter, so it is always paired with a quick category filter
    (ElementMulticategoryFilter) to minimise the number of elements expanded.
  - Some interferences are never reported: elements that auto-join (e.g. concrete
    members joined at intersections) and elements with no solid geometry
    (e.g. rebar). This is a Revit limitation, not a bug in this tool.
"""

from pyrevit import routes, revit, DB
from System.Collections.Generic import List
import json
import logging
import traceback

from utils import get_element_name, get_element_id_value

logger = logging.getLogger(__name__)

# Friendly-name aliases so callers don't have to know exact BuiltInCategory ids.
_FRIENDLY = {
    "walls": "OST_Walls",
    "floors": "OST_Floors",
    "roofs": "OST_Roofs",
    "ceilings": "OST_Ceilings",
    "columns": "OST_Columns",
    "structural columns": "OST_StructuralColumns",
    "structural framing": "OST_StructuralFraming",
    "framing": "OST_StructuralFraming",
    "beams": "OST_StructuralFraming",
    "foundations": "OST_StructuralFoundation",
    "ducts": "OST_DuctCurves",
    "duct fittings": "OST_DuctFitting",
    "pipes": "OST_PipeCurves",
    "pipe fittings": "OST_PipeFitting",
    "cable trays": "OST_CableTray",
    "conduits": "OST_Conduit",
    "plumbing fixtures": "OST_PlumbingFixtures",
    "mechanical equipment": "OST_MechanicalEquipment",
    "generic models": "OST_GenericModel",
    "doors": "OST_Doors",
    "windows": "OST_Windows",
}

# Sensible default scope: the physical architectural, structural and MEP
# categories most coordination workflows care about.
_DEFAULT_CATEGORIES = [
    "OST_Walls", "OST_Floors", "OST_Roofs", "OST_Ceilings",
    "OST_StructuralFraming", "OST_StructuralColumns", "OST_StructuralFoundation",
    "OST_Columns",
    "OST_DuctCurves", "OST_DuctFitting", "OST_PipeCurves", "OST_PipeFitting",
    "OST_CableTray", "OST_Conduit", "OST_MechanicalEquipment",
]


def _resolve_bic(name):
    """Resolve a category name (BuiltInCategory id or friendly alias) to a BuiltInCategory."""
    if not name:
        return None
    n = str(name).strip()
    if not n.startswith("OST_"):
        n = _FRIENDLY.get(n.lower(), n)
    return getattr(DB.BuiltInCategory, n, None)


def _resolve_categories(names):
    """Resolve a list of names to (valid_bics, unknown_names)."""
    bics = []
    unknown = []
    for name in names:
        bic = _resolve_bic(name)
        if bic is None:
            unknown.append(name)
        else:
            bics.append(bic)
    return bics, unknown


def _multicategory_filter(bics):
    cats = List[DB.BuiltInCategory]()
    for b in bics:
        cats.Add(b)
    return DB.ElementMulticategoryFilter(cats)


def _location_mm(elem):
    """Return the centre of the element's bounding box in mm, or None."""
    try:
        bb = elem.get_BoundingBox(None)
        if not bb:
            return None
        cx = (bb.Min.X + bb.Max.X) / 2.0 * 304.8
        cy = (bb.Min.Y + bb.Max.Y) / 2.0 * 304.8
        cz = (bb.Min.Z + bb.Max.Z) / 2.0 * 304.8
        return {"x": round(cx, 1), "y": round(cy, 1), "z": round(cz, 1)}
    except Exception:
        return None


def _describe(elem):
    cat = "Unknown"
    try:
        if elem.Category:
            cat = elem.Category.Name
    except Exception:
        pass
    return {
        "id": get_element_id_value(elem),
        "name": get_element_name(elem),
        "category": cat,
    }


def register_clash_routes(api):
    """Register clash/interference detection routes with the API."""

    @api.route("/clash_check/", methods=["POST"])
    def clash_check(doc, request):
        """
        Detect hard clashes (geometric interferences) between elements.

        Payload (all optional):
        {
            "set_a_categories": ["OST_StructuralFraming", "beams"],
            "set_b_categories": ["OST_DuctCurves", "pipes"],
            "max_clashes": 200
        }

        - If neither set is given, a default physical scope is checked against itself.
        - If only set_a is given, set_a is checked against itself.
        - If both are given, set_a is checked against set_b (cross-discipline).
        """
        try:
            if not doc:
                return routes.make_response(
                    data={"error": "No active Revit document"}, status=503
                )

            data = {}
            if request and request.data:
                data = json.loads(request.data) if isinstance(request.data, str) else request.data

            max_clashes = int(data.get("max_clashes", 200))
            a_names = data.get("set_a_categories") or []
            b_names = data.get("set_b_categories") or []

            if not a_names and not b_names:
                a_names = list(_DEFAULT_CATEGORIES)

            a_bics, a_unknown = _resolve_categories(a_names)
            if b_names:
                b_bics, b_unknown = _resolve_categories(b_names)
            else:
                # Self-check: B mirrors A.
                b_bics, b_unknown = list(a_bics), []

            if not a_bics or not b_bics:
                return routes.make_response(
                    data={
                        "error": "No valid categories to check",
                        "unknown_categories": a_unknown + b_unknown,
                        "hint": "Use BuiltInCategory ids like OST_Walls or aliases like 'ducts', 'beams'.",
                    },
                    status=400,
                )

            # Set A elements (iterate these; keep the smaller native quick-filtered set).
            set_a = list(
                DB.FilteredElementCollector(doc)
                .WherePasses(_multicategory_filter(a_bics))
                .WhereElementIsNotElementType()
            )

            b_filter = _multicategory_filter(b_bics)

            clashes = []
            seen = set()
            truncated = False

            for elem in set_a:
                try:
                    eid = get_element_id_value(elem)
                    # Native pass: B-category quick filter + slow intersection filter.
                    hits = (
                        DB.FilteredElementCollector(doc)
                        .WherePasses(b_filter)
                        .WhereElementIsNotElementType()
                        .WherePasses(DB.ElementIntersectsElementFilter(elem))
                    )
                    for hit in hits:
                        hid = get_element_id_value(hit)
                        if hid == eid:
                            continue
                        pair = (eid, hid) if eid < hid else (hid, eid)
                        if pair in seen:
                            continue
                        seen.add(pair)
                        clashes.append({
                            "element_a": _describe(elem),
                            "element_b": _describe(hit),
                            "location_mm": _location_mm(hit) or _location_mm(elem),
                        })
                        if len(clashes) >= max_clashes:
                            truncated = True
                            break
                except Exception as elem_err:
                    logger.warning("Clash check failed for one element: {}".format(str(elem_err)))
                    continue
                if truncated:
                    break

            return routes.make_response(data={
                "status": "success",
                "clash_count": len(clashes),
                "truncated": truncated,
                "checked": {
                    "set_a_categories": a_names,
                    "set_b_categories": b_names if b_names else a_names,
                    "set_a_element_count": len(set_a),
                },
                "clashes": clashes,
                "message": "Found {} clash(es)".format(len(clashes)),
                "note": "Auto-joined concrete and geometry-less elements (e.g. rebar) are not reported by Revit's interference logic.",
            })

        except Exception as e:
            logger.error("clash_check failed: {}".format(str(e)))
            return routes.make_response(
                data={"error": str(e), "traceback": traceback.format_exc()},
                status=500,
            )

    logger.info("Clash detection routes registered successfully")
