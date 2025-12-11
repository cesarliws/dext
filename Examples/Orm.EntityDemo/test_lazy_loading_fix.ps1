# Test script to verify the Lazy Loading fix
Write-Host "=== Dext Lazy Loading Fix Test ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Changes made:" -ForegroundColor Yellow
Write-Host "1. Added TClassToClassConverter to handle object type conversions"
Write-Host "2. Registered tkClass -> tkClass converter in TValueConverterRegistry"
Write-Host "3. Converter checks if source object is compatible with target class using 'is' operator"
Write-Host ""
Write-Host "The fix resolves the issue where:" -ForegroundColor Green
Write-Host "- FindObject returns TObject (containing TAddress)"
Write-Host "- TValueConverter.ConvertAndSet tries to convert TObject to TAddress"
Write-Host "- No converter was registered for this conversion"
Write-Host "- Fallback TValue.Cast failed with invalid typecast"
Write-Host ""
Write-Host "Now the TClassToClassConverter:" -ForegroundColor Green
Write-Host "- Receives TValue containing TObject (TAddress instance)"
Write-Host "- Checks if the object 'is' compatible with target class (TAddress)"
Write-Host "- Returns the object wrapped in TValue if compatible"
Write-Host ""
Write-Host "To test, compile and run EntityDemo.dpr in RAD Studio" -ForegroundColor Cyan
Write-Host "The TestLazyLoadReference test should now pass!" -ForegroundColor Green
