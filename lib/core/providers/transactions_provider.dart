import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_provider.dart';

class TransactionsProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthProvider? _auth;

  List<Map<String, dynamic>> _transactionsLedger = [];
  List<Map<String, dynamic>> _salesList = [];
  List<Map<String, dynamic>> _supportTickets = [];

  StreamSubscription? _transactionsSub;
  StreamSubscription? _salesSub;
  StreamSubscription? _supportSub;

  DateTimeRange? _dashboardDateRange;

  TransactionsProvider(this._auth) {
    _auth?.addListener(_onAuthChanged);
    if (_auth?.activeUserPhone != null) {
      _startListeners();
    }
  }

  void _onAuthChanged() {
    if (_auth?.activeUserPhone != null) {
      _startListeners();
    } else {
      _cancelListeners();
      _transactionsLedger = [];
      _salesList = [];
      _supportTickets = [];
      notifyListeners();
    }
  }

  void _startListeners() {
    _cancelListeners();

    _transactionsSub = _db
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _transactionsLedger = snapshot.docs
          .map((doc) => {'docId': doc.id, ...doc.data()})
          .toList();
      notifyListeners();
    });

    _salesSub = _db.collection('sales').snapshots().listen((snapshot) {
      _salesList = snapshot.docs
          .map((doc) => {'docId': doc.id, ...doc.data()})
          .toList();
      notifyListeners();
    });

    _supportSub = _db.collection('support_tickets').snapshots().listen((snapshot) {
      _supportTickets = snapshot.docs
          .map((doc) => {'docId': doc.id, ...doc.data()})
          .toList();
      notifyListeners();
    });
  }

  void _cancelListeners() {
    _transactionsSub?.cancel();
    _salesSub?.cancel();
    _supportSub?.cancel();
    _transactionsSub = null;
    _salesSub = null;
    _supportSub = null;
  }

  @override
  void dispose() {
    _cancelListeners();
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  // ---------- Getters ----------
  List<Map<String, dynamic>> get transactionsLedger => _transactionsLedger;
  List<Map<String, dynamic>> get salesList => _salesList;
  List<Map<String, dynamic>> get supportTickets => _supportTickets;

  DateTimeRange? get dashboardDateRange => _dashboardDateRange;
  void setDashboardDateRange(DateTimeRange? range) {
    _dashboardDateRange = range;
    notifyListeners();
  }

  // ---------- الدالة الجديدة لإضافة حركة ----------
  Future<void> addTransaction(Map<String, dynamic> transaction) async {
    // نضمن أن timestamp هو FieldValue.serverTimestamp() إن لم يُحدد
    final data = Map<String, dynamic>.from(transaction);
    data['timestamp'] = FieldValue.serverTimestamp(); // سيحل محله الوقت الحقيقي عند الحفظ

    try {
      await _db.collection('transactions').add(data);
      // لا داعي لإضافتها محلياً لأن الـ stream سيقوم بتحديث القائمة تلقائياً
      // لكن يمكننا إصدار notifyListeners بعد الإضافة إن أردنا (اختياري)
    } catch (e) {
      debugPrint('خطأ في إضافة الحركة: $e');
      rethrow;
    }
  }

  double get filteredSales {
    return _salesList.where((sale) {
      final dateStr = sale['date'] ?? DateTime.now().toIso8601String();
      try {
        final date = DateTime.parse(dateStr);
        if (_dashboardDateRange != null) {
          return date.isAfter(_dashboardDateRange!.start
                  .subtract(const Duration(days: 1))) &&
              date.isBefore(
                  _dashboardDateRange!.end.add(const Duration(days: 1)));
        }
        return date.year == DateTime.now().year &&
            date.month == DateTime.now().month &&
            date.day == DateTime.now().day;
      } catch (e) {
        return false;
      }
    }).fold(0.0, (sum, sale) => sum + ((sale['amount'] ?? 0.0) as num));
  }

  double get filteredProfit {
    return _salesList.where((sale) {
      final dateStr = sale['date'] ?? DateTime.now().toIso8601String();
      try {
        final date = DateTime.parse(dateStr);
        if (_dashboardDateRange != null) {
          return date.isAfter(_dashboardDateRange!.start
                  .subtract(const Duration(days: 1))) &&
              date.isBefore(
                  _dashboardDateRange!.end.add(const Duration(days: 1)));
        }
        return date.year == DateTime.now().year &&
            date.month == DateTime.now().month &&
            date.day == DateTime.now().day;
      } catch (e) {
        return false;
      }
    }).fold(0.0, (sum, sale) => sum + ((sale['profit'] ?? 0.0) as num));
  }

  int get openTicketsCount =>
      _supportTickets.where((ticket) => ticket['status'] == 'مفتوحة').length;
  int get criticalTicketsCount => _supportTickets
      .where((ticket) =>
          ticket['status'] == 'مفتوحة' && ticket['priority'] == 'عالية')
      .length;
}
