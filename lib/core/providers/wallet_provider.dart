import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class WalletProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthProvider? _auth;

  WalletProvider(this._auth) {
    _auth?.addListener(_onAuthChanged);
    if (_auth?.activeUserPhone != null) {
      _startListeners();
    }
  }

  @override
  void dispose() {
    _cancelListeners();
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  // ---------- جميع البيانات المخزنة محلياً ----------
  List<Map<String, dynamic>> _usersDatabase = [];
  List<Map<String, dynamic>> _rechargeRequests = [];
  List<Map<String, dynamic>> _transactionsLedger = [];
  List<Map<String, dynamic>> _salesList = [];
  List<Map<String, dynamic>> _supportTickets = [];
  List<Map<String, dynamic>> _bankAccounts = [];
  List<Map<String, dynamic>> _myAgentBankAccounts = [];

  StreamSubscription? _usersSub;
  StreamSubscription? _rechargeSub;
  StreamSubscription? _transactionsSub;
  StreamSubscription? _salesSub;
  StreamSubscription? _supportSub;
  StreamSubscription? _bankAccountsSub;
  StreamSubscription? _agentBankSub;

  DateTimeRange? _dashboardDateRange;

  void _onAuthChanged() {
    if (_auth?.activeUserPhone != null) {
      _startListeners();
    } else {
      _cancelListeners();
      _myAgentBankAccounts = [];
      notifyListeners();
    }
  }

  void _startListeners() {
    _cancelListeners();

    _usersSub = _db.collection('users').snapshots().listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        _usersDatabase = snapshot.docs.map((doc) => doc.data()).toList();
        _runAutoRadar(_usersDatabase);
        notifyListeners();
      }
    });

    _rechargeSub = _db
        .collection('recharge_requests')
        .where('status', isEqualTo: 'قيد الانتظار')
        .snapshots()
        .listen((snapshot) {
      _rechargeRequests = snapshot.docs
          .map((doc) => {'docId': doc.id, ...doc.data()})
          .toList();
      notifyListeners();
    });

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

    _bankAccountsSub = _db
        .collection('bank_accounts')
        .orderBy('order')
        .snapshots()
        .listen((snapshot) {
      _bankAccounts = snapshot.docs
          .map((doc) => {'docId': doc.id, ...doc.data()})
          .toList();
      notifyListeners();
    });

    if (_auth?.currentUserRole == 'agent' ||
        _auth?.currentUserRole == 'super_admin') {
      _agentBankSub = _db
          .collection('agent_bank_accounts')
          .where('agentPhone', isEqualTo: _auth!.activeUserPhone)
          .orderBy('order')
          .snapshots()
          .listen((snapshot) {
        _myAgentBankAccounts = snapshot.docs
            .map((doc) => {'docId': doc.id, ...doc.data()})
            .toList();
        notifyListeners();
      });
    }
  }

  void _cancelListeners() {
    _usersSub?.cancel();
    _rechargeSub?.cancel();
    _transactionsSub?.cancel();
    _salesSub?.cancel();
    _supportSub?.cancel();
    _bankAccountsSub?.cancel();
    _agentBankSub?.cancel();
    _usersSub = null;
    _rechargeSub = null;
    _transactionsSub = null;
    _salesSub = null;
    _supportSub = null;
    _bankAccountsSub = null;
    _agentBankSub = null;
  }

  // ---------- الرادار التلقائي ----------
  void _runAutoRadar(List<Map<String, dynamic>> users) {
    final now = DateTime.now();
    WriteBatch batch = _db.batch();
    bool needsUpdate = false;

    for (var user in users) {
      if (user['role'] == 'agent' &&
          user['subExpiry'] != null &&
          user['subStatus'] == 'نشط') {
        try {
          DateTime expiryDate = DateTime.parse(user['subExpiry']);
          if (now.isAfter(expiryDate)) {
            DocumentReference ref = _db.collection('users').doc(user['phone']);
            batch.update(ref, {'subStatus': 'إنذار'});
            needsUpdate = true;
          }
        } catch (e) {}
      }
    }
    if (needsUpdate) batch.commit();
  }

  // ---------- Getters الأساسية ----------
  List<Map<String, dynamic>> get usersDatabase => _usersDatabase;
  List<Map<String, dynamic>> get agentsList =>
      _usersDatabase.where((user) => user['role'] == 'agent').toList();
  List<Map<String, dynamic>> get usersList =>
      _usersDatabase
          .where((user) => user['role'] == 'user' || user['role'] == 'pos')
          .toList();
  List<Map<String, dynamic>> get pendingRechargeRequests => _rechargeRequests;
  List<Map<String, dynamic>> get transactionsLedger => _transactionsLedger;
  List<Map<String, dynamic>> get salesList => _salesList;
  List<Map<String, dynamic>> get supportTickets => _supportTickets;
  List<Map<String, dynamic>> get bankAccounts => _bankAccounts;
  List<Map<String, dynamic>> get myAgentBankAccounts => _myAgentBankAccounts;

  DateTimeRange? get dashboardDateRange => _dashboardDateRange;
  void setDashboardDateRange(DateTimeRange? range) {
    _dashboardDateRange = range;
    notifyListeners();
  }

  double get currentUserBalance {
    if (_auth?.activeUserPhone == null) return 0.0;
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'balance': 0.0});
    if (user['role'] == 'user' || user['role'] == 'pos') {
      Map<String, dynamic> wallets = user['wallets'] ?? {};
      return wallets.values.fold(0.0, (sum, val) => sum + (val as num).toDouble());
    }
    return (user['balance'] ?? 0.0).toDouble();
  }

  double get availableBalance => currentUserBalance - heldBalance;

  double get heldBalance {
    if (_auth?.activeUserPhone == null) return 0.0;
    final user = _usersDatabase.firstWhere(
      (u) => u['phone'] == _auth!.activeUserPhone,
      orElse: () => {'heldBalance': 0.0},
    );
    return (user['heldBalance'] ?? 0.0).toDouble();
  }

  String get currentUserName {
    if (_auth?.activeUserPhone == null) return '';
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'name': ''});
    return user['name'] ?? '';
  }

  String? get activeUserPhone => _auth?.activeUserPhone;

  String get currentUserPin {
    if (_auth?.activeUserPhone == null) return '';
    final user = _usersDatabase.firstWhere(
      (u) => u['phone'] == _auth!.activeUserPhone,
      orElse: () => {'pin': '123456'},
    );
    return user['pin'] ?? '123456';
  }

  String get currentUserNetwork {
    if (_auth?.activeUserPhone == null) return 'غير محدد';
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'networkName': 'غير محدد'});
    return user['networkName'] ?? 'غير محدد';
  }

  List<String> get currentUserNetworkIds {
    if (_auth?.activeUserPhone == null) return [];
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'networkIds': <String>[]});
    return List<String>.from(user['networkIds'] ?? []);
  }

  String? get currentUserAccountNumber {
    if (_auth?.activeUserPhone == null) return null;
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {});
    return user['accountNumber']?.toString();
  }

  bool get currentUserPrivacyShowPhone {
    if (_auth?.activeUserPhone == null) return true;
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'privacy_showPhone': true});
    return user['privacy_showPhone'] ?? true;
  }

  bool get isBiometricCurrentlyEnabled {
    if (_auth?.activeUserPhone == null) return false;
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'isBiometricEnabled': false});
    return user['isBiometricEnabled'] ?? false;
  }

  double getWalletBalance(String agentPhone) {
    if (_auth?.activeUserPhone == null) return 0.0;
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'wallets': {}});
    Map<String, dynamic> wallets = user['wallets'] ?? {};
    return (wallets[agentPhone] ?? 0.0).toDouble();
  }

  List<Map<String, dynamic>> get userPurchasedCards {
    if (_auth?.activeUserPhone == null) return [];
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {'purchasedCards': []});
    var rawList = user['purchasedCards'] ?? [];
    List<Map<String, dynamic>> structuredList = [];
    for (var item in rawList) {
      if (item is Map) {
        structuredList.add(Map<String, dynamic>.from(item));
      } else if (item is String) {
        structuredList.add({
          'title': item,
          'pin': 'بيانات قديمة',
          'price': 0.0,
          'date': ''
        });
      }
    }
    return structuredList;
  }

  // ---------- أرقام الحسابات ----------
  bool _isSpecialAccountNumber(String numberStr) {
    final num = int.tryParse(numberStr);
    if (num == null || num < 10000) return true;
    if (numberStr.length >= 5 && numberStr.split('').toSet().length == 1) return true;
    final ascending = '0123456789';
    if (ascending.contains(numberStr)) return true;
    final descending = '9876543210';
    if (descending.contains(numberStr)) return true;
    return false;
  }

  Future<String> _generateNextAccountNumber() async {
    final usersSnapshot = await _db
        .collection('users')
        .where('accountNumber', isNotEqualTo: null)
        .get();

    List<int> existingNumbers = [];
    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      final acc = data['accountNumber'];
      if (acc != null) {
        final num = int.tryParse(acc.toString());
        if (num != null) existingNumbers.add(num);
      }
    }

    int candidate = 10000;
    if (existingNumbers.isNotEmpty) {
      candidate = existingNumbers.reduce((a, b) => a > b ? a : b) + 1;
      if (candidate > 19999 && candidate < 100000) {
        candidate = 100000;
      } else if (candidate > 199999 && candidate < 1000000) {
        candidate = 1000000;
      } else if (candidate > 1999999 && candidate < 10000000) {
        candidate = 10000000;
      }
    }

    while (_isSpecialAccountNumber(candidate.toString())) {
      candidate++;
      if (candidate > 19999 && candidate < 100000) {
        candidate = 100000;
      } else if (candidate > 199999 && candidate < 1000000) {
        candidate = 1000000;
      } else if (candidate > 1999999 && candidate < 10000000) {
        candidate = 10000000;
      }
    }

    return candidate.toString();
  }

  Future<void> _ensureUserAccountNumber() async {
    if (_auth?.activeUserPhone == null) return;
    try {
      final doc = await _db.collection('users').doc(_auth!.activeUserPhone).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['accountNumber'] == null) {
          final newAcc = await _generateNextAccountNumber();
          await _db.collection('users').doc(_auth!.activeUserPhone).update({
            'accountNumber': newAcc,
          });
        }
      }
    } catch (e) {
      debugPrint('خطأ في ضمان رقم الحساب: $e');
    }
  }

  Future<int> adminGenerateMissingAccountNumbers() async {
    int generated = 0;
    try {
      final usersSnapshot = await _db.collection('users').get();
      for (var doc in usersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['accountNumber'] == null) {
          final newAcc = await _generateNextAccountNumber();
          await doc.reference.update({'accountNumber': newAcc});
          generated++;
        }
      }
    } catch (e) {
      throw 'خطأ في التوليد الجماعي: $e';
    }
    return generated;
  }

  Future<void> adminUpdateUserAccountNumber(String phone, String newAccountNumber) async {
    final existing = await _db
        .collection('users')
        .where('accountNumber', isEqualTo: newAccountNumber)
        .get();
    if (existing.docs.isNotEmpty) {
      if (existing.docs.length > 1 || existing.docs.first.id != phone) {
        throw 'رقم الحساب مستخدم من قبل شخص آخر.';
      }
    }
    await _db.collection('users').doc(phone).update({
      'accountNumber': newAccountNumber,
    });
    _logAction(
        action: 'تعديل رقم حساب',
        details: 'تم تغيير رقم حساب $phone إلى $newAccountNumber',
        severity: 'high');
  }

  Future<void> adminToggleUserBan(String phone, bool ban) async {
    await _db.collection('users').doc(phone).update({
      'isBanned': ban,
    });
    _logAction(
        action: ban ? 'حظر حساب' : 'فك حظر حساب',
        details: 'المستخدم: $phone',
        severity: 'critical');
  }

  List<Map<String, dynamic>> getAllUsersWithAccountDetails() {
    return _usersDatabase.map((user) {
      return {
        'phone': user['phone'],
        'accountNumber': user['accountNumber'] ?? 'غير متوفر',
        'name': user['name'] ?? 'غير معروف',
        'role': user['role'] ?? 'مستخدم',
        'isBanned': user['isBanned'] ?? false,
        'privacyShowPhone': user['privacy_showPhone'] ?? true,
      };
    }).toList();
  }

  // ---------- البحث عن المستخدمين ----------
  Future<Map<String, dynamic>?> searchUserByAccountOrName(String query) async {
    if (query.trim().isEmpty) return null;
    final isNumeric = RegExp(r'^\d+$').hasMatch(query.trim());

    try {
      if (isNumeric) {
        final snap = await _db
            .collection('users')
            .where('accountNumber', isEqualTo: query.trim())
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data() as Map<String, dynamic>;
          if (data['isBanned'] == true) return null;
          return _buildSearchResult(data, snap.docs.first.id);
        }
      } else {
        for (var user in _usersDatabase) {
          final name = user['name']?.toString() ?? '';
          if (name.contains(query.trim())) {
            if (user['isBanned'] == true) continue;
            return _buildSearchResult(user, user['phone'] ?? '');
          }
        }
        final snap = await _db
            .collection('users')
            .where('name', isGreaterThanOrEqualTo: query.trim())
            .where('name', isLessThan: '${query.trim()}z')
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data() as Map<String, dynamic>;
          return _buildSearchResult(data, snap.docs.first.id);
        }
      }
      return null;
    } catch (e) {
      throw 'خطأ في البحث: $e';
    }
  }

  Map<String, dynamic> _buildSearchResult(Map<String, dynamic> data, String phone) {
    final bool showPhone = data['privacy_showPhone'] ?? true;
    final bool hideBalance = data['privacy_hideBalance'] ?? false;
    final bool showFullName = data['privacy_showFullName'] ?? true;
    return {
      'accountNumber': data['accountNumber'] ?? 'غير متوفر',
      'name': showFullName ? (data['name'] ?? 'مجهول') : 'مخفي',
      'role': data['role'] ?? 'user',
      'phone': showPhone ? phone : 'مخفي',
      'balance': hideBalance ? 0.0 : _getUserBalance(data, phone),
    };
  }

  double _getUserBalance(Map<String, dynamic> data, String phone) {
    if (data['role'] == 'user' || data['role'] == 'pos') {
      Map<String, dynamic> wallets = data['wallets'] ?? {};
      return wallets.values.fold(0.0, (sum, val) => sum + (val as num).toDouble());
    }
    return (data['balance'] ?? 0.0).toDouble();
  }

  Future<Map<String, dynamic>?> searchUserByAdmin(String query) async {
    if (query.trim().isEmpty) return null;
    final isNumeric = RegExp(r'^\d+$').hasMatch(query.trim());
    try {
      if (isNumeric) {
        var snap = await _db
            .collection('users')
            .where('accountNumber', isEqualTo: query.trim())
            .limit(1)
            .get();
        if (snap.docs.isEmpty) {
          snap = await _db
              .collection('users')
              .where('phone', isEqualTo: query.trim())
              .limit(1)
              .get();
        }
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data() as Map<String, dynamic>;
          return {
            ...data,
            'phone': snap.docs.first.id,
          };
        }
      } else {
        final snap = await _db
            .collection('users')
            .where('name', isGreaterThanOrEqualTo: query.trim())
            .where('name', isLessThan: '${query.trim()}z')
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data() as Map<String, dynamic>;
          return {
            ...data,
            'phone': snap.docs.first.id,
          };
        }
      }
      return null;
    } catch (e) {
      throw 'خطأ في البحث الإداري: $e';
    }
  }

  Future<Map<String, dynamic>?> searchUserForTransfer(String targetPhone) async {
    if (_auth?.activeUserPhone == null) throw 'يرجى تسجيل الدخول.';
    if (targetPhone == _auth!.activeUserPhone) throw 'لا يمكنك تحويل الرصيد لنفسك!';

    try {
      final doc = await _db.collection('users').doc(targetPhone).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;

      var lastTxn = await _db
          .collection('transactions')
          .where('toPhone', isEqualTo: targetPhone)
          .where('fromPhone', isEqualTo: _auth!.activeUserPhone)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      String lastRecharge = 'لا يوجد سجل سابق';
      if (lastTxn.docs.isNotEmpty) {
        var tData = lastTxn.docs.first.data() as Map<String, dynamic>;
        if (tData['timestamp'] != null) {
          lastRecharge = DateFormat('yyyy-MM-dd hh:mm a')
              .format((tData['timestamp'] as Timestamp).toDate());
        }
      }

      double displayBalance = 0.0;
      if (data['role'] == 'user' || data['role'] == 'pos') {
        Map<String, dynamic> wallets = data['wallets'] ?? {};
        displayBalance = (wallets[_auth!.activeUserPhone] ?? 0.0).toDouble();
      } else {
        displayBalance = (data['balance'] ?? 0.0).toDouble();
      }

      return {
        'name': data['name'] ?? 'مجهول',
        'role': data['role'] ?? 'user',
        'networkName': data['networkName'] ?? 'غير محدد',
        'balance': displayBalance,
        'lastRecharge': lastRecharge,
      };
    } catch (e) {
      throw 'حدث خطأ أثناء البحث عن الرقم.';
    }
  }

  // ---------- إعدادات المستخدم الشخصية ----------
  Future<bool> changeUserName(String newName) async {
    if (_auth?.activeUserPhone == null) return false;
    try {
      await _db.collection('users').doc(_auth!.activeUserPhone).update({'name': newName});
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> changeUserPin(String oldPin, String newPin) async {
    if (_auth?.activeUserPhone == null) return false;
    if (currentUserPin == oldPin) {
      await _db.collection('users').doc(_auth!.activeUserPhone).update({'pin': newPin});
      return true;
    }
    return false;
  }

  Future<String> changeUserPinWithOld(String oldPin, String newPin, String confirmPin) async {
    if (_auth?.activeUserPhone == null) return 'يرجى تسجيل الدخول.';
    if (newPin.length != 6) return 'يجب أن يتكون رمز PIN من 6 أرقام.';
    if (newPin != confirmPin) return 'رمز PIN الجديد غير متطابق.';

    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {});
    if (user.isEmpty) return 'المستخدم غير موجود.';

    String storedPin = user['pin'] ?? '123456';
    if (storedPin != oldPin) return 'رمز PIN القديم غير صحيح.';

    await _db.collection('users').doc(_auth!.activeUserPhone).update({'pin': newPin});
    final index = _usersDatabase.indexWhere((u) => u['phone'] == _auth!.activeUserPhone);
    if (index != -1) {
      _usersDatabase[index]['pin'] = newPin;
      notifyListeners();
    }
    return 'تم تحديث رمز PIN بنجاح.';
  }

  bool changeUserPassword(String oldPassword, String newPassword) {
    if (_auth?.activeUserPhone == null) return false;
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _auth!.activeUserPhone);
    if (user['password'] == oldPassword) {
      _db.collection('users').doc(_auth!.activeUserPhone).update({'password': newPassword});
      return true;
    }
    return false;
  }

  void toggleBiometric(bool isEnabled) {
    if (_auth?.activeUserPhone == null) return;
    _db.collection('users').doc(_auth!.activeUserPhone).update({'isBiometricEnabled': isEnabled});
  }

  Future<void> updatePrivacySettings({required bool showPhone}) async {
    if (_auth?.activeUserPhone == null) return;
    await _db.collection('users').doc(_auth!.activeUserPhone).update({
      'privacy_showPhone': showPhone,
    });
    final index = _usersDatabase.indexWhere((u) => u['phone'] == _auth!.activeUserPhone);
    if (index != -1) {
      _usersDatabase[index]['privacy_showPhone'] = showPhone;
      notifyListeners();
    }
  }

  Future<void> updatePrivacySetting(String key, bool value) async {
    if (_auth?.activeUserPhone == null) return;
    await _db.collection('users').doc(_auth!.activeUserPhone).update({'privacy_$key': value});
  }

  Future<void> updateUserDailyLimit(double limit) async {
    if (_auth?.activeUserPhone == null) return;
    await _db.collection('users').doc(_auth!.activeUserPhone).update({'dailyLimit': limit});
    final index = _usersDatabase.indexWhere((u) => u['phone'] == _auth!.activeUserPhone);
    if (index != -1) {
      _usersDatabase[index]['dailyLimit'] = limit;
      notifyListeners();
    }
  }

  Future<void> updateUserMonthlyLimit(double limit) async {
    if (_auth?.activeUserPhone == null) return;
    await _db.collection('users').doc(_auth!.activeUserPhone).update({'monthlyLimit': limit});
    final index = _usersDatabase.indexWhere((u) => u['phone'] == _auth!.activeUserPhone);
    if (index != -1) {
      _usersDatabase[index]['monthlyLimit'] = limit;
      notifyListeners();
    }
  }

  Future<bool> deleteUserAccount(String password) async {
    if (_auth?.activeUserPhone == null) return false;
    try {
      final doc = await _db.collection('users').doc(_auth!.activeUserPhone).get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;
      if (data['password'] != password) return false;

      await _db.collection('users').doc(_auth!.activeUserPhone).delete();
      return true;
    } catch (e) {
      debugPrint('خطأ في حذف الحساب: $e');
      return false;
    }
  }

  Future<void> saveUserPreferredColor(Color color) async {
    if (_auth?.activeUserPhone == null) return;
    final colorValue = color.value;
    await _db.collection('users').doc(_auth!.activeUserPhone).update({
      'preferredColor': colorValue,
    });
  }

  Future<Color?> getUserPreferredColor() async {
    if (_auth?.activeUserPhone == null) return null;
    try {
      final doc = await _db.collection('users').doc(_auth!.activeUserPhone).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final colorValue = data['preferredColor'];
        if (colorValue != null) {
          return Color(colorValue);
        }
      }
    } catch (e) {
      debugPrint('خطأ في جلب اللون المفضل: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getUserTierForAgent(String agentPhone) async {
    if (_auth?.activeUserPhone == null) return null;

    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {});
    Map<String, dynamic> wallets = user['wallets'] ?? {};
    double walletBalance = (wallets[agentPhone] ?? 0.0).toDouble();

    final tierQuery = await _db.collection('discount_tiers')
        .where('agentPhone', isEqualTo: agentPhone)
        .where('isActive', isEqualTo: true)
        .get();

    if (tierQuery.docs.isEmpty) return null;

    List<Map<String, dynamic>> tiers = tierQuery.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();

    tiers.sort((a, b) => (b['condition'] as int).compareTo(a['condition'] as int));

    for (var tier in tiers) {
      if (walletBalance >= (tier['condition'] as num).toDouble()) {
        return tier;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> getUserHighestTier() async {
    if (_auth?.activeUserPhone == null) return null;

    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _auth!.activeUserPhone,
        orElse: () => {});
    Map<String, dynamic> wallets = user['wallets'] ?? {};
    if (wallets.isEmpty) return null;

    Map<String, dynamic>? bestTier;
    double bestCondition = 0;

    for (var agentPhone in wallets.keys) {
      final tier = await getUserTierForAgent(agentPhone);
      if (tier != null && (tier['condition'] as num).toDouble() > bestCondition) {
        bestCondition = (tier['condition'] as num).toDouble();
        bestTier = tier;
      }
    }
    return bestTier;
  }

  bool validatePin(String pin) {
    if (_auth?.activeUserPhone == null) return false;
    return currentUserPin == pin;
  }

  // ---------- إدارة الوكلاء (مدير عام) ----------
  Future<void> addAgent({
    required String name,
    required String phone,
    required String password,
    String? networkName,
    String? profitMargin,
    String? location,
    double initialBalance = 0.0,
  }) async {
    try {
      bool exists = await checkUserExists(phone);
      if (!exists) {
        final DateTime nextMonth = DateTime.now().add(const Duration(days: 30));
        final String expiryDate =
            '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}-${nextMonth.day.toString().padLeft(2, '0')}';

        await _db.collection('users').doc(phone).set({
          'id': 'AGENT_${DateTime.now().millisecondsSinceEpoch}',
          'name': name,
          'phone': phone,
          'password': password,
          'role': 'agent',
          'networkName': networkName ?? 'غير محدد',
          'profitMargin': profitMargin ?? 'غير محدد',
          'location': location ?? 'غير محدد',
          'balance': initialBalance,
          'dangerLimit': 0.0,
          'status': 'نشط',
          'pin': '123456',
          'subPlan': 'باقة افتراضية',
          'subPrice': 0.0,
          'subStatus': 'نشط',
          'subExpiry': expiryDate,
          'purchasedCards': [],
          'isBiometricEnabled': false,
          'createdAt': FieldValue.serverTimestamp(),
          'hiddenSections': [],
          'privacy_showPhone': true,
        });
        _logAction(
            action: 'إضافة وكيل جديد',
            details: 'تم إضافة وكيل جديد باسم "$name" ورقم $phone',
            severity: 'medium');

        _sendNotification(
            targetPhones: [phone],
            title: 'أهلاً بك كوكيل جديد! 🎉',
            body: 'تم تفعيل حسابك كوكيل معتمد في النظام.');
      } else {
        throw 'رقم الهاتف مسجل مسبقاً في النظام!';
      }
    } catch (e) {
      throw 'حدث خطأ: $e';
    }
  }

  Future<void> updateAgentDetails({
    required String oldPhone,
    required String newPhone,
    required String newName,
    required String newNetwork,
    required String newLocation,
    required String newProfit,
    required String newPassword,
  }) async {
    try {
      final doc = await _db.collection('users').doc(oldPhone).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data.addAll({
          'phone': newPhone,
          'name': newName,
          'networkName': newNetwork,
          'location': newLocation,
          'profitMargin': newProfit,
          'password': newPassword
        });
        WriteBatch batch = _db.batch();
        batch.set(_db.collection('users').doc(newPhone), data);
        if (oldPhone != newPhone) batch.delete(_db.collection('users').doc(oldPhone));
        await batch.commit();
      }
    } catch (e) {
      throw 'فشل تعديل بيانات الوكيل: $e';
    }
  }

  void toggleUserStatus(String phone, String currentStatus) {
    try {
      String newStatus = currentStatus == 'نشط' ? 'مجمد' : 'نشط';
      _db.collection('users').doc(phone).update({'status': newStatus});
    } catch (e) {}
  }

  void deleteAgent(String phone) {
    try {
      _db.collection('users').doc(phone).delete();
    } catch (e) {}
  }

  Future<bool> checkUserExists(String phone) async {
    try {
      final doc = await _db.collection('users').doc(phone).get().timeout(const Duration(seconds: 5));
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // ---------- نقاط البيع ----------
  Future<void> upgradeUserToPos({
    required String posPhone,
    required String storeName,
    required String location,
    required double creditLimit,
    required String commission,
    required List<String> allowedCategories,
    required double creditDeduction,
  }) async {
    if (_auth?.activeUserPhone == null) return;
    try {
      final doc = await _db.collection('users').doc(posPhone).get();
      if (!doc.exists) throw 'الرقم غير مسجل كزبون مسبقاً.';

      final userData = doc.data() as Map<String, dynamic>;
      if (userData['role'] != 'user' && userData['role'] != 'pos') {
        throw 'لا يمكن تعديل صلاحية هذا الحساب.';
      }

      WriteBatch batch = _db.batch();

      batch.update(doc.reference, {
        'role': 'pos',
        'storeName': storeName,
        'location': location,
        'pos_agents': FieldValue.arrayUnion([_auth!.activeUserPhone]),
        'agent_relations.$_activeUserPhone': {
          'creditLimit': creditLimit,
          'commission': commission,
          'allowedCategories': allowedCategories,
        }
      });

      batch.set(
          _db.collection('points_of_sale').doc(posPhone),
          {
            'phone': posPhone,
            'name': storeName,
            'location': location,
            'ownerName': userData['name'],
            'pos_agents': FieldValue.arrayUnion([_auth!.activeUserPhone]),
            'status': 'نشط',
          },
          SetOptions(merge: true));

      final agentRef = _db.collection('users').doc(_auth!.activeUserPhone);
      batch.update(agentRef, {'balance': FieldValue.increment(-creditDeduction)});

      DocumentReference txnRef = _db.collection('transactions').doc();
      batch.set(txnRef, {
        'fromPhone': _auth!.activeUserPhone,
        'toPhone': posPhone,
        'agentPhone': _auth!.activeUserPhone,
        'agentName': currentUserName,
        'targetName': userData['name'] ?? 'مستخدم',
        'networkName': userData['networkName'] ?? 'غير محدد',
        'amount': creditDeduction,
        'type': 'credit_deduction',
        'title': 'حجز رصيد ائتماني لنقطة بيع: $storeName',
        'reference': 'CRD-${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': FieldValue.serverTimestamp()
      });

      batch.set(_db.collection('notifications').doc(), {
        'targetPhones': [posPhone],
        'title': 'اعتماد نقطة بيع 🏪',
        'body': 'تم ربط حسابك بالوكيل $currentUserName بأسعار الجملة بنجاح.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'readBy': [],
      });

      await batch.commit();
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> updatePosDetails({
    required String posPhone,
    required String storeName,
    required String location,
    required double creditLimit,
    required String commission,
    required List<String> allowedCategories,
    required double oldCreditLimit,
  }) async {
    if (_auth?.activeUserPhone == null) return;
    try {
      WriteBatch batch = _db.batch();

      batch.update(_db.collection('users').doc(posPhone), {
        'storeName': storeName,
        'location': location,
        'agent_relations.$_activeUserPhone.creditLimit': creditLimit,
        'agent_relations.$_activeUserPhone.commission': commission,
        'agent_relations.$_activeUserPhone.allowedCategories': allowedCategories,
      });

      batch.update(_db.collection('points_of_sale').doc(posPhone), {
        'name': storeName,
        'location': location,
      });

      double difference = creditLimit - oldCreditLimit;
      if (difference > 0) {
        final agentRef = _db.collection('users').doc(_auth!.activeUserPhone);
        batch.update(agentRef, {'balance': FieldValue.increment(-difference)});

        DocumentReference txnRef = _db.collection('transactions').doc();
        batch.set(txnRef, {
          'fromPhone': _auth!.activeUserPhone,
          'toPhone': posPhone,
          'agentPhone': _auth!.activeUserPhone,
          'agentName': currentUserName,
          'targetName': 'نقطة بيع: $storeName',
          'networkName': 'النظام',
          'amount': difference,
          'type': 'credit_deduction',
          'title': 'زيادة الحد الائتماني لـ $storeName',
          'reference': 'CRD-${DateTime.now().millisecondsSinceEpoch}',
          'timestamp': FieldValue.serverTimestamp()
        });
      } else if (difference < 0) {
        double refund = (-difference);
        final agentRef = _db.collection('users').doc(_auth!.activeUserPhone);
        batch.update(agentRef, {'balance': FieldValue.increment(refund)});

        DocumentReference txnRef = _db.collection('transactions').doc();
        batch.set(txnRef, {
          'fromPhone': posPhone,
          'toPhone': _auth!.activeUserPhone,
          'agentPhone': _auth!.activeUserPhone,
          'agentName': currentUserName,
          'targetName': 'نقطة بيع: $storeName',
          'networkName': 'النظام',
          'amount': refund,
          'type': 'credit_refund',
          'title': 'تخفيض الحد الائتماني لـ $storeName وإعادة للمحفظة',
          'reference': 'RFD-${DateTime.now().millisecondsSinceEpoch}',
          'timestamp': FieldValue.serverTimestamp()
        });
      }

      await batch.commit();
    } catch (e) {
      throw 'فشل التعديل: $e';
    }
  }

  Future<void> receivePosPayment(String posPhone, double amount, String note) async {
    if (_auth?.activeUserPhone == null) return;
    try {
      final posDoc = await _db.collection('users').doc(posPhone).get();
      final posData = posDoc.data() as Map<String, dynamic>? ?? {};

      WriteBatch batch = _db.batch();

      batch.update(_db.collection('users').doc(posPhone),
          {'wallets.$_activeUserPhone': FieldValue.increment(amount)});

      final agentRef = _db.collection('users').doc(_auth!.activeUserPhone);
      batch.update(agentRef, {'balance': FieldValue.increment(amount)});

      batch.set(_db.collection('transactions').doc(), {
        'fromPhone': posPhone,
        'toPhone': _auth!.activeUserPhone,
        'agentPhone': _auth!.activeUserPhone,
        'agentName': currentUserName,
        'targetName': posData['name'] ?? 'نقطة بيع',
        'networkName': posData['networkName'] ?? 'غير محدد',
        'type': 'deposit',
        'amount': amount,
        'fee': 0.0,
        'paymentMethod': 'نقدي / كاش',
        'note': note,
        'title': 'استلام سداد ديون من: ${posData['name'] ?? ''}',
        'reference': 'REP-${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw e.toString();
    }
  }

  // ---------- الاشتراكات ----------
  Future<void> applySubscriptionPlan({
    required int targetingFilter,
    required String planName,
    required double planPrice,
    required int durationMonths,
    String? targetAgentPhone,
  }) async {
    try {
      WriteBatch batch = _db.batch();
      final DateTime newExpiry = DateTime.now().add(Duration(days: durationMonths * 30));
      final String formattedExpiry =
          '${newExpiry.year}-${newExpiry.month.toString().padLeft(2, '0')}-${newExpiry.day.toString().padLeft(2, '0')}';

      if (targetingFilter == 1) {
        for (var agent in agentsList) {
          DocumentReference ref = _db.collection('users').doc(agent['phone']);
          batch.update(ref, {
            'subPlan': planName,
            'subPrice': planPrice,
            'subExpiry': formattedExpiry,
            'subStatus': 'نشط'
          });
        }
        _sendNotification(
            targetPhones: ['all_agents'],
            title: 'تحديث الباقة 🎁',
            body: 'تم تجديد باقتك إلى "$planName" بنجاح.');
      } else if (targetingFilter == 2 && targetAgentPhone != null) {
        DocumentReference ref = _db.collection('users').doc(targetAgentPhone);
        batch.update(ref, {
          'subPlan': planName,
          'subPrice': planPrice,
          'subExpiry': formattedExpiry,
          'subStatus': 'نشط'
        });
        _sendNotification(
            targetPhones: [targetAgentPhone],
            title: 'تحديث الباقة 🎁',
            body: 'تم تجديد باقتك إلى "$planName" بنجاح.');
      }
      await batch.commit();
    } catch (e) {
      throw 'حدث خطأ: $e';
    }
  }

  Future<void> updateAgentGracePeriod(String agentPhone, String newExpiryDate) async {
    try {
      await _db.collection('users').doc(agentPhone).update({
        'subExpiry': newExpiryDate,
        'subStatus': 'إنذار'
      });
      _sendNotification(
          targetPhones: [agentPhone],
          title: 'تنبيه فترة السماح ⚠️',
          body: 'تم تعديل تاريخ انتهاء باقتك إلى $newExpiryDate');
    } catch (e) {
      throw 'فشل التحديث: $e';
    }
  }

  Future<void> toggleSubscriptionStatus(String agentPhone, String currentStatus) async {
    try {
      String newStatus = currentStatus == 'موقوف مؤقتاً' ? 'نشط' : 'موقوف مؤقتاً';
      await _db.collection('users').doc(agentPhone).update({'subStatus': newStatus});
      _sendNotification(
          targetPhones: [agentPhone],
          title: 'حالة الحساب',
          body: 'تم تحويل حالة حسابك إلى: $newStatus');
    } catch (e) {
      throw 'فشل التغيير: $e';
    }
  }

  // ---------- طلبات الشحن والإيداع ----------
  Future<String> uploadReceiptImage(File file) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance
        .ref()
        .child('receipts')
        .child(currentUserId)
        .child(fileName);
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask.whenComplete(() => null);
    return await snapshot.ref.getDownloadURL();
  }

  String get currentUserId => _auth?.activeUserPhone ?? '';

  Future<void> submitDepositRequest({
    required String bankAccountId,
    required double amount,
    required String reference,
    required String receiptImageUrl,
  }) async {
    String? agentId;
    String? bankName;
    String? accountNumber;

    final agentsSnap = await _db
        .collection('users')
        .where('role', isEqualTo: 'agent')
        .where('networkIds', arrayContainsAny: currentUserNetworkIds)
        .get();

    for (var agentDoc in agentsSnap.docs) {
      final accDoc = await _db.collection('agent_bank_accounts').doc(bankAccountId).get();
      if (accDoc.exists) {
        agentId = agentDoc.id;
        bankName = accDoc.data()?['bankName'] ?? '';
        accountNumber = accDoc.data()?['accountNumber'] ?? '';
        break;
      }
    }

    if (agentId == null) throw Exception('الحساب غير موجود');

    await _db.collection('depositRequests').add({
      'userId': currentUserId,
      'userName': currentUserName,
      'agentId': agentId,
      'bankAccountId': bankAccountId,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'amount': amount,
      'reference': reference,
      'receiptImageUrl': receiptImageUrl,
      'status': 'pending',
      'rejectionReason': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelDepositRequest(String docId) async {
    await _db.collection('depositRequests').doc(docId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> getPendingDepositRequestsStream() {
    return _db
        .collection('depositRequests')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              return {
                'docId': doc.id,
                ...data,
              };
            }).toList());
  }

  Stream<List<Map<String, dynamic>>> getMyPendingUserRecharges() {
    if (_auth?.activeUserPhone == null) return Stream.value([]);
    return _db
        .collection('user_recharges')
        .where('userPhone', isEqualTo: _auth!.activeUserPhone)
        .where('status', isEqualTo: 'قيد الانتظار')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['docId'] = doc.id;
              return data;
            }).toList());
  }

  Stream<List<Map<String, dynamic>>> getPendingPosRechargeRequests() {
    if (_auth?.activeUserPhone == null) return Stream.value([]);
    return _db
        .collection('user_recharges')
        .where('targetPhone', isEqualTo: _auth!.activeUserPhone)
        .where('status', isEqualTo: 'قيد الانتظار')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['docId'] = doc.id;
              return data;
            }).toList());
  }

  Future<void> cancelQuotaRequest(String docId) async {
    await _db.collection('recharge_requests').doc(docId).delete();
  }

  // ---------- تقارير وإحصائيات ----------
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

  Map<String, dynamic> get subscriptionStats {
    int active = 0, expiringSoon = 0, frozen = 0;
    double realExpectedRevenue = 0.0;
    for (var agent in agentsList) {
      String status = agent['subStatus'] ?? 'نشط';
      if (status == 'نشط' || status == 'فترة مجانية') {
        active++;
        realExpectedRevenue += (agent['subPrice'] ?? 0.0).toDouble();
      } else if (status == 'إنذار') {
        expiringSoon++;
      } else if (status == 'مجمد' || status == 'موقوف مؤقتاً') {
        frozen++;
      }
    }
    return {
      'active': active,
      'expiringSoon': expiringSoon,
      'frozen': frozen,
      'expectedRevenue': realExpectedRevenue
    };
  }

  // ---------- الحسابات البنكية للنظام (مدير عام) ----------
  Future<void> addBankAccount(String bankName, String accNumber, String beneficiary) async {
    try {
      int newOrder = _bankAccounts.length;
      await _db.collection('bank_accounts').add({
        'bankName': bankName,
        'accountNumber': accNumber,
        'beneficiary': beneficiary.isNotEmpty ? beneficiary : 'غير محدد',
        'status': 'نشط',
        'hasQR': false,
        'order': newOrder,
        'createdAt': FieldValue.serverTimestamp()
      });
    } catch (e) {
      throw 'خطأ: $e';
    }
  }

  Future<void> updateBankAccount(String docId, String bankName, String accNumber, String beneficiary) async {
    await _db.collection('bank_accounts').doc(docId).update({
      'bankName': bankName,
      'accountNumber': accNumber,
      'beneficiary': beneficiary
    });
  }

  Future<void> toggleBankAccountStatus(String docId, String currentStatus) async {
    String newStatus = currentStatus == 'نشط' ? 'موقوف' : 'نشط';
    await _db.collection('bank_accounts').doc(docId).update({'status': newStatus});
  }

  Future<void> deleteBankAccount(String docId) async {
    await _db.collection('bank_accounts').doc(docId).delete();
  }

  Future<void> reorderBankAccounts(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _bankAccounts.removeAt(oldIndex);
    _bankAccounts.insert(newIndex, item);
    notifyListeners();
    WriteBatch batch = _db.batch();
    for (int i = 0; i < _bankAccounts.length; i++) {
      batch.update(_db.collection('bank_accounts').doc(_bankAccounts[i]['docId']),
          {'order': i});
    }
    await batch.commit();
  }

  // ---------- إعادة التعيين المتقدمة ----------
  Future<String> previewResetImpact({
    required String phone,
    required String accountNumber,
    required String targetType,
    required Map<String, dynamic> options,
  }) async {
    final WriteBatch batch = _db.batch();
    int affected = 0;
    final phones = <String>[];

    if (targetType == 'agent' || targetType == 'user') {
      String? docId = phone.isNotEmpty ? phone : null;
      if (docId == null && accountNumber.isNotEmpty) {
        final snap = await _db
            .collection('users')
            .where('accountNumber', isEqualTo: accountNumber)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) docId = snap.docs.first.id;
      }
      if (docId != null) phones.add(docId);
    } else if (targetType == 'all_agents') {
      phones.addAll(agentsList.map((a) => a['phone'].toString()));
    } else if (targetType == 'all_users') {
      phones.addAll(usersList.map((u) => u['phone'].toString()));
    } else if (targetType == 'self') {
      phones.add(_auth?.activeUserPhone ?? '');
    }

    for (final phone in phones) {
      if (options['resetBalance'] == true) {
        batch.update(_db.collection('users').doc(phone), {'balance': 0, 'wallets': {}});
        affected++;
      }
      if (options['resetNetworks'] == true) {
        final nets = await _db.collection('networks').where('agentPhone', isEqualTo: phone).get();
        for (final d in nets.docs) batch.delete(d.reference);
        affected += nets.size;
      }
      if (options['resetTransactions'] == true) {
        final txns = await _db.collection('transactions').where('fromPhone', isEqualTo: phone).get();
        for (final d in txns.docs) batch.delete(d.reference);
        final txns2 = await _db.collection('transactions').where('toPhone', isEqualTo: phone).get();
        for (final d in txns2.docs) if (!txns.docs.any((e) => e.id == d.id)) batch.delete(d.reference);
        affected += txns.size + txns2.size;
      }
      if (options['resetCards'] == true) {
        final cards = await _db.collection('cards').where('buyerPhone', isEqualTo: phone).get();
        for (final d in cards.docs) batch.delete(d.reference);
        affected += cards.size;
      }
      if (options['resetBankAccounts'] == true) {
        final banks = await _db.collection('agent_bank_accounts').where('agentPhone', isEqualTo: phone).get();
        for (final d in banks.docs) batch.delete(d.reference);
        affected += banks.size;
      }
      if (options['resetSubscriptions'] == true) {
        batch.update(_db.collection('users').doc(phone), {
          'subPlan': '',
          'subPrice': 0,
          'subStatus': 'ملغي',
          'subExpiry': '',
        });
        affected++;
      }
      if (options['deleteAccount'] == true) {
        affected += 5;
      }
    }
    return 'متوقع تأثر حوالي $affected مستند/حقل.';
  }

  Future<void> executeReset({
    required String phone,
    required String accountNumber,
    required String targetType,
    required Map<String, dynamic> options,
    required String adminPassword,
    String? renameTo,
    String? mergeFrom,
    String? mergeTo,
    bool exportBeforeDelete = false,
  }) async {
    final WriteBatch batch = _db.batch();
    final phones = <String>[];

    if (targetType == 'agent' || targetType == 'user') {
      String? docId = phone.isNotEmpty ? phone : null;
      if (docId == null && accountNumber.isNotEmpty) {
        final snap = await _db
            .collection('users')
            .where('accountNumber', isEqualTo: accountNumber)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) docId = snap.docs.first.id;
      }
      if (docId != null) phones.add(docId);
    } else if (targetType == 'all_agents') {
      phones.addAll(agentsList.map((a) => a['phone'].toString()));
    } else if (targetType == 'all_users') {
      phones.addAll(usersList.map((u) => u['phone'].toString()));
    } else if (targetType == 'self') {
      phones.add(_auth?.activeUserPhone ?? '');
    }

    for (final phone in phones) {
      if (options['resetBalance'] == true) {
        batch.update(_db.collection('users').doc(phone), {'balance': 0, 'wallets': {}});
      }
      if (options['resetNetworks'] == true) {
        final nets = await _db.collection('networks').where('agentPhone', isEqualTo: phone).get();
        for (final d in nets.docs) batch.delete(d.reference);
      }
      if (options['resetTransactions'] == true) {
        final txns = await _db.collection('transactions').where('fromPhone', isEqualTo: phone).get();
        for (final d in txns.docs) batch.delete(d.reference);
        final txns2 = await _db.collection('transactions').where('toPhone', isEqualTo: phone).get();
        for (final d in txns2.docs) if (!txns.docs.any((e) => e.id == d.id)) batch.delete(d.reference);
      }
      if (options['resetCards'] == true) {
        final cards = await _db.collection('cards').where('buyerPhone', isEqualTo: phone).get();
        for (final d in cards.docs) batch.delete(d.reference);
      }
      if (options['resetBankAccounts'] == true) {
        final banks = await _db.collection('agent_bank_accounts').where('agentPhone', isEqualTo: phone).get();
        for (final d in banks.docs) batch.delete(d.reference);
      }
      if (options['resetSubscriptions'] == true) {
        batch.update(_db.collection('users').doc(phone), {
          'subPlan': '',
          'subPrice': 0,
          'subStatus': 'ملغي',
          'subExpiry': '',
        });
      }
      if (options['renameAccount'] == true && renameTo != null && renameTo.isNotEmpty) {
        batch.update(_db.collection('users').doc(phone), {'name': renameTo});
      }
      if (options['deleteAccount'] == true) {
        batch.delete(_db.collection('users').doc(phone));
      }
    }

    if (options['mergeRecords'] == true && mergeFrom != null && mergeTo != null) {
      final fromTxns = await _db.collection('transactions').where('fromPhone', isEqualTo: mergeFrom).get();
      for (final d in fromTxns.docs) {
        batch.update(d.reference, {'fromPhone': mergeTo});
      }
      final toTxns = await _db.collection('transactions').where('toPhone', isEqualTo: mergeFrom).get();
      for (final d in toTxns.docs) {
        batch.update(d.reference, {'toPhone': mergeTo});
      }
    }

    await batch.commit();

    _logAction(
      action: 'إعادة تهيئة متقدمة',
      details: 'نوع الهدف: $targetType, الخيارات: $options',
      severity: 'critical',
    );
  }

  // ---------- دوال خاصة بالوكيل (شبكات) ----------
  Future<List<Map<String, dynamic>>> getAgentNetworkNames() async {
    if (_auth?.activeUserPhone == null) return [];
    try {
      final snap = await _db
          .collection('networks')
          .where('agentPhone', isEqualTo: _auth!.activeUserPhone)
          .where('isActive', isEqualTo: true)
          .get();
      return snap.docs.map((doc) => {
        'networkId': doc.id,
        'networkName': doc['name'] ?? 'بدون اسم',
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRealAgentsForRecharge() async {
    try {
      final agentsSnap = await _db
          .collection('users')
          .where('role', isEqualTo: 'agent')
          .where('status', isEqualTo: 'نشط')
          .get();

      List<Map<String, dynamic>> realAgents = [];

      for (var doc in agentsSnap.docs) {
        final agent = doc.data();
        final phone = doc.id;

        final networksSnap = await _db
            .collection('networks')
            .where('agentPhone', isEqualTo: phone)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (networksSnap.docs.isEmpty) continue;

        final banksSnap = await _db
            .collection('agent_bank_accounts')
            .where('agentPhone', isEqualTo: phone)
            .where('status', isEqualTo: 'نشط')
            .limit(1)
            .get();

        if (banksSnap.docs.isEmpty) continue;

        realAgents.add({
          'phone': phone,
          'name': agent['name'] ?? '',
          'networkName': agent['networkName'] ?? '',
        });
      }

      return realAgents;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getActiveNetworksForRecharge() async {
    try {
      final agentsSnap = await _db
          .collection('users')
          .where('role', isEqualTo: 'agent')
          .where('status', isEqualTo: 'نشط')
          .get();

      List<Map<String, dynamic>> activeNetworks = [];

      for (var agentDoc in agentsSnap.docs) {
        final agentPhone = agentDoc.id;
        final agentData = agentDoc.data();

        final banksSnap = await _db
            .collection('agent_bank_accounts')
            .where('agentPhone', isEqualTo: agentPhone)
            .where('status', isEqualTo: 'نشط')
            .limit(1)
            .get();

        if (banksSnap.docs.isEmpty) continue;

        final networksSnap = await _db
            .collection('networks')
            .where('agentPhone', isEqualTo: agentPhone)
            .where('isActive', isEqualTo: true)
            .get();

        for (var netDoc in networksSnap.docs) {
          final netData = netDoc.data();
          activeNetworks.add({
            'networkId': netDoc.id,
            'networkName': netData['name'] ?? 'بدون اسم',
            'agentPhone': agentPhone,
            'agentName': agentData['name'] ?? agentPhone,
          });
        }
      }

      return activeNetworks;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAgentBankAccountsForUser(String agentPhone) async {
    final snap = await _db
        .collection('agent_bank_accounts')
        .where('agentPhone', isEqualTo: agentPhone)
        .where('status', isEqualTo: 'نشط')
        .orderBy('order')
        .get();
    return snap.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> getActiveBankAccountsForUserNetworks() async {
    final agentsSnap = await _db
        .collection('users')
        .where('role', isEqualTo: 'agent')
        .get();

    List<Map<String, dynamic>> accounts = [];

    for (var agentDoc in agentsSnap.docs) {
      final agentId = agentDoc.id;
      final bankAccSnap = await _db
          .collection('agent_bank_accounts')
          .where('agentPhone', isEqualTo: agentId)
          .where('status', isEqualTo: 'نشط')
          .get();

      for (var accDoc in bankAccSnap.docs) {
        final data = accDoc.data();
        accounts.add({
          'docId': accDoc.id,
          'agentId': agentId,
          'agentPhone': agentId,
          ...data,
        });
      }
    }

    return accounts;
  }

  // ---------- دوال تحويل API المتبقية ----------
  Future<void> requestWalletRecharge(String targetPhone, double amount) async {
    await submitSaaSRechargeRequest(
        quotaAmount: amount,
        feeAmount: 0.0,
        adminBankName: 'غير محدد',
        transferSource: 'طلب قديم',
        reference: 'N/A',
        base64Image: '');
  }

  Future<void> acceptRechargeRequest({
    required String requestId,
    required String agentPhone,
    required String agentName,
    required double amount,
  }) async {
    await adminAcceptSaaSRecharge(requestId, agentPhone, amount, 0.0);
  }

  Future<void> adminAcceptSaaSRecharge(String requestId, String agentPhone,
      double quotaAmount, double feeAmount) async {
    final api = ApiService(authToken: _auth?.authToken);
    await api.post('/api/accept-recharge', {
      'requestId': requestId,
      'agentPhone': agentPhone,
      'quotaAmount': quotaAmount,
    }, authenticate: true);
  }

  Future<void> rejectRechargeRequest(String requestId, String reason) async {
    try {
      final reqDoc =
          await _db.collection('recharge_requests').doc(requestId).get();
      if (reqDoc.exists) {
        final reqData = reqDoc.data() as Map<String, dynamic>;
        String userPhone = reqData['userPhone'];

        WriteBatch batch = _db.batch();
        batch.update(
            reqDoc.reference, {'status': 'مرفوض', 'rejectReason': reason});

        DocumentReference notifRef = _db.collection('notifications').doc();
        batch.set(notifRef, {
          'targetPhones': [userPhone],
          'title': 'تم رفض طلب الشحن ❌',
          'body': 'السبب: $reason',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'readBy': [],
        });

        await batch.commit();
      }
    } catch (e) {}
  }

  // ---------- دوال مساعدة (إرسال إشعار، تدقيق) ----------
  void _sendNotification({
    required List<String> targetPhones,
    required String title,
    required String body,
  }) async {
    await _db.collection('notifications').add({
      'targetPhones': targetPhones,
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'readBy': [],
    });
  }

  Future<void> _logAction({
    required String action,
    required String details,
    required String severity,
    String? targetPhone,
  }) async {
    if (_auth?.activeUserPhone == null) return;
    try {
      final userDoc = await _db.collection('users').doc(_auth!.activeUserPhone).get();
      final userData = userDoc.data() ?? {};
      final now = DateTime.now();
      final formattedDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      await _db.collection('audit_logs').add({
        'name': userData['name'] ?? 'غير معروف',
        'phone': _auth!.activeUserPhone,
        'role': userData['role'] ?? 'Unknown',
        'action': action,
        'details': details,
        'datetime': formattedDate,
        'timestamp': FieldValue.serverTimestamp(),
        'ip': 'Cloud System',
        'severity': severity,
        'targetPhone': targetPhone,
      });
    } catch (e) {
      debugPrint('خطأ في تسجيل الحدث: $e');
    }
  }

  Future<void> updateUserPin(String pin) async {
    if (_auth?.activeUserPhone == null) return;
    await _db.collection('users').doc(_auth!.activeUserPhone).update({'pin': pin});
    final index = _usersDatabase.indexWhere((u) => u['phone'] == _auth!.activeUserPhone);
    if (index != -1) {
      _usersDatabase[index]['pin'] = pin;
      notifyListeners();
    }
  }

  Future<void> setHoldAmount(double amount) async {
    if (_auth?.activeUserPhone == null) return;
    await _db.collection('users').doc(_auth!.activeUserPhone).update({
      'heldBalance': amount,
    });
  }

  Future<void> updateDangerLimit(String phone, double newLimit) async {
    await _db.collection('users').doc(phone).update({'dangerLimit': newLimit});
  }

  // ---------- الإجراءات الخاصة بالوكيل (حسابات بنكية) منقولة من النسخة الأولى ----------
  // (موجودة أعلاه)
}
