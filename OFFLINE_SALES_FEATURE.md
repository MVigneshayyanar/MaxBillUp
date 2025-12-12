# Offline Sales Syncing Feature

## Overview
This feature enables the MaxBillUp app to complete sales even when offline. Sales are automatically saved locally and synced to Firebase when the internet connection is restored.

## How It Works

### 1. Sale Completion Process
When a user completes a sale (via PaymentPage or SplitPaymentPage):
- The app checks internet connectivity
- **If Online**: Sale is saved directly to Firestore with all related updates (stock, customer credit, etc.)
- **If Offline or Error**: Sale is saved to local Hive database and queued for syncing

### 2. Automatic Syncing
- The `SaleSyncService` monitors connectivity changes
- When internet connection is restored, all pending sales are automatically synced
- Syncing includes:
  - Sale record creation in Firestore
  - Product stock updates
  - Customer credit updates (for credit sales)
  - Credit note status updates
  - Quotation status updates
  - Saved order deletion

### 3. User Notifications
Users are notified about the offline status:
- **Green notification**: Sale completed successfully online
- **Orange notification**: Sale saved offline, will sync when online

## Technical Components

### Files Modified
1. **lib/main.dart**
   - Initializes Hive database
   - Registers Sale adapter
   - Initializes SaleSyncService
   - Provides SaleSyncService via Provider

2. **lib/Sales/Bill.dart**
   - Updated `_completeSale()` in PaymentPage to check connectivity
   - Updated `_processSplitSale()` in SplitPaymentPage to check connectivity
   - Added `_saveOfflineSale()` helper method in both pages

3. **lib/services/sale_sync_service.dart**
   - Enhanced to handle complete backend sync
   - Includes stock updates, customer credit, credit notes, quotations
   - Monitors connectivity and auto-syncs when online
   - Provides methods to get unsynced sales count and list

### New Files
1. **lib/components/sync_status_indicator.dart**
   - Widget to display pending sync count
   - Dialog to show detailed sync status
   - Manual sync trigger option

### Existing Files (Already in place)
1. **lib/models/sale.dart** - Hive model for offline sales
2. **lib/models/sale.g.dart** - Generated Hive adapter

## Usage

### For Developers

#### Adding Sync Status Indicator to a Page
```dart
import 'package:maxbillup/components/sync_status_indicator.dart';

// In your build method:
Column(
  children: [
    SyncStatusIndicator(),
    // ... rest of your widgets
  ],
)
```

#### Showing Sync Status Dialog
```dart
import 'package:maxbillup/components/sync_status_indicator.dart';

// Show dialog:
SyncStatusDialog.show(context);
```

#### Manual Sync Trigger
```dart
final saleSyncService = Provider.of<SaleSyncService>(context, listen: false);
await saleSyncService.syncAll();
```

### For Users
1. **Normal Operation**:
   - Complete sales as usual
   - Sales are saved immediately to the server when online

2. **When Offline**:
   - Complete sales normally
   - You'll see an orange notification: "Offline mode: Sale saved locally"
   - The invoice is still generated and can be printed
   - Sales are queued for syncing

3. **When Back Online**:
   - Sales automatically sync in the background
   - No user action required
   - Check sync status by clicking "Sync Now" button (if added to UI)

## Data Flow

### Online Sale Flow
```
Complete Sale → Check Connectivity → Online
                ↓
                Save to Firestore
                ↓
                Update Stock
                ↓
                Update Customer Credit (if applicable)
                ↓
                Update Credit Notes
                ↓
                Update Quotations
                ↓
                Show Success Notification
                ↓
                Display Invoice
```

### Offline Sale Flow
```
Complete Sale → Check Connectivity → Offline
                ↓
                Save to Hive (Local DB)
                ↓
                Show Offline Notification
                ↓
                Display Invoice
                ↓
                [Wait for Connection]
                ↓
                Connection Restored → Auto Sync
                ↓
                Complete Backend Updates
```

## Error Handling

### Sync Errors
- If a sync fails, the error is stored in the Sale object
- The sale remains in the unsynced list
- Sync will be retried on next connectivity change
- Errors can be viewed in the Sync Status Dialog

### Conflict Resolution
- Sales are identified by unique invoice numbers
- Firestore `.set()` is used to prevent duplicates
- Last write wins for any conflicts

## Database Structure

### Hive Box
- **Box Name**: 'sales'
- **Type**: Sale objects
- **Location**: App documents directory

### Sale Model Fields
- `id`: Invoice number (unique identifier)
- `data`: Complete sale data (Map)
- `isSynced`: Boolean flag
- `syncError`: Error message (if any)
- `createdAt`: Timestamp

## Performance Considerations

1. **Batch Processing**: Small delay between syncs to avoid overwhelming Firestore
2. **Background Sync**: Happens automatically without blocking UI
3. **Efficient Storage**: Only unsynced sales are kept in local database
4. **Memory Management**: Hive box is properly opened/closed

## Testing

### Test Offline Mode
1. Turn off WiFi/Mobile Data
2. Complete a sale
3. Verify orange notification appears
4. Turn on connectivity
5. Verify sale syncs automatically

### Test Sync Status
1. Complete multiple sales offline
2. Open Sync Status Dialog
3. Verify pending sales are listed
4. Restore connectivity
5. Trigger manual sync
6. Verify sales are synced

## Future Enhancements

Potential improvements:
- Background sync worker for iOS/Android
- Sync progress indicator
- Retry policy with exponential backoff
- Conflict resolution UI
- Sync history log
- Offline data cleanup policy

## Dependencies

Required packages (already in pubspec.yaml):
- `hive: ^2.2.3`
- `hive_flutter: ^1.1.0`
- `connectivity_plus: ^7.0.0`
- `provider: ^6.0.0`
- `build_runner: ^2.5.4` (dev)
- `hive_generator: ^2.0.1` (dev)

## Troubleshooting

### Sales Not Syncing
1. Check internet connectivity
2. View Sync Status Dialog for error messages
3. Try manual sync
4. Check Firebase permissions

### Hive Errors
1. Ensure Hive is initialized in main.dart
2. Check if Sale adapter is registered
3. Verify Hive box is opened
4. Run build_runner to regenerate adapters

### Missing Sales
1. Check Sync Status Dialog for unsynced sales
2. Verify sale was saved (check invoice generation)
3. Check Firebase console for sale records
4. Review app logs for errors

## Support

For issues or questions:
1. Check this documentation
2. Review error messages in Sync Status Dialog
3. Check application logs
4. Contact development team

