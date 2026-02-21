// lib/features/settings/services/auto_sync_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AutoSyncService {
  static final AutoSyncService _instance = AutoSyncService._internal();
  factory AutoSyncService() => _instance;
  AutoSyncService._internal();

  Timer? _syncTimer;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  bool _isDisposed = false;
  
  // Stream for sync status
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  // Start auto sync
  void startAutoSync(String userMobile, {Duration interval = const Duration(minutes: 15)}) {
    if (_isDisposed) return;
    
    stopAutoSync(); // Stop any existing timer
    
    print('🔄 Auto-sync started with interval: ${interval.inMinutes} minutes');
    
    _syncTimer = Timer.periodic(interval, (timer) async {
      if (!_isDisposed) {
        await _performSync(userMobile);
      }
    });
    
    // Perform initial sync
    _performSync(userMobile);
  }

  // Stop auto sync
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    print('🔄 Auto-sync stopped');
  }

  // Helper method to convert any Timestamp to String
  dynamic _convertValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else if (value is Map) {
      // Handle nested maps
      final Map<String, dynamic> result = {};
      value.forEach((key, val) {
        result[key.toString()] = _convertValue(val);
      });
      return result;
    } else if (value is List) {
      // Handle lists
      return value.map((item) => _convertValue(item)).toList();
    }
    return value;
  }

  // Perform sync
  Future<void> _performSync(String userMobile) async {
    if (_isSyncing || _isDisposed) {
      print('⚠️ Sync already in progress or disposed, skipping...');
      return;
    }

    _isSyncing = true;
    
    if (!_isDisposed && !_syncStatusController.isClosed) {
      _syncStatusController.add(SyncStatus.started());
    }

    try {
      print('🔄 Starting sync for user: $userMobile');
      
      // Sync inventory data
      await _syncInventory(userMobile);
      
      // Sync transactions
      await _syncTransactions(userMobile);
      
      // Sync settings
      await _syncSettings(userMobile);
      
      _lastSyncTime = DateTime.now();
      await _saveLastSyncTime();
      
      if (!_isDisposed && !_syncStatusController.isClosed) {
        _syncStatusController.add(SyncStatus.completed(
          message: 'Synced successfully at ${_formatTime(_lastSyncTime!)}',
        ));
      }
      
      print('✅ Sync completed at ${_lastSyncTime}');
      
    } catch (e) {
      print('❌ Sync failed: $e');
      if (!_isDisposed && !_syncStatusController.isClosed) {
        _syncStatusController.add(SyncStatus.failed(
          message: 'Sync failed: ${e.toString()}',
        ));
      }
    } finally {
      _isSyncing = false;
    }
  }

  // Sync inventory data
  Future<void> _syncInventory(String userMobile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userMobile)
          .collection('inventory')
          .get();
      
      final inventoryData = snapshot.docs.map((doc) {
        final data = doc.data();
        // Convert all Timestamp values to strings
        final convertedData = <String, dynamic>{};
        data.forEach((key, value) {
          convertedData[key] = _convertValue(value);
        });
        return convertedData;
      }).toList();
      
      await prefs.setString('cached_inventory', jsonEncode(inventoryData));
      print('✅ Inventory sync completed: ${inventoryData.length} items');
      
    } catch (e) {
      print('❌ Inventory sync failed: $e');
      rethrow;
    }
  }

  // Sync transactions
  Future<void> _syncTransactions(String userMobile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userMobile)
          .collection('transactions')
          .get();
      
      final transactionsData = snapshot.docs.map((doc) {
        final data = doc.data();
        // Convert all Timestamp values to strings
        final convertedData = <String, dynamic>{};
        data.forEach((key, value) {
          convertedData[key] = _convertValue(value);
        });
        return convertedData;
      }).toList();
      
      await prefs.setString('cached_transactions', jsonEncode(transactionsData));
      print('✅ Transactions sync completed: ${transactionsData.length} items');
      
    } catch (e) {
      print('❌ Transactions sync failed: $e');
      rethrow;
    }
  }

  // Sync settings
  Future<void> _syncSettings(String userMobile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userMobile)
          .collection('settings')
          .doc('preferences')
          .get();
      
      if (doc.exists) {
        final settingsData = doc.data() as Map<String, dynamic>;
        // Convert all Timestamp values to strings
        final convertedData = <String, dynamic>{};
        settingsData.forEach((key, value) {
          convertedData[key] = _convertValue(value);
        });
        await prefs.setString('user_settings', jsonEncode(convertedData));
        print('✅ Settings sync completed');
      }
      
    } catch (e) {
      print('❌ Settings sync failed: $e');
      rethrow;
    }
  }

  // Save last sync time
  Future<void> _saveLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_time', _lastSyncTime!.toIso8601String());
  }

  // Load last sync time
  Future<DateTime?> loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString('last_sync_time');
    if (timeString != null) {
      return DateTime.parse(timeString);
    }
    return null;
  }

  // Get sync status
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  // Format time
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  // Dispose
  void dispose() {
    _isDisposed = true;
    stopAutoSync();
    if (!_syncStatusController.isClosed) {
      _syncStatusController.close();
    }
  }
}

// Sync status model
class SyncStatus {
  final String type; // 'started', 'completed', 'failed'
  final String? message;
  
  factory SyncStatus.started() {
    return SyncStatus._internal('started', null);
  }
  
  factory SyncStatus.completed({required String message}) {
    return SyncStatus._internal('completed', message);
  }
  
  factory SyncStatus.failed({required String message}) {
    return SyncStatus._internal('failed', message);
  }
  
  SyncStatus._internal(this.type, this.message);
  
  bool get isStarted => type == 'started';
  bool get isCompleted => type == 'completed';
  bool get isFailed => type == 'failed';
}