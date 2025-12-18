@echo off
echo Fixing Unicode symbols in source files...
powershell -NoProfile -Command ^
"$utf8 = New-Object System.Text.UTF8Encoding $true; " ^
"Get-ChildItem -Recurse -Include *.pas,*.dpr | " ^
"Where-Object { (Get-Content $_.FullName -Raw -Encoding UTF8) -match '\?\?' } | " ^
"ForEach-Object { " ^
"  $content = Get-Content $_.FullName -Raw -Encoding UTF8; " ^
"  $content = $content.Replace('?? Starting', [char]0x25BA + ' Starting'); " ^
"  $content = $content.Replace('?? Building', [char]0x25BA + ' Building'); " ^
"  $content = $content.Replace('?? Running', [char]0x25BA + ' Running'); " ^
"  $content = $content.Replace('?? Testing', [char]0x25BA + ' Testing'); " ^
"  $content = $content.Replace('?? Loading', [char]0x25BA + ' Loading'); " ^
"  $content = $content.Replace('?? Success', [char]0x2713 + ' Success'); " ^
"  $content = $content.Replace('?? Completed', [char]0x2713 + ' Completed'); " ^
"  $content = $content.Replace('?? Passed', [char]0x2713 + ' Passed'); " ^
"  $content = $content.Replace('?? OK', [char]0x2713 + ' OK'); " ^
"  $content = $content.Replace('?? Warning', [char]0x26A0 + ' Warning'); " ^
"  $content = $content.Replace('?? Error', [char]0x2717 + ' Error'); " ^
"  $content = $content.Replace('?? Failed', [char]0x2717 + ' Failed'); " ^
"  [System.IO.File]::WriteAllText($_.FullName, $content, $utf8); " ^
"  Write-Host ('Fixed: ' + $_.Name) " ^
"}"
echo Done!
