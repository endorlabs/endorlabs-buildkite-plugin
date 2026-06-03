@ECHO OFF
SETLOCAL EnableExtensions
REM Buildkite selects hooks/post-command.bat on Windows before the extensionless hook.
REM Implementation is Bash (lib/*.bash); delegate to Git Bash / MSYS bash.
SET "HOOK_DIR=%~dp0"
SET "PLUGIN_ROOT=%HOOK_DIR%.."
WHERE bash >NUL 2>&1
IF ERRORLEVEL 1 (
  ECHO +++ endorlabs plugin: bash is required on Windows ^(Git for Windows / Git Bash^). See README.
  EXIT /B 1
)
CD /D "%PLUGIN_ROOT%"
bash "%HOOK_DIR%post-command" %*
EXIT /B %ERRORLEVEL%
