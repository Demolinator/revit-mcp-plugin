@echo off
title Revit MCP - Optional Web/Mobile (ngrok) Setup
echo.
echo   Setting up the OPTIONAL ngrok remote connector for use from
echo   claude.ai web / phone. Not needed for Claude Desktop / Cowork.
echo.
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0setup-web-mobile.ps1"
if errorlevel 1 (
    echo.
    echo   Setup encountered an error. See messages above.
    echo.
    pause
)
