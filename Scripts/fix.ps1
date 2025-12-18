 = New-Object System.Text.UTF8Encoding True
Get-ChildItem -Recurse -Include *.pas,*.dpr | Where-Object { (Get-Content .FullName -Raw -Encoding UTF8) -match '\?\?' } | ForEach-Object {
   = Get-Content .FullName -Raw -Encoding UTF8
   = .Replace('?? Starting', [char]0x25BA + ' Starting')
   = .Replace('?? Success', [char]0x2713 + ' Success')
   = .Replace('?? Warning', [char]0x26A0 + ' Warning')
   = .Replace('?? Error', [char]0x2717 + ' Error')
  [System.IO.File]::WriteAllText(.FullName, , )
  Write-Host " Fixed:  \
}
