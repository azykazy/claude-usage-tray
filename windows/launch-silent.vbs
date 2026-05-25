' launch-silent.vbs - コンソールウィンドウなしで claude-usage-tray.ps1 を起動

Dim sh, fso, dir, ps
Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
ps  = dir & "\claude-usage-tray.ps1"

sh.Run "powershell.exe -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File """ & ps & """", 0, False
