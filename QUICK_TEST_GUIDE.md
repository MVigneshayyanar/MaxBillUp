# 🎯 QUICK TEST GUIDE - Customer Management Fix

## ✅ What Was Fixed

1. **Last Due Amount** - Now saves and reflects in ledger
2. **Payment History** - Loads instantly with proper error handling  
3. **Import Contacts** - Added button in nq.dart (via common_widgets)

---

## 📱 HOW TO TEST (3 Minutes)

### Test 1: Add Customer with Last Due (1 min)

**Steps:**
1. Open app → Go to Sales/Quotation
2. Click **Customer** button
3. Click **"➕" (Add Customer)** button
4. Fill form:
   - Name: `Test Customer`
   - Phone: `9999999999`
   - Last Due Amount: `5000`
5. Click **Add**

**✅ Expected Result:**
- Green success message: "Customer added successfully"
- Go to Menu → Customer Management
- Find "Test Customer"
- Balance shows: **Rs 5000.00**

---

### Test 2: Check Payment History (30 sec)

**Steps:**
1. Click on "Test Customer"
2. Click **"Payment History"**

**✅ Expected Result:**
- **Data loads instantly** (not infinite loading)
- Shows entry:
  - **"Sales Credit Added"**
  - Amount: Rs 5000
  - Date & Time shown
  - Note: "Opening Balance - Last Due Added"
  - Method: Manual
- If empty: Shows helpful message with icon

---

### Test 3: Check Ledger (30 sec)

**Steps:**
1. Back to Customer Details
2. Click **"Ledger Account"**

**✅ Expected Result:**
- Shows table with columns:
  - DATE | PARTICULARS | DEBIT | CREDIT | BALANCE
- First entry:
  - PARTICULARS: "Sales Credit Added (Manual)"
  - DEBIT: 5000
  - BALANCE: 5000 (in red)

---

### Test 4: Import Contact (1 min)

**Steps:**
1. Go to Sales/Quotation → Customer button
2. Look for **📞 icon** next to **➕ icon**
3. Click **📞 (Import from Contacts)**
4. Search and select a contact
5. Name & Phone are pre-filled
6. Add Last Due: `3000`
7. Click Add

**✅ Expected Result:**
- Customer created with balance 3000
- Payment History shows opening balance
- Ledger shows debit entry

---

## 🐛 TROUBLESHOOTING

### Issue: Payment History shows "Error loading data"
**Cause:** Composite index not created in Firestore
**Solution:** App automatically falls back to manual sorting - data still loads!

### Issue: No contact permission
**Cause:** Contacts permission not granted
**Solution:** App will prompt for permission

### Issue: Import button not visible
**Cause:** Make sure you did hot reload after updating files
**Solution:** Press `r` in terminal or restart app

---

## 🎉 SUCCESS INDICATORS

### ✅ Everything Working:
- Customer added → Success message shows
- Balance reflects immediately
- Payment History loads in < 1 second
- Ledger shows proper entries
- Import contacts button visible
- Notes display correctly

### ❌ Something Wrong:
- No success message after adding
- Payment History stuck on loading
- Ledger empty even with transactions
- Import button missing

**If issues persist:**
1. Press `R` (hot restart) in terminal
2. Or stop app and run: `flutter clean && flutter run`

---

## 📊 WHAT TO LOOK FOR

### Payment History Entry Format:
```
🔴 Sales Credit Added
31 Dec 2024 • 12:30 • Manual
Opening Balance - Last Due Added
Rs 5000
```

### Ledger Entry Format:
```
DATE       PARTICULARS                    DEBIT  CREDIT  BALANCE
31/12/24   Sales Credit Added (Manual)    5000   -       5000
```

---

## ⚡ QUICK COMMANDS

```bash
# Hot reload (fastest)
Press 'r' in terminal

# Hot restart (if reload doesn't work)
Press 'R' in terminal

# Full rebuild (if restart doesn't work)
flutter clean && flutter pub get && flutter run
```

---

**Time to Test:** ~3 minutes
**Expected Outcome:** All features working perfectly! ✅

