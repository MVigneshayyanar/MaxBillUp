# 🚀 AUTOMATED TRANSLATION UPDATE SCRIPT

## PowerShell Script to Update All Files

Save this as `update_all_translations.ps1` and run it:

```powershell
# Translation Update Script for MaxBillUp
# This script adds imports and provides a report of what needs manual updating

$projectRoot = "C:\MaxBillUp\lib"

# List of all files that need translation
$files = @(
    "Sales\Bill.dart",
    "Sales\Invoice.dart",
    "Sales\Saved.dart",
    "Sales\BarcodeScanner.dart",
    "Sales\Quotation.dart",
    "Sales\QuotationsList.dart",
    "Sales\QuotationDetail.dart",
    "Sales\QuotationPreview.dart",
    "Stocks\Category.dart",
    "Stocks\AddCategoryPopup.dart",
    "Stocks\Expenses.dart",
    "Stocks\OtherExpenses.dart",
    "Stocks\StockPurchase.dart",
    "Stocks\ExpenseCategories.dart",
    "Menu\CustomerManagement.dart",
    "Settings\TaxSettings.dart",
    "Settings\StaffManagement.dart",
    "Auth\LoginPage.dart",
    "Auth\SplashPage.dart",
    "Auth\BusinessDetailsPage.dart",
    "Auth\SubscriptionPlanPage.dart",
    "Sales\components\sale_app_bar.dart",
    "Stocks\Components\stock_app_bar.dart",
    "components\barcode_scanner.dart",
    "components\sync_status_indicator.dart"
)

$importStatement = "import 'package:maxbillup/utils/translation_helper.dart';"
$addedImports = 0
$alreadyHaveImport = 0
$errors = 0

Write-Host "`n🚀 Starting Translation Import Update...`n" -ForegroundColor Cyan

foreach ($file in $files) {
    $fullPath = Join-Path $projectRoot $file
    
    if (!(Test-Path $fullPath)) {
        Write-Host "❌ File not found: $file" -ForegroundColor Red
        $errors++
        continue
    }
    
    $content = Get-Content $fullPath -Raw
    
    # Check if import already exists
    if ($content -match "translation_helper") {
        Write-Host "⏭️  Already has import: $file" -ForegroundColor Yellow
        $alreadyHaveImport++
        continue
    }
    
    # Find the last import statement
    $lines = Get-Content $fullPath
    $lastImportIndex = -1
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^import ") {
            $lastImportIndex = $i
        }
    }
    
    if ($lastImportIndex -ge 0) {
        # Insert import after the last import
        $newLines = @()
        $newLines += $lines[0..$lastImportIndex]
        $newLines += $importStatement
        $newLines += $lines[($lastImportIndex + 1)..($lines.Count - 1)]
        
        Set-Content $fullPath -Value $newLines
        Write-Host "✅ Added import: $file" -ForegroundColor Green
        $addedImports++
    } else {
        Write-Host "⚠️  No import section found: $file" -ForegroundColor Yellow
        $errors++
    }
}

Write-Host "`n📊 Summary:" -ForegroundColor Cyan
Write-Host "✅ Imports Added: $addedImports" -ForegroundColor Green
Write-Host "⏭️  Already Had Import: $alreadyHaveImport" -ForegroundColor Yellow
Write-Host "❌ Errors: $errors" -ForegroundColor Red

Write-Host "`n✅ Phase 1 Complete: All imports added!`n" -ForegroundColor Green
Write-Host "📝 Next Step: Run the text replacement script (see below)`n" -ForegroundColor Cyan
```

## Phase 2: Text Replacement Guide

After running the import script, manually update text strings using IDE Find & Replace:

### Common Replacements:

```
Find: Text('Save')
Replace: Text(context.tr('save'))

Find: Text('Cancel')
Replace: Text(context.tr('cancel'))

Find: Text('Delete')
Replace: Text(context.tr('delete'))

Find: Text('Add')
Replace: Text(context.tr('add'))

Find: Text('Edit')
Replace: Text(context.tr('edit'))

Find: Text('Update')
Replace: Text(context.tr('update'))

Find: Text('Search')
Replace: Text(context.tr('search'))

Find: labelText: 'Product Name'
Replace: labelText: context.tr('product_name')

Find: labelText: 'Price'
Replace: labelText: context.tr('price')

Find: labelText: 'Quantity'
Replace: labelText: context.tr('quantity')

Find: hintText: 'Search'
Replace: hintText: context.tr('search')

Find: title: Text('Products')
Replace: title: Text(context.tr('products'))

Find: title: Text('Settings')
Replace: title: Text(context.tr('settings'))
```

### Special Cases to Handle Manually:

1. **Const Text widgets** - Remove `const` keyword:
```dart
// Before
const Text('Save')

// After  
Text(context.tr('save'))
```

2. **String concatenation**:
```dart
// Before
Text('Total: $amount')

// After
Text('${context.tr('total')}: $amount')
```

3. **Dialog titles**:
```dart
// Before
AlertDialog(title: const Text('Confirm Delete'))

// After
AlertDialog(title: Text(context.tr('confirm_delete')))
```

## Quick Regex Patterns for IDE

### Pattern 1: Simple Text widgets
```
Find (Regex): const Text\('([^']+)'\)
Replace: Text(context.tr('$1'))
```

### Pattern 2: Label text
```
Find (Regex): labelText: '([^']+)'
Replace: labelText: context.tr('$1')
```

### Pattern 3: Hint text
```
Find (Regex): hintText: '([^']+)'
Replace: hintText: context.tr('$1')
```

## Files that Need Manual Review

These files have complex text that needs careful review:

1. **Bill.dart** - Payment calculations, tax display
2. **Invoice.dart** - Receipt formatting
3. **Reports.dart** - Chart labels, date formatting
4. **TaxSettings.dart** - Tax type labels

## Testing Script

After updates, run this to test:

```powershell
# Test all updated files compile
cd C:\MaxBillUp
flutter analyze lib/

# Check for common mistakes
Get-ChildItem -Path lib -Filter *.dart -Recurse | Select-String -Pattern "context\.tr\(''\)" | Select-Object Path, LineNumber
```

This will find any empty translation keys like `context.tr('')`

---

**Save this script and run Phase 1 first, then Phase 2 manually with IDE Find & Replace.**

