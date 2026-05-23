Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
WshShell.CurrentDirectory = scriptDir
pythonExe = fso.BuildPath(scriptDir, ".venv\Scripts\python.exe")
appPy = fso.BuildPath(scriptDir, "app.py")
cmdLine = "cmd /c start /min """" """ & pythonExe & """ """ & appPy & """"
WshShell.Run cmdLine, 0, False
