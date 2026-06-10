# -*- coding: utf-8 -*-
"""Color tools"""

from mcp.server.fastmcp import Context
from typing import Dict, Any, Optional, List
from .utils import format_response


def register_colors_tools(mcp, revit_get, revit_post, revit_image=None):
    """Register color tools with the MCP server."""

    @mcp.tool()
    async def color_splash(
        category_name: str,
        parameter_name: str,
        use_gradient: bool = False,
        custom_colors: Optional[List[str]] = None,
        ctx: Context = None,
    ) -> str:
        """
        Color elements in a category based on parameter values

        This tool applies color coding to Revit elements within a specified category
        based on their parameter values. Elements with the same parameter value
        will receive the same color.

        Args:
            category_name: Name of the category to color (e.g., "Walls", "Doors", "Windows")
            parameter_name: Name of the parameter to use for coloring (e.g., "Mark", "Type Name")
            use_gradient: Whether to use gradient coloring instead of distinct colors (default: False)
            custom_colors: Optional list of custom colors in hex format (e.g., ["#FF0000", "#00FF00"])
            ctx: MCP context for logging

        Returns:
            Results of the coloring operation including statistics and color assignments
        """
        try:
            data = {
                "category_name": category_name,
                "parameter_name": parameter_name,
                "use_gradient": use_gradient,
            }

            if custom_colors:
                data["custom_colors"] = custom_colors

            if ctx:
                await ctx.info(
                    "Color splashing {} elements by {}".format(
                        category_name, parameter_name
                    )
                )
            response = await revit_post("/color_splash/", data, ctx)
            return format_response(response)

        except Exception as e:
            error_msg = "Error applying color splash: {}".format(str(e))
            if ctx:
                await ctx.error(error_msg)
            return error_msg

    @mcp.tool()
    async def clear_colors(category_name: str, ctx: Context = None) -> str:
        """
        Clear color overrides for elements in a category

        This tool removes all color overrides that have been applied to elements
        in the specified category, returning them to their default appearance.

        Args:
            category_name: Name of the category to clear colors from (e.g., "Walls", "Doors")
            ctx: MCP context for logging

        Returns:
            Results of the clear operation including count of elements processed
        """
        try:
            data = {"category_name": category_name}

            if ctx:
                await ctx.info("Clearing color overrides for {} elements".format(category_name))
            response = await revit_post("/clear_colors/", data, ctx)
            return format_response(response)

        except Exception as e:
            error_msg = "Error clearing colors: {}".format(str(e))
            if ctx:
                await ctx.error(error_msg)
            return error_msg

    @mcp.tool()
    async def list_category_parameters(category_name: str, ctx: Context = None) -> str:
        """
        Get available parameters for elements in a category

        This tool helps you discover what parameters are available for coloring
        by listing all parameters found on elements in the specified category.

        Args:
            category_name: Name of the category to check parameters for (e.g., "Walls", "Doors")
            ctx: MCP context for logging

        Returns:
            List of available parameters with their types and sample values
        """
        try:
            data = {"category_name": category_name}

            if ctx:
                await ctx.info(
                    "Getting available parameters for {} category".format(category_name)
                )
            response = await revit_post("/list_category_parameters/", data, ctx)
            return format_response(response)

        except Exception as e:
            error_msg = "Error listing category parameters: {}".format(str(e))
            if ctx:
                await ctx.error(error_msg)
            return error_msg
