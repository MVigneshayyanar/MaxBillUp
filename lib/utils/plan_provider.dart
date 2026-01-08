import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/utils/firestore_service.dart';

/// Global Plan Provider - ALWAYS fetches fresh data from Firestore
/// NO CACHING - Every access fetches from backend
class PlanProvider extends ChangeNotifier {
  static const String PLAN_FREE = 'Free';
  static const String PLAN_STARTER = 'Starter';
  static const String PLAN_Essential = 'Essential';
  static const String PLAN_Growth = 'Growth';
  static const String PLAN_MAX = 'Pro';

  StreamSubscription<DocumentSnapshot>? _planSubscription;
  String? _storeId;

  // Cache the current plan for instant access
  String _cachedPlan = PLAN_FREE;
  DateTime? _cachedExpiryDate;
  bool _isInitialized = false;

  /// Get cached plan instantly (no async wait)
  String get cachedPlan => _cachedPlan;

  /// Get cached expiry date instantly (no async wait)
  DateTime? get cachedExpiryDate => _cachedExpiryDate;

  /// Check if plan is expiring soon (within 3 days)
  bool get isExpiringSoon {
    if (_cachedExpiryDate == null) return false;
    final daysUntilExpiry = _cachedExpiryDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry >= 0 && daysUntilExpiry <= 3;
  }

  /// Get days until expiry (negative if expired)
  int get daysUntilExpiry {
    if (_cachedExpiryDate == null) return -1;
    return _cachedExpiryDate!.difference(DateTime.now()).inDays;
  }

  /// Check if provider is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the plan listener - call this once at app startup
  Future<void> initialize() async {
    await _startPlanListener();
    // Fetch and cache the current plan and expiry date
    await _fetchPlanAndExpiry();
    _isInitialized = true;
    notifyListeners();
  }

  /// Force refresh the plan from Firestore and notify all listeners
  /// Call this after subscription purchase to instantly update the app
  Future<void> forceRefresh() async {
    debugPrint('🔄 PlanProvider: Force refreshing subscription status...');
    await _fetchPlanAndExpiry();
    debugPrint('✅ PlanProvider: New plan = $_cachedPlan, Expiry = $_cachedExpiryDate');
    notifyListeners();
  }

  /// Fetch both plan and expiry date from Firestore
  Future<void> _fetchPlanAndExpiry() async {
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc == null || !storeDoc.exists) {
        _cachedPlan = PLAN_FREE;
        _cachedExpiryDate = null;
        return;
      }

      final data = storeDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        _cachedPlan = PLAN_FREE;
        _cachedExpiryDate = null;
        return;
      }

      // Get expiry date
      final expiryDateStr = data['subscriptionExpiryDate']?.toString();
      if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
        try {
          _cachedExpiryDate = DateTime.parse(expiryDateStr);
        } catch (e) {
          _cachedExpiryDate = null;
        }
      } else {
        _cachedExpiryDate = null;
      }

      // Get plan
      _cachedPlan = await getCurrentPlan();
    } catch (e) {
      debugPrint('Error fetching plan and expiry: $e');
      _cachedPlan = PLAN_FREE;
      _cachedExpiryDate = null;
    }
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
          .listen((snapshot) async {
        // Update cached plan and expiry date when Firestore changes
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          if (data != null) {
            // Update plan
            final newPlan = data['plan']?.toString() ?? PLAN_FREE;
            if (newPlan != _cachedPlan) {
              debugPrint('📱 PlanProvider: Real-time update - Plan changed to $newPlan');
              _cachedPlan = newPlan.isEmpty ? PLAN_FREE : newPlan;
            }

            // Update expiry date
            final expiryDateStr = data['subscriptionExpiryDate']?.toString();
            if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
              try {
                _cachedExpiryDate = DateTime.parse(expiryDateStr);
              } catch (e) {
                _cachedExpiryDate = null;
              }
            } else {
              _cachedExpiryDate = null;
            }
          }
        }
        // Notify all widgets to rebuild
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

  /// Get current plan synchronously for UI (returns cached value)
  /// Returns cached plan instantly, auto-updated by Firestore listener
  String get currentPlan {
    return _cachedPlan;
  }

  void _fetchAndNotify() async {
    // Fetch fresh data and update cache
    _cachedPlan = await getCurrentPlan();
    notifyListeners();
  }

  // ==========================================
  // ASYNC PERMISSION CHECKS - Always fetch fresh
  // ==========================================

  bool _isPlanFree(String plan) => plan == PLAN_FREE || plan == PLAN_STARTER;

  Future<bool> canAccessReportsAsync() async {
    final plan = await getCurrentPlan();
    return !_isPlanFree(plan);
  }

  Future<bool> canAccessDaybookAsync() async {
    return true; // Daybook is FREE for everyone
  }

  Future<bool> canAccessQuotationAsync() async {
    final plan = await getCurrentPlan();
    return !_isPlanFree(plan);
  }

  Future<bool> canAccessFullBillHistoryAsync() async {
    final plan = await getCurrentPlan();
    return !_isPlanFree(plan);
  }

  Future<bool> canEditBillAsync() async {
    final plan = await getCurrentPlan();
    return !_isPlanFree(plan);
  }

  Future<bool> canAccessCustomerCreditAsync() async {
    final plan = await getCurrentPlan();
    return !_isPlanFree(plan);
  }

  Future<bool> canUseLogoOnBillAsync() async {
    final plan = await getCurrentPlan();
    return !_isPlanFree(plan);
  }

  Future<bool> canImportContactsAsync() async {
    final plan = await getCurrentPlan();
    return !_isPlanFree(plan);
  }

  Future<bool> canUseBulkInventoryAsync() async {
    final plan = await getCurrentPlan();
    return !_isPlanFree(plan);
  }

  Future<bool> canAccessStaffManagementAsync() async {
    final plan = await getCurrentPlan();
    // Starter is the free plan - no staff management
    if (plan == PLAN_FREE || plan == PLAN_STARTER) return false;
    return plan == PLAN_Essential || plan == PLAN_Growth || plan == PLAN_MAX;
  }

  Future<int> getMaxStaffCountAsync() async {
    final plan = await getCurrentPlan();
    switch (plan) {
      case PLAN_FREE:
      case PLAN_STARTER:
        return 0;
      case PLAN_Essential:
        return 1; // Admin + 1 Manager
      case PLAN_Growth:
        return 3; // Admin + 3 Staff
      case PLAN_MAX:
        return 15; // Admin + 15 Staff
      default:
        return 0;
    }
  }

  Future<int> getBillHistoryDaysLimitAsync() async {
    final plan = await getCurrentPlan();
    return _isPlanFree(plan) ? 7 : 36500;
  }

  Future<bool> canAddMoreStaffAsync(int currentStaffCount) async {
    final maxStaff = await getMaxStaffCountAsync();
    if (maxStaff == 0) return false;
    return currentStaffCount < maxStaff;
  }

  // ==========================================
  // SYNC METHODS - Use cached plan for instant updates
  // These return results based on cached plan value
  // ==========================================

  bool _isFreePlan() => _cachedPlan == PLAN_FREE || _cachedPlan == PLAN_STARTER;

  bool canAccessReports() => !_isFreePlan();
  bool canAccessDaybook() => true; // Daybook is FREE
  bool canAccessQuotation() => !_isFreePlan();
  bool canAccessFullBillHistory() => !_isFreePlan();
  bool canEditBill() => !_isFreePlan();
  bool canAccessCustomerCredit() => !_isFreePlan();
  bool canUseLogoOnBill() => !_isFreePlan();
  bool canImportContacts() => !_isFreePlan();
  bool canUseBulkInventory() => !_isFreePlan();
  bool canAccessStaffManagement() => _cachedPlan == PLAN_Essential || _cachedPlan == PLAN_Growth || _cachedPlan == PLAN_MAX;

  int getMaxStaffCount() {
    switch (_cachedPlan) {
      case PLAN_FREE:
      case PLAN_STARTER:
        return 0;
      case PLAN_Essential:
        return 1; // Admin + 1 Manager
      case PLAN_Growth:
        return 3; // Admin + 3 Staff
      case PLAN_MAX:
        return 15; // Admin + 15 Staff
      default:
        return 0;
    }
  }

  int getBillHistoryDaysLimit() {
    return _cachedPlan == PLAN_FREE ? 7 : 36500;
  }

  @override
  void dispose() {
    _planSubscription?.cancel();
    super.dispose();
  }
}

