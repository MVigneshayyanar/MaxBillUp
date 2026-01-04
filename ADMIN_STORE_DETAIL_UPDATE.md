# Admin Store Detail - Change Plan & Date Feature

## Summary
Added functionality to the Store Detail Page in the Admin panel to allow administrators to:
1. **Change subscription plan** for any store
2. **Modify subscription dates** (both start date and expiry date)

## Changes Made to `lib/Admin/Home.dart`

### 1. New "SUBSCRIPTION DETAILS" Section
Added a dedicated section to display current subscription information:
- **Subscription Start Date** - Shows when the subscription began
- **Subscription Expiry Date** - Shows when the subscription expires
- **Current Plan** - Displays the active plan (Free/Growth/Pro)

### 2. New "ADMIN ACTIONS" Section
Added action buttons with beautiful UI:
- **Change Plan** button (amber color with premium icon)
- **Modify Subscription Date** button (primary blue color with calendar icon)

### 3. Change Plan Functionality
**Dialog Features:**
- Radio button selection for plans: Free, Growth, Pro
- Shows current plan
- Updates Firestore with:
  - New plan name
  - Timestamp of when plan was updated (`planUpdatedAt`)
- Success/error notifications via SnackBar

**Usage:**
1. Admin clicks "Change Plan" button
2. Dialog appears with radio options
3. Admin selects new plan
4. Clicks "UPDATE PLAN"
5. Firestore is updated immediately
6. Success message displayed

### 4. Modify Subscription Date Functionality
**Two-Step Process:**

**Step 1 - Date Picker:**
- Material date picker opens
- Admin selects the desired date
- Date range: 2020 to 2030

**Step 2 - Date Type Selection:**
- Dialog shows selected date
- Admin chooses which date to update:
  - **START DATE** (orange button) - Updates subscription start date
  - **EXPIRY DATE** (blue button) - Updates subscription expiry date

**Updates Firestore with:**
- Selected date as Timestamp
- Timestamp of when date was modified (`dateUpdatedAt`)
- Success/error notifications

### 5. Helper Methods Added

**`_formatDate(dynamic dateValue)`**
- Handles both Timestamp and String date formats
- Returns formatted date string: "dd MMM yyyy" (e.g., "04 Jan 2026")
- Shows "Not Set" if date is null
- Shows "Invalid Date" if date cannot be parsed

**`_buildActionButton()`**
- Creates consistent action button UI
- Parameters: icon, label, color, onTap callback
- Features ripple effect on tap
- Colored background and border matching button color

**`_showChangePlanDialog()`**
- Shows plan selection dialog
- Radio buttons for plan options
- Updates Firestore on confirmation

**`_showChangeDateDialog()`**
- Shows date picker
- Passes selected date to date type dialog

**`_showDateTypeDialog()`**
- Shows dialog to select date type
- Displays selected date
- Two action buttons: START DATE and EXPIRY DATE

**`_updateSubscriptionDate()`**
- Updates Firestore with selected date
- Shows success/error feedback

## UI/UX Features

### Visual Design
- Clean card-based layout with rounded corners
- Color-coded sections for easy navigation
- Icon-based labeling for quick recognition
- Consistent spacing and padding

### User Feedback
- Success SnackBars (green) when updates succeed
- Error SnackBars (red) when updates fail
- Loading states handled implicitly by Firebase
- Dialog confirmations before updates

### Accessibility
- Clear labels in uppercase for sections
- Icon + text combinations for clarity
- Color-coded actions (amber for plan, blue for dates)
- Proper error handling with user-friendly messages

## Firestore Updates

### Plan Update
```dart
{
  'plan': selectedPlan,              // 'Free', 'Growth', or 'Pro'
  'planUpdatedAt': ServerTimestamp   // Auto timestamp
}
```

### Date Update
```dart
{
  'startDate': Timestamp,            // For start date updates
  // OR
  'expiryDate': Timestamp,           // For expiry date updates
  'dateUpdatedAt': ServerTimestamp   // Auto timestamp
}
```

## Usage Flow

### For Admins - Change Plan:
1. Open Store Detail Page
2. Scroll to "ADMIN ACTIONS" section
3. Click "Change Plan"
4. Select new plan (Free/Growth/Pro)
5. Click "UPDATE PLAN"
6. See success confirmation

### For Admins - Modify Date:
1. Open Store Detail Page
2. Scroll to "ADMIN ACTIONS" section
3. Click "Modify Subscription Date"
4. Select date from date picker
5. Choose date type (START DATE or EXPIRY DATE)
6. See success confirmation

## Benefits
- **Centralized Control**: Admins can manage subscriptions from one place
- **Quick Updates**: No need to access database directly
- **Audit Trail**: Timestamps track when changes were made
- **Error Prevention**: Dialogs require confirmation before updates
- **Real-time Updates**: UI refreshes automatically via StreamBuilder
- **Professional UI**: Consistent with app design language

## Testing Recommendations
1. Test plan changes for all three plans
2. Test date updates for both start and expiry dates
3. Verify Firestore updates are reflected in real-time
4. Test with stores that have null/missing dates
5. Verify error handling when network is offline
6. Check that success/error messages display correctly

## Future Enhancements (Optional)
- Add validation to prevent expiry date before start date
- Add ability to extend subscription by X days/months
- Show subscription history/audit log
- Add bulk update capabilities for multiple stores
- Email notification to store owner when plan/dates change
- Add notes/reason field for changes

