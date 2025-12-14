# 🌍 Language System - Quick Reference Card

## 🎯 **KEY FACT: AUTO-UPDATE WORKS EVERYWHERE!**

When user changes language in Settings:
- ✅ **ALL pages update instantly**
- ✅ **No app restart needed**
- ✅ **No manual refresh needed**
- ✅ **Works automatically via Provider**

---

## ⚡ Quick Usage

### Import Once:
```dart
import 'package:maxbillup/utils/translation_helper.dart';
```

### Use Anywhere:
```dart
// In Text widgets
Text(context.tr('sales'))

// In Buttons
ElevatedButton(
  child: Text(context.tr('save')),
  onPressed: () {},
)

// In AppBar
AppBar(title: Text(context.tr('settings')))

// As Widget
TranslatedText('welcome')
```

### Result:
**Changes instantly when language changes!** ✨

---

## 🎯 Common Translation Keys (150+)

### Most Used:
| Key | English | Hindi | Tamil |
|-----|---------|-------|-------|
| `sales` | Sales | बिक्री | விற்பனை |
| `products` | Products | उत्पाद | பொருட்கள் |
| `save` | Save | सेव करें | சேமி |
| `cancel` | Cancel | रद्द करें | ரத்து |
| `add` | Add | जोड़ें | சேர் |
| `delete` | Delete | हटाएं | நீக்கு |
| `search` | Search | खोजें | தேடு |
| `settings` | Settings | सेटिंग்स | அமைப்புகள் |

### All Categories:
- **Actions:** save, cancel, delete, edit, add, update, search, back, next, close, open, refresh, sync
- **Sales:** new_sale, quick_sale, complete_payment, checkout, cash, online, credit
- **Products:** add_product, product_name, price, quantity, stock, barcode, category
- **Billing:** subtotal, discount, tax, total, amount_received, invoice, receipt
- **Reports:** daily_report, monthly_report, sales_report, profit_loss
- **Settings:** business_details, tax_settings, choose_language, theme
- **Status:** active, inactive, paid, unpaid, pending, completed, available
- **Misc:** quotations, expenses, customers, staff_management, categories

**Total: 150+ keys in 9 languages!**

---

## 🔧 Change Language

### User Action:
```
Settings → Choose Language → Select Language
```

### Programmatically:
```dart
final lang = context.lang;
await lang.changeLanguage('hi');  // Switch to Hindi
await lang.changeLanguage('ta');  // Switch to Tamil
await lang.changeLanguage('en');  // Switch to English
```

---

## 📝 Add New Translation Key

### Step 1: Open
```
lib/utils/language_provider.dart
```

### Step 2: Add to Translations
```dart
'en': {
  // existing...
  'my_new_key': 'My Text',
},
'hi': {
  // existing...
  'my_new_key': 'मेरा पाठ',
},
'ta': {
  // existing...
  'my_new_key': 'எனது உரை',
},
```

### Step 3: Use in Code
```dart
Text(context.tr('my_new_key'))
```

---

## 🌐 Supported Languages

| Code | Language |
|------|----------|
| `en` | English |
| `hi` | Hindi |
| `ta` | Tamil |
| `fr` | French |
| `es` | Spanish |
| `ms` | Malay |
| `bn` | Bangla |
| `uz` | Uzbek |
| `ru` | Russian |

---

## 🎨 Get Current Language

```dart
final lang = context.lang;

String code = lang.currentLanguageCode;  // 'en'
String name = lang.currentLanguageName;  // 'English'
```

---

## ✅ Features

- ✅ 9 Languages
- ✅ 50+ Translation Keys
- ✅ Real-time Updates
- ✅ Persistent Storage
- ✅ Works Everywhere
- ✅ Easy to Extend

---

## 📚 Documentation

- **LANGUAGE_SYSTEM_GUIDE.md** - Full guide
- **LANGUAGE_IMPLEMENTATION_SUMMARY.md** - Summary
- **lib/examples/translation_example.dart** - Examples

---

**That's it!** Use `context.tr('key')` anywhere in your app! 🚀

