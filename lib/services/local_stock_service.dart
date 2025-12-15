import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service to manage product stock locally when offline
class LocalStockService {
  static const String _stockPrefix = 'local_stock_';
  static const String _pendingUpdatesKey = 'pending_stock_updates';

  /// Update stock locally for a product
  static Future<void> updateLocalStock(String productId, int quantityChange) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_stockPrefix$productId';

      // Get current local stock value (or null if not cached)
      final currentStock = prefs.getInt(key);

      if (currentStock != null) {
        // Update local stock
        final newStock = (currentStock + quantityChange).clamp(0, double.infinity).toInt();
        await prefs.setInt(key, newStock);
        print('📦 Local stock updated for $productId: $currentStock -> $newStock (change: $quantityChange)');
      } else {
        print('⚠️ No local stock cached for $productId, will update on next fetch');
      }

      // Track pending update for sync
      await _addPendingUpdate(productId, quantityChange);
    } catch (e) {
      print('❌ Error updating local stock: $e');
    }
  }

  /// Get local stock for a product (returns null if not cached)
  static Future<int?> getLocalStock(String productId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('$_stockPrefix$productId');
    } catch (e) {
      print('❌ Error getting local stock: $e');
      return null;
    }
  }

  /// Cache stock value from Firestore
  static Future<void> cacheStock(String productId, int stock) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_stockPrefix$productId', stock);
    } catch (e) {
      print('❌ Error caching stock: $e');
    }
  }

  /// Add pending stock update for later sync
  static Future<void> _addPendingUpdate(String productId, int quantityChange) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updatesJson = prefs.getString(_pendingUpdatesKey) ?? '[]';
      final updates = List<Map<String, dynamic>>.from(json.decode(updatesJson));

      // Check if update for this product already exists
      final existingIndex = updates.indexWhere((u) => u['productId'] == productId);
      if (existingIndex != -1) {
        // Accumulate the change
        updates[existingIndex]['quantityChange'] =
            (updates[existingIndex]['quantityChange'] as int) + quantityChange;
      } else {
        // Add new pending update
        updates.add({
          'productId': productId,
          'quantityChange': quantityChange,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      await prefs.setString(_pendingUpdatesKey, json.encode(updates));
    } catch (e) {
      print('❌ Error adding pending update: $e');
    }
  }

  /// Get all pending stock updates
  static Future<List<Map<String, dynamic>>> getPendingUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updatesJson = prefs.getString(_pendingUpdatesKey) ?? '[]';
      return List<Map<String, dynamic>>.from(json.decode(updatesJson));
    } catch (e) {
      print('❌ Error getting pending updates: $e');
      return [];
    }
  }

  /// Clear pending updates after successful sync
  static Future<void> clearPendingUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingUpdatesKey);
      print('✅ Pending stock updates cleared');
    } catch (e) {
      print('❌ Error clearing pending updates: $e');
    }
  }

  /// Clear all local stock cache
  static Future<void> clearAllLocalStock() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_stockPrefix)) {
          await prefs.remove(key);
        }
      }
      print('✅ All local stock cache cleared');
    } catch (e) {
      print('❌ Error clearing local stock: $e');
    }
  }
}

