@echo off
title Revit MCP - Session Startup
echo.
echo   Starting Revit MCP for Cowork...
echo.
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0start-revit-mcp.ps1"
if errorlevel 1 (
    echo.
    echo   Startup encountered an error. See messages above.
    echo.
    pause
)
