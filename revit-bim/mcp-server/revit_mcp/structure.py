# -*- coding: UTF-8 -*-
"""
Structure Module for Revit MCP
Handles grid creation and structural framing placement
"""

from utils import get_element_name, find_family_symbol_safely, get_element_id_value, suppress_warnings
from pyrevit import routes, revit, DB
import json
import traceback
import logging

logger = logging.getLogger(__name__)

MM_TO_FEET = 1.0 / 304.8


def register_structure_routes(api):
    """Register all structure routes with the API"""

    @api.route("/create_grid/", methods=["POST"])
    def create_grid_handler(doc, request):
        """Create grid lines in the Revit model."""
        try:
            if not doc:
                return routes.make_response(
                    data={"error": "No active Revit document"}, status=503
                )

            if not request or not request.data:
                return routes.make_response(
                    data={"error": "No data provided"}, status=400
                )

            data = json.loads(request.data) if isinstance(request.data, str) else request.data

            grids = data.get("grids", [])
            if not grids:
                return routes.make_response(
                    data={"error": "No grids provided"}, status=400
                )

            t = DB.Transaction(doc, "Create Grids via MCP")
            t.Start()
            suppress_warnings(t)

            try:
                created = []

                for i, grid_def in enumerate(grids):
                    sp = grid_def.get("start_point", {})
                    ep = grid_def.get("end_point", {})
                    name = grid_def.get("name")

                    # Convert mm to feet
                    start = DB.XYZ(
                        float(sp.get("x", 0)) * MM_TO_FEET,
                        float(sp.get("y", 0)) * MM_TO_FEET,
                        float(sp.get("z", 0)) * MM_TO_FEET,
                    )
                    end = DB.XYZ(
                        float(ep.get("x", 0)) * MM_TO_FEET,
                        float(ep.get("y", 0)) * MM_TO_FEET,
                        float(ep.get("z", 0)) * MM_TO_FEET,
                    )

                    # Validate non-zero length
                    length = start.DistanceTo(end)
                    if length < 0.001:
                        logger.warning("Grid {} has zero length, skipping".format(i))
                        continue

                    line = DB.Line.CreateBound(start, end)
                    grid = DB.Grid.Create(doc, line)

                    if name:
                        try:
                            grid.Name = name
                        except Exception as name_err:
                            logger.warning("Could not set grid name '{}': {}".format(
                                name, str(name_err)
                            ))

                    grid_name = get_element_name(grid)
                    created.append({
                        "id": get_element_id_value(grid),
                        "name": grid_name,
                    })

                t.Commit()

                message = "Created {} grid line{}".format(
                    len(created),
                    "s" if len(created) != 1 else ""
                )

                return routes.make_response(
                    data={
                        "status": "success",
                        "created": created,
                        "count": len(created),
                        "message": message,
                    }
                )

            except Exception as tx_error:
                if t.HasStarted() and not t.HasEnded():
                    t.RollBack()
                raise tx_error

        except Exception as e:
            logger.error("Failed to create grids: {}".format(str(e)))
            error_trace = traceback.format_exc()
            return routes.make_response(
                data={"error": str(e), "traceback": error_trace}, status=500
            )

    @api.route("/create_framing/", methods=["POST"])
    def create_framing_handler(doc, request):
        """Create structural framing (beams) in the Revit model."""
        try:
            if not doc:
                return routes.make_response(
                    data={"error": "No active Revit document"}, status=503
                )

            if not request or not request.data:
                return routes.make_response(
                    data={"error": "No data provided"}, status=400
                )

            data = json.loads(request.data) if isinstance(request.data, str) else request.data

            elements = data.get("elements", [])
            if not elements:
                return routes.make_response(
                    data={"error": "No elements provided"}, status=400
                )

            # Find structural framing types
            framing_symbols = (
                DB.FilteredElementCollector(doc)
                .OfCategory(DB.BuiltInCategory.OST_StructuralFraming)
                .OfClass(DB.FamilySymbol)
                .ToElements()
            )

            if not framing_symbols or len(framing_symbols) == 0:
                return routes.make_response(
                    data={"error": "No structural framing types found — load beam families into the project"},
                    status=404,
                )

            # Get available levels
            levels = (
                DB.FilteredElementCollector(doc)
                .OfCategory(DB.BuiltInCategory.OST_Levels)
                .WhereElementIsNotElementType()
                .ToElements()
            )

            t = DB.Transaction(doc, "Create Structural Framing via MCP")
            t.Start()
            suppress_warnings(t)

            try:
                created = []

                for elem_def in elements:
                    sp = elem_def.get("start_point", {})
                    ep = elem_def.get("end_point", {})
                    type_name = elem_def.get("type_name")
                    level_name = elem_def.get("level_name")
                    name = elem_def.get("name", "")

                    # Convert mm to feet
                    start = DB.XYZ(
                        float(sp.get("x", 0)) * MM_TO_FEET,
                        float(sp.get("y", 0)) * MM_TO_FEET,
                        float(sp.get("z", 0)) * MM_TO_FEET,
                    )
                    end = DB.XYZ(
                        float(ep.get("x", 0)) * MM_TO_FEET,
                        float(ep.get("y", 0)) * MM_TO_FEET,
                        float(ep.get("z", 0)) * MM_TO_FEET,
                    )

                    # Validate non-zero length
                    length = start.DistanceTo(end)
                    if length < 0.001:
                        logger.warning("Beam has zero length, skipping")
                        continue

                    # Find the beam type
                    target_symbol = None
                    if type_name:
                        for sym in framing_symbols:
                            try:
                                sym_name = get_element_name(sym)
                                if sym_name == type_name:
                                    target_symbol = sym
                                    break
                            except Exception:
                                continue

                    if not target_symbol:
                        target_symbol = framing_symbols[0]

                    # Find level
                    target_level = None
                    if level_name:
                        for level in levels:
                            try:
                                if get_element_name(level) == level_name:
                                    target_level = level
                                    break
                            except Exception:
                                continue

                    if not target_level and levels:
                        target_level = levels[0]

                    # Activate symbol
                    if not target_symbol.IsActive:
                        target_symbol.Activate()
                        doc.Regenerate()

                    # Place the beam at its level's elevation. NewFamilyInstance
                    # positions a beam at the curve's Z, so without this a beam
                    # given level_name="L40" + z=0 points would land at Z=0 instead
                    # of on that level (inconsistent with walls/floors, which
                    # extrude from their level). The provided point z is preserved
                    # as an offset from the level.
                    level_elev = 0.0
                    try:
                        if target_level is not None:
                            level_elev = target_level.Elevation
                    except Exception:
                        level_elev = 0.0
                    if abs(level_elev) > 1e-9:
                        start = DB.XYZ(start.X, start.Y, start.Z + level_elev)
                        end = DB.XYZ(end.X, end.Y, end.Z + level_elev)

                    # Create curve for beam
                    curve = DB.Line.CreateBound(start, end)

                    # Create the beam
                    beam = doc.Create.NewFamilyInstance(
                        curve,
                        target_symbol,
                        target_level,
                        DB.Structure.StructuralType.Beam,
                    )

                    beam_type = get_element_name(target_symbol)
                    beam_level = get_element_name(target_level) if target_level else "Unknown"

                    created.append({
                        "id": get_element_id_value(beam),
                        "name": name,
                        "type": beam_type,
                        "level": beam_level,
                    })

                t.Commit()

                level_msg = ""
                if created and created[0].get("level"):
                    level_msg = " on {}".format(created[0]["level"])

                message = "Created {} structural framing element{}{}".format(
                    len(created),
                    "s" if len(created) != 1 else "",
                    level_msg,
                )

                return routes.make_response(
                    data={
                        "status": "success",
                        "created": created,
                        "count": len(created),
                        "message": message,
                    }
                )

            except Exception as tx_error:
                if t.HasStarted() and not t.HasEnded():
                    t.RollBack()
                raise tx_error

        except Exception as e:
            logger.error("Failed to create framing: {}".format(str(e)))
            error_trace = traceback.format_exc()
            return routes.make_response(
                data={"error": str(e), "traceback": error_trace}, status=500
            )

    logger.info("Structure routes registered successfully")
