@echo off
title Revit MCP - One-Time Setup
echo.
echo   Starting setup...
echo.
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0setup-revit-mcp.ps1"
if errorlevel 1 (
    echo.
    echo   Setup encountered an error. See messages above.
    echo.
    pause
)
