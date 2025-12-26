import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/utils/firestore_service.dart';

/// Global Plan Provider - ALWAYS fetches fresh data from Firestore
/// NO CACHING - Every access fetches from backend
class PlanProvider extends ChangeNotifier {
  static const String PLAN_FREE = 'Free';
  static const String PLAN_Essential = 'Essential';
  static const String PLAN_Growth = 'Growth';
  static const String PLAN_MAX = 'Pro';

  StreamSubscription<DocumentSnapshot>? _planSubscription;
  String? _storeId;

  /// Initialize the plan listener - call this once at app startup
  Future<void> initialize() async {
    await _startPlanListener();
  }

  /// Start listening to plan changes in real-time (no caching, direct Firestore stream)
  Future<void> _startPlanListener() async {
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc == null) {
        notifyListeners();
        return;
      }

      _storeId = storeDoc.id;

      // Cancel existing subscription if any
      await _planSubscription?.cancel();

      // Listen to store document changes in real-time
      // This triggers notifyListeners() on every Firestore change
      _planSubscription = FirebaseFirestore.instance
          .collection('store')
          .doc(storeDoc.id)
          .snapshots()
          .listen((snapshot) {
        // Just notify - widgets will fetch fresh data
        notifyListeners();
      }, onError: (e) {
        debugPrint('Plan listener error: $e');
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error starting plan listener: $e');
      notifyListeners();
    }
  }

  /// ALWAYS fetch current plan from Firestore - NO CACHE
  Future<String> getCurrentPlan() async {
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc == null || !storeDoc.exists) {
        return PLAN_FREE;
      }

      final data = storeDoc.data() as Map<String, dynamic>?;
      if (data == null) return PLAN_FREE;

      String? planValue = data['plan']?.toString();
      if (planValue == null || planValue.trim().isEmpty) {
        return PLAN_FREE;
      }

      final plan = planValue.trim();

      // Check expiry for paid plans
      if (plan != PLAN_FREE) {
        final expiryDateStr = data['subscriptionExpiryDate']?.toString();
        if (expiryDateStr != null) {
          try {
            final expiryDate = DateTime.parse(expiryDateStr);
            if (DateTime.now().isAfter(expiryDate)) {
              return PLAN_FREE; // Expired
            }
          } catch (e) {
            return PLAN_FREE;
          }
        }
      }

      return plan;
    } catch (e) {
      debugPrint('Error fetching plan: $e');
      return PLAN_FREE;
    }
  }

  /// Get current plan synchronously for UI (fetches fresh in background)
  /// Returns 'Free' as default, then triggers rebuild with fresh data
  String get currentPlan {
    // Trigger async fetch and notify
    _fetchAndNotify();
    return PLAN_FREE; // Default return while fetching
  }

  void _fetchAndNotify() async {
    // This triggers widgets to rebuild with fresh data
    notifyListeners();
  }

  // ==========================================
  // ASYNC PERMISSION CHECKS - Always fetch fresh
  // ==========================================

  Future<bool> canAccessReportsAsync() async {
    final plan = await getCurrentPlan();
    return plan != PLAN_FREE;
  }

  Future<bool> canAccessDaybookAsync() async {
    final plan = await getCurrentPlan();
    return plan != PLAN_FREE;
  }

  Future<bool> canAccessQuotationAsync() async {
    final plan = await getCurrentPlan();
    return plan != PLAN_FREE;
  }

  Future<bool> canAccessFullBillHistoryAsync() async {
    final plan = await getCurrentPlan();
    return plan != PLAN_FREE;
  }

  Future<bool> canEditBillAsync() async {
    final plan = await getCurrentPlan();
    return plan != PLAN_FREE;
  }

  Future<bool> canAccessCustomerCreditAsync() async {
    final plan = await getCurrentPlan();
    return plan != PLAN_FREE;
  }

  Future<bool> canUseLogoOnBillAsync() async {
    final plan = await getCurrentPlan();
    return plan != PLAN_FREE;
  }

  Future<bool> canImportContactsAsync() async {
    final plan = await getCurrentPlan();
    return plan != PLAN_FREE;
  }

  Future<bool> canUseBulkInventoryAsync() async {
    final plan = await getCurrentPlan();
    return plan != PLAN_FREE;
  }

  Future<bool> canAccessStaffManagementAsync() async {
    final plan = await getCurrentPlan();
    return plan == PLAN_Growth || plan == PLAN_MAX;
  }

  Future<int> getMaxStaffCountAsync() async {
    final plan = await getCurrentPlan();
    switch (plan) {
      case PLAN_FREE:
      case PLAN_Essential:
        return 0;
      case PLAN_Growth:
        return 3;
      case PLAN_MAX:
        return 10;
      default:
        return 0;
    }
  }

  Future<int> getBillHistoryDaysLimitAsync() async {
    final plan = await getCurrentPlan();
    return plan == PLAN_FREE ? 7 : 36500;
  }

  Future<bool> canAddMoreStaffAsync(int currentStaffCount) async {
    final maxStaff = await getMaxStaffCountAsync();
    if (maxStaff == 0) return false;
    return currentStaffCount < maxStaff;
  }

  // ==========================================
  // SYNC METHODS - Use FutureBuilder in widgets
  // These just return defaults, use async versions
  // ==========================================

  bool canAccessReports() => false; // Use canAccessReportsAsync()
  bool canAccessDaybook() => true; // Daybook is FREE
  bool canAccessQuotation() => false; // Use canAccessQuotationAsync()
  bool canAccessFullBillHistory() => false;
  bool canEditBill() => false;
  bool canAccessCustomerCredit() => false;
  bool canUseLogoOnBill() => false;
  bool canImportContacts() => false;
  bool canUseBulkInventory() => false;
  bool canAccessStaffManagement() => false;

  @override
  void dispose() {
    _planSubscription?.cancel();
    super.dispose();
  }
}

