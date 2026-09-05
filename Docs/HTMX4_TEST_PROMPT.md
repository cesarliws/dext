# پرامپت اجرای تست HTMX 4

این پرامپت را به یک عامل کدنویسی بده و از او بخواه فقط نتیجه‌های قابل‌اثبات را گزارش کند.

```text
در شاخهٔ codex/htmx4-native، پیاده‌سازی HTMX 4 در Dext را تست و اعتبارسنجی کن.

محدودهٔ بررسی
- واحد جدید Sources/Web/Dext.Web.Htmx4.pas و تست‌های Tests/Web/Dext.Web.Htmx.Tests.pas را بررسی کن.
- رفتار legacy در Dext.Web.Htmx را تغییر نده و بدون نیاز روشن، refactor انجام نده.
- پیش از هر ویرایش، git status --short را ببین و تغییرات موجود کاربر را حفظ کن.

تست‌های واحد موردنیاز
1. درخواست عادی (بدون HX-Request) باید IsHtmx=False و RequestType=hrtNone داشته باشد.
2. HX-Request: true همراه با HX-Request-Type: partial باید IsPartial=True و RequestType=hrtPartial بدهد؛ مقادیر header را با حروف بزرگ/کوچک متفاوت هم امتحان کن.
3. HX-Request: true همراه با HX-Request-Type: full باید IsFull=True و RequestType=hrtFull بدهد.
4. برای HX-Source، HX-Target، HX-Current-URL، HX-Boosted و HX-History-Restore-Request، مقدارهای THtmx4Request را بررسی کن.
5. Htmx4.Partials باید چند تگ <hx-partial> درست بسازد؛ هم Target و هم Id را با hx-swap اختیاری تست کن.
6. selector، id و swap باید در attribute HTML-escape شوند (حداقل &, ", < و >). HTML داخل partial عمداً raw باقی بماند.
7. AsResult باید نتیجهٔ HTML سازگار با Dext برگرداند. اگر mock فعلی امکان دیدن body یا content-type را نمی‌دهد، یک تست integration کوچک و محدود اضافه کن.

ساخت و اجرای تست
1. محیط Delphi 13 را فعال کن:
   call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"
2. پکیج وب را بساز:
   C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe Packages\d13\Dext.Web.Core.dproj /t:Build /p:Config=Release /p:Platform=Win32 /v:minimal
3. پروژهٔ تست را بساز و runner تولیدشده را اجرا کن:
   C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe Tests\Web\Dext.Web.UnitTests.dproj /t:Build /p:Config=Debug /p:Platform=Win32 /v:minimal
4. تست‌ها را هم در runner و هم، در صورت وجود fixture مناسب، در مرورگر واقعی smoke-test کن: یک پاسخ شامل دو hx-partial به دو selector متفاوت بده و تأیید کن هر دو target به‌روزرسانی می‌شوند. درخواست partial و full را جداگانه امتحان کن.

نکتهٔ محیط ساخت
- اگر خطای «Never-build package rtl must be recompiled» یا «Required package Dext.Net.Core not found» دیدی، آن را BLOCKED (وابستگی/خروجی package) ثبت کن؛ آن را به HTMX4 نسبت نده و با تغییر کد HTMX4 دور نزن. در همان Delphi 13، وابستگی‌های Dext.Core، Dext.EntityFramework و Dext.Net.Core را با runtime سازگار بازسازی کن و سپس دوباره تست کن.

فرمت گزارش نهایی
- برای هر مورد: PASS، FAIL یا BLOCKED، فرمان اجراشده، و خروجی/شاهد کوتاه را بنویس.
- فایل‌های تغییرکرده را فهرست کن و توضیح بده چرا هر تغییر برای تست لازم بوده است.
- در FAIL، کوچک‌ترین patch پیشنهادی را بده؛ مگر اینکه صریحاً درخواست شده باشد، آن را اعمال نکن.
- در پایان git diff --check و git status --short را گزارش کن.

منابع رفتاری
- https://four.htmx.org/docs/
- https://four.htmx.org/reference/headers/HX-Request-Type
```
