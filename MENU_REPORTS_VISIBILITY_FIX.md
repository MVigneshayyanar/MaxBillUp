# Menu and Reports Cards Visibility Fix for Free/Starter Plan Owners

## Issue Description
In owner mode for free/starter plan users, the menu and report cards were completely hidden. According to requirements, these cards should be **visible** but clicking them should prompt users to upgrade their subscription.

## Root Cause
The visibility logic was checking if the user's plan had the required rank before showing the cards. For owners on free/starter plans (rank 0), cards requiring rank 1+ were being hidden completely with `if (isFeatureAvailable())` conditional rendering.

### Previous Behavior:
- **Menu.dart**: `isFeatureAvailable()` returned `false` for admins on free/starter plans, causing cards to not render
- **Reports.dart**: Same issue - `isPaidPlan` check prevented card rendering for free plan users

## Solution Implemented

### 1. Reports.dart Changes

#### Updated `isFeatureAvailable()` function (Line ~188):
```dart
// OLD - hid cards for admins without paid plan
if (isAdmin) return isPaidPlan;

// NEW - show all cards for admins
if (isAdmin) return true;
```

#### Updated `_buildReportTile()` function (Lines ~282-370):
- Added plan checking logic in the `onTap` handler
- DayBook remains free for all users
- For admins on free/starter plan: shows upgrade dialog when clicked
- For staff: checks both user permission AND paid plan requirement
- Added `_getPermissionKey()` helper method to map view names to permission keys

**Key Logic:**
```dart
onTap: () {
  // DayBook is always free
  if (viewName == 'DayBook') {
    setState(() => _currentView = viewName);
    return;
  }
  
  // For admins on free/starter plan, show upgrade dialog
  if (isAdmin && !isPaidPlan) {
    PlanPermissionHelper.showUpgradeDialog(context, title, ...);
    return;
  }
  
  // For staff, check permissions
  if (!isAdmin) {
    final hasPermission = _permissions[...] == true;
    if (!hasPermission || !isPaidPlan) {
      PlanPermissionHelper.showUpgradeDialog(context, title, ...);
      return;
    }
  }
  
  // All checks passed - open the report
  setState(() => _currentView = viewName);
}
```

### 2. Menu.dart Changes

#### Updated `isFeatureAvailable()` function (Lines ~193-201):
```dart
// OLD - hid cards for admins without required plan rank
if (planRank < requiredRank) return false;
if (isAdmin) return true;

// NEW - show all cards for admins first
if (isAdmin) return true;
// Then check plan rank for staff
if (planRank < requiredRank) return false;
```

#### Updated `_buildMenuTile()` function (Lines ~372-478):
- Wrapped in `Consumer<PlanProvider>` to access plan data
- Added `requiredRank` parameter (default = 0 for free features)
- Calculates current `planRank` from plan name
- Added plan checking logic in `onTap` handler similar to Reports
- Added `_getPermissionKeyFromView()` helper method

**Key Logic:**
```dart
onTap: () {
  // Check if feature requires a higher plan
  if (requiredRank > 0 && planRank < requiredRank) {
    // Show upgrade dialog for admins
    if (isAdmin) {
      PlanPermissionHelper.showUpgradeDialog(context, title, ...);
      return;
    }
    
    // For staff, also check permission
    if (!_hasPermission(...)) {
      PlanPermissionHelper.showUpgradeDialog(context, title, ...);
      return;
    }
  }
  
  // Navigate to the view
  setState(() => _currentView = viewKey);
}
```

#### Updated menu tile calls (Lines ~234-258):
Added `requiredRank` parameter to premium features:
- Customers: `requiredRank: 1`
- Credit Notes: `requiredRank: 1`
- Credit Details: `requiredRank: 2`
- Quotation: `requiredRank: 1`
- Staff Management: `requiredRank: 2`

## Plan Rank System
- **Free/Starter**: Rank 0
- **Essential**: Rank 1
- **Growth**: Rank 2
- **Pro/Premium**: Rank 3

## Features Affected

### Reports Page (All require paid plan except DayBook):
- ✅ **DayBook** - Always free for everyone
- 🔒 **Analytics** - Requires paid plan
- 🔒 **Sales Summary** - Requires paid plan
- 🔒 **Sales Report** - Requires paid plan
- 🔒 **Item Sales** - Requires paid plan
- 🔒 **Top Customers** - Requires paid plan
- 🔒 **Staff Report** - Requires paid plan
- 🔒 **Stock Report** - Requires paid plan
- 🔒 **Low Stock** - Requires paid plan
- 🔒 **Top Products** - Requires paid plan
- 🔒 **Top Categories** - Requires paid plan
- 🔒 **Expense Report** - Requires paid plan
- 🔒 **Tax Report** - Requires paid plan
- 🔒 **GST Report** - Requires paid plan

### Menu Page:
- ✅ **Bill History** - Free (limited to 7 days for starter plan)
- 🔒 **Customers** - Rank 1 (Essential+)
- 🔒 **Credit Notes** - Rank 1 (Essential+)
- 🔒 **Expenses** - Rank 1 (Essential+)
- 🔒 **Credit Details** - Rank 2 (Growth+)
- 🔒 **Quotation** - Rank 1 (Essential+)
- 🔒 **Staff Management** - Rank 2 (Growth+)
- ✅ **Video Tutorials** - Always free
- ✅ **Knowledge Base** - Always free

## User Experience

### Before Fix:
- Owner on Free plan opens Reports → sees only DayBook card
- Owner on Free plan opens Menu → sees very limited cards
- No way to discover premium features

### After Fix:
- Owner on Free plan opens Reports → **sees all report cards**
- Owner clicks on "Analytics" → **upgrade dialog appears**
- Clear call-to-action to upgrade subscription
- Better feature discovery and conversion funnel

## Testing Steps

1. **Test as Owner on Free/Starter Plan:**
   - Open Reports page → Verify all cards are visible
   - Click on any report (except DayBook) → Verify upgrade dialog appears
   - Click on DayBook → Verify it opens without prompt
   - Open Menu page → Verify all cards are visible
   - Click on premium features → Verify upgrade dialog appears

2. **Test as Owner on Paid Plan:**
   - Open Reports page → Verify all cards are visible
   - Click on any report → Verify it opens directly
   - Open Menu page → Verify all cards are visible
   - Click on features → Verify they open directly

3. **Test as Staff on Free Plan:**
   - Cards visibility depends on granted permissions
   - Clicking locked features shows upgrade dialog

## Files Modified
1. `lib/Reports/Reports.dart` - Updated visibility and click logic
2. `lib/Menu/Menu.dart` - Updated visibility and click logic

## Related Files
- `lib/utils/plan_permission_helper.dart` - Contains upgrade dialog
- `lib/utils/plan_provider.dart` - Provides plan data to widgets

## Benefits
- ✅ Better user experience - users can see what they're missing
- ✅ Improved feature discovery
- ✅ Clear upgrade path with contextual prompts
- ✅ Consistent behavior across menu and reports
- ✅ No breaking changes to existing functionality

