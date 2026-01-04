# Admin Store Detail - Inline Edit Subscription Details

## Summary of Changes

Updated the Store Detail Page to fetch subscription dates from the backend and allow inline editing directly within the Subscription Details card. Removed the separate Admin Actions card for a cleaner, more intuitive interface.

## Changes Made

### 1. **Updated Subscription Details Section**
Now displays data from the correct backend fields:
- **subscriptionStartDate** - Fetched from `storeData['subscriptionStartDate']`
- **subscriptionExpiryDate** - Fetched from `storeData['subscriptionExpiryDate']`
- **Current Plan** - Shows Free/Essential/Growth/Pro

### 2. **Added Inline Edit Functionality**
Each field now has an edit icon button that allows direct editing:
- Click edit icon next to **Subscription Start** → Opens date picker
- Click edit icon next to **Subscription Expiry** → Opens date picker
- Click edit icon next to **Current Plan** → Opens plan selection dialog

### 3. **Removed Admin Actions Card**
- Deleted the separate "ADMIN ACTIONS" section
- Edit functionality now integrated directly into the Subscription Details card
- Cleaner, more intuitive UI

### 4. **New Methods Added**

#### `_editableDetailRow()`
Creates a detail row with an edit icon button:
```dart
Widget _editableDetailRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  required String value,
  required VoidCallback onEdit,
  bool isLast = false
})
```
- Same styling as regular detail rows
- Adds trailing edit icon button
- Calls `onEdit` callback when clicked

#### `_editDate()`
Handles date editing for both start and expiry dates:
- Parses current date from backend (handles Timestamp or String)
- Shows material date picker with range 2020-2030
- Updates Firestore with new date in ISO8601 format
- Updates `dateUpdatedAt` timestamp for audit trail
- Shows success/error feedback via SnackBar

### 5. **Removed Methods**
- `_buildActionButton()` - No longer needed
- `_showChangeDateDialog()` - Replaced by `_editDate()`
- `_showDateTypeDialog()` - Not needed with inline editing
- `_updateSubscriptionDate()` - Functionality merged into `_editDate()`

## Backend Field Mapping

The component now correctly reads from these Firestore fields:
```dart
{
  'subscriptionStartDate': '2026-01-04T16:07:19.751075',  // ISO8601 String
  'subscriptionExpiryDate': '2026-01-06T00:00:00.000',    // ISO8601 String
  'plan': 'Growth',                                        // String
  'dateUpdatedAt': Timestamp                               // Auto-generated
}
```

## UI/UX Improvements

### Before:
- Subscription details in one card
- Separate Admin Actions card below
- Two clicks to edit (open card, then select action)

### After:
- Single Subscription Details card
- Edit icons directly on each row
- One click to edit any field
- Cleaner, more compact layout

### Visual Features:
- ✏️ Edit icon (blue) on each editable row
- Tooltip on hover: "Edit"
- Same consistent styling as other detail rows
- Material date picker with primary color theme
- Success/error SnackBars for feedback

## Usage Flow

### Edit Subscription Start Date:
1. Click edit icon next to "Subscription Start"
2. Select new date from date picker
3. Date saved automatically
4. Success notification shown

### Edit Subscription Expiry Date:
1. Click edit icon next to "Subscription Expiry"
2. Select new date from date picker
3. Date saved automatically
4. Success notification shown

### Change Plan:
1. Click edit icon next to "Current Plan"
2. Select plan from radio buttons (Free/Essential/Growth/Pro)
3. Click "UPDATE PLAN"
4. Plan updated and success notification shown

## Data Format

### Dates Stored:
- Format: ISO8601 String
- Example: `"2026-01-04T16:07:19.751075"`
- Displayed as: "04 Jan 2026"

### Date Display:
- Uses `_formatDate()` helper method
- Handles both Timestamp and String formats
- Shows "Not Set" if null
- Shows "Invalid Date" if parse fails

## Benefits

✅ **Cleaner UI** - One card instead of two
✅ **Faster Editing** - Direct access to edit functions
✅ **Better UX** - Clear visual feedback with edit icons
✅ **Consistent Design** - Matches existing detail row style
✅ **Correct Data Source** - Uses proper backend fields
✅ **Audit Trail** - Tracks when dates are modified
✅ **Error Handling** - Graceful error messages
✅ **Real-time Updates** - UI refreshes via StreamBuilder

## Testing Checklist

- [x] Dates load from `subscriptionStartDate` and `subscriptionExpiryDate`
- [x] Edit icons appear on all three rows
- [x] Date picker opens for start date edit
- [x] Date picker opens for expiry date edit
- [x] Plan dialog opens for plan edit
- [x] Dates update in Firestore correctly
- [x] Plan updates in Firestore correctly
- [x] Success messages display correctly
- [x] Error handling works when offline
- [x] UI refreshes after updates
- [x] No compilation errors

