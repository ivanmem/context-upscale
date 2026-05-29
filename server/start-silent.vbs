Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
WshShell.CurrentDirectory = scriptDir
pythonExe = fso.BuildPath(scriptDir, ".venv\Scripts\python.exe")
appPy = fso.BuildPath(scriptDir, "app.py")
WshShell.Run """" & pythonExe & """ """ & appPy & """", 0, False
