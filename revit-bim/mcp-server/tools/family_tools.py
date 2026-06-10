# -*- coding: utf-8 -*-
"""Family and placement tools"""

from mcp.server.fastmcp import Context
from typing import Dict, Any
from .utils import format_response


def register_family_tools(mcp, revit_get, revit_post):
    """Register family-related tools"""

    @mcp.tool()
    async def place_family(
        family_name: str,
        type_name: str = None,
        x: float = 0.0,
        y: float = 0.0,
        z: float = 0.0,
        rotation: float = 0.0,
        level_name: str = None,
        properties: Dict[str, Any] = None,
        ctx: Context = None,
    ) -> str:
        """Place a family instance at a specified location in the Revit model"""
        data = {
            "family_name": family_name,
            "type_name": type_name,
            "location": {"x": x, "y": y, "z": z},
            "rotation": rotation,
            "level_name": level_name,
            "properties": properties or {},
        }
        response = await revit_post("/place_family/", data, ctx)
        return format_response(response)

    @mcp.tool()
    async def list_families(
        contains: str = None, limit: int = 50, ctx: Context = None
    ) -> str:
        """Get a flat list of available family types in the current Revit model"""
        params = {}
        if contains:
            params["contains"] = contains
        if limit != 50:
            params["limit"] = str(limit)

        result = await revit_get("/list_families/", ctx, params=params)
        return format_response(result)

    @mcp.tool()
    async def list_family_categories(ctx: Context = None) -> str:
        """Get a list of all family categories in the current Revit model"""
        response = await revit_get("/list_family_categories/", ctx)
        return format_response(response)

    @mcp.tool()
    async def load_family(file_path: str, ctx: Context = None) -> str:
        """Load a Revit family (.rfa file) from disk into the active document.

        Use this when a needed family (furniture, doors, windows, equipment) is
        not already loaded in the project — load it first, then place_family can
        place its types. The file_path must be a full path to a .rfa file
        accessible to the machine running Revit.

        Args:
            file_path: Full path to the .rfa family file, e.g.
                "C:\\ProgramData\\Autodesk\\RVT 2027\\Libraries\\English\\Furniture\\Chair.rfa"
            ctx: MCP context for logging
        """
        response = await revit_post("/load_family/", {"file_path": file_path}, ctx)
        return format_response(response)
