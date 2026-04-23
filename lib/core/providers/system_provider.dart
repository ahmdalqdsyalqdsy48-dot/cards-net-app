import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';

class SystemProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  double _adminMainBalance = 0.0;
  int _totalSystemCards = 0;
  String? _activeUserPhone;
  double _newsScrollSpeed = 40.0;

  String _currentUserRole = 'guest';
  Map<String, bool> _currentUserPermissions = {};

  bool _isMaintenanceMode = false;
  bool _isForcedUpdate = false;
  bool _showNewsBar = true;
  bool _isCurrencyAutoRounding = true;
  String _minimumChargeLimit = '1000';
  String _termsAndConditions = '';
  String _supportNumbers = '';

  String _appName = 'كروت نت';
  String _appLogoUrl = '';
  int _loginBgColor = 0xFFFFFFFF;
  List<String> _loginCarouselImages = [];
  String _loginWelcomeMessage = 'مرحباً بك في نظام كروت نت';
  int _carouselIntervalSeconds = 5;
  String _marqueeDirection = 'rtl';
  int _marqueeTextColor = 0xFFFFFFFF;
  int _marqueeBgColor = 0x4DFFC107;
  double _marqueeFontSize = 14.0;

  String _appNameAlign = 'center';
  String _appNameFont = 'Cairo';
  int _appNameColor = 0xFF2196F3;

  List<String> _agentUniversalHiddenSections = [];
  List<Map<String, dynamic>> _agentBanners = [];
  Map<String, dynamic> _agentEmergencyAlert = {
    'isActive': false,
    'text': '',
    'targetType': 'all',
    'targetPhones': []
  };
  bool _hideProfitEnabled = false;
  bool _leaderboardEnabled = false;
  bool _forceAgentTheme = false;

  List<String> _userUniversalHiddenSections = [];
  bool _guestModeEnabled = false;
  bool _kycRequired = false;
  Map<String, dynamic> _userPromoPopup = {
    'isActive': false,
    'imageUrl': '',
    'targetType': 'all',
    'targetPhones': []
  };
  Map<String, dynamic> _socialLinks = {
    'whatsapp': '',
    'facebook': '',
    'telegram': ''
  };
  bool _loyaltySystemEnabled = false;

  List<Map<String, dynamic>> _targetedNews = [];
  List<Map<String, dynamic>> _usersDatabase = [];
  List<String> _announcements = [];
  List<Map<String, dynamic>> _rechargeRequests = [];
  List<Map<String, dynamic>> _transactionsLedger = [];
  List<Map<String, dynamic>> _auditLogs = [];

  bool _isAutoBackupEnabled = true;
  String _backupFrequency = 'يومياً';
  String _backupTime = '04:00';
  String _emergencyEmail = '';
  bool _isDriveLinked = false;
  bool _isDropboxLinked = false;
  List<Map<String, dynamic>> _backupsList = [];
  List<Map<String, dynamic>> _bankAccounts = [];
  List<Map<String, dynamic>> _coupons = [];

  List<Map<String, dynamic>> _salesList = [];
  List<Map<String, dynamic>> _supportTickets = [];
  int _smsBalance = 0;
  DateTimeRange? _dashboardDateRange;

  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription? _notificationSubscription;

  List<Map<String, dynamic>> _myAgentBankAccounts = [];
  StreamSubscription? _agentBankSubscription;

  SystemProvider() {
    _initDatabaseSync();
  }

  void _initDatabaseSync() {
    _db.collection('system').doc('main_info').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        _adminMainBalance = (data['adminMainBalance'] ?? 0.0).toDouble();
        _totalSystemCards = data['totalSystemCards'] ?? 0;
        _announcements = List<String>.from(data['announcements'] ?? []);
        _newsScrollSpeed = (data['newsScrollSpeed'] ?? 40.0).toDouble();

        _isMaintenanceMode = data['isMaintenanceMode'] ?? false;
        _isForcedUpdate = data['isForcedUpdate'] ?? false;
        _showNewsBar = data['showNewsBar'] ?? true;
        _isCurrencyAutoRounding = data['isCurrencyAutoRounding'] ?? true;
        _minimumChargeLimit = data['minimumChargeLimit'] ?? '1000';
        _termsAndConditions = data['termsAndConditions'] ?? '';
        _supportNumbers = data['supportNumbers'] ?? '';

        _appName = data['appName'] ?? 'كروت نت';
        _appLogoUrl = data['appLogoUrl'] ?? '';
        _loginBgColor = data['loginBgColor'] ?? 0xFFFFFFFF;
        _loginCarouselImages =
            List<String>.from(data['loginCarouselImages'] ?? []);
        _loginWelcomeMessage =
            data['loginWelcomeMessage'] ?? 'مرحباً بك في نظام $_appName';
        _carouselIntervalSeconds = data['carouselIntervalSeconds'] ?? 5;
        _marqueeDirection = data['marqueeDirection'] ?? 'rtl';
        _marqueeTextColor = data['marqueeTextColor'] ?? 0xFFFFFFFF;
        _marqueeBgColor = data['marqueeBgColor'] ?? 0x4DFFC107;
        _marqueeFontSize = (data['marqueeFontSize'] ?? 14.0).toDouble();

        _appNameAlign = data['appNameAlign'] ?? 'center';
        _appNameFont = data['appNameFont'] ?? 'Cairo';
        _appNameColor = data['appNameColor'] ?? 0xFF2196F3;

        _agentUniversalHiddenSections =
            List<String>.from(data['agentUniversalHiddenSections'] ?? []);
        _userUniversalHiddenSections =
            List<String>.from(data['userUniversalHiddenSections'] ?? []);
        _hideProfitEnabled = data['hideProfitEnabled'] ?? false;
        _leaderboardEnabled = data['leaderboardEnabled'] ?? false;
        _forceAgentTheme = data['forceAgentTheme'] ?? false;

        _guestModeEnabled = data['guestModeEnabled'] ?? false;
        _kycRequired = data['kycRequired'] ?? false;
        _loyaltySystemEnabled = data['loyaltySystemEnabled'] ?? false;

        if (data['socialLinks'] != null) {
          _socialLinks = Map<String, dynamic>.from(data['socialLinks']);
        }
        if (data['agentEmergencyAlert'] != null) {
          _agentEmergencyAlert =
              Map<String, dynamic>.from(data['agentEmergencyAlert']);
        }
        if (data['userPromoPopup'] != null) {
          _userPromoPopup = Map<String, dynamic>.from(data['userPromoPopup']);
        }
        if (data['agentBanners'] != null) {
          _agentBanners = List<Map<String, dynamic>>.from(data['agentBanners']);
        }
        if (data['targetedNews'] != null) {
          _targetedNews = List<Map<String, dynamic>>.from(data['targetedNews']);
        }

        _smsBalance = data['smsBalance'] ?? 0;

        notifyListeners();
      }
    });

    _db.collection('users').snapshots().listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        _usersDatabase = snapshot.docs.map((doc) => doc.data()).toList();
        _runAutoRadar(_usersDatabase);
        notifyListeners();
      }
    });

    _db
        .collection('recharge_requests')
        .where('status', isEqualTo: 'قيد الانتظار')
        .snapshots()
        .listen((snapshot) {
      _rechargeRequests =
          snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    _db
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _transactionsLedger =
          snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    _db
        .collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      _auditLogs =
          snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    _db
        .collection('system')
        .doc('backup_settings')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        _isAutoBackupEnabled = data['isAutoBackupEnabled'] ?? true;
        _backupFrequency = data['backupFrequency'] ?? 'يومياً';
        String rawTime = data['backupTime'] ?? '04:00';
        _backupTime = rawTime.contains(' ') ? '04:00' : rawTime;
        _emergencyEmail = data['emergencyEmail'] ?? '';
        _isDriveLinked = data['isDriveLinked'] ?? false;
        _isDropboxLinked = data['isDropboxLinked'] ?? false;
        notifyListeners();
      }
    });

    _db
        .collection('backups')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _backupsList =
          snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    _db
        .collection('bank_accounts')
        .orderBy('order')
        .snapshots()
        .listen((snapshot) {
      _bankAccounts =
          snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    _db
        .collection('coupons')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _coupons =
          snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    _db.collection('support_tickets').snapshots().listen((snapshot) {
      _supportTickets =
          snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    _db.collection('sales').snapshots().listen((snapshot) {
      _salesList =
          snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });
  }

  void _listenToUserNotifications() {
    if (_activeUserPhone == null) return;
    _notificationSubscription?.cancel();
    _agentBankSubscription?.cancel();

    _notificationSubscription = _db
        .collection('notifications')
        .where('targetPhones', arrayContainsAny: [
          _activeUserPhone,
          'all',
          _currentUserRole == 'agent' ? 'all_agents' : 'all_staff'
        ])
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots()
        .listen((snapshot) {
      _notifications = snapshot.docs.map((doc) {
        final data = doc.data();
        List readBy = data['readBy'] ?? [];
        bool isRead = readBy.contains(_activeUserPhone) || data['isRead'] == true;
        return {'docId': doc.id, ...data, 'isReadLocal': isRead};
      }).toList();
      notifyListeners();
    });

    if (_currentUserRole == 'agent' || _currentUserRole == 'super_admin') {
      _agentBankSubscription = _db
          .collection('agent_bank_accounts')
          .where('agentPhone', isEqualTo: _activeUserPhone)
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

  void clearAllData() {
    _activeUserPhone = null;
    _currentUserRole = 'guest';
    _currentUserPermissions = {};
    _notifications = [];
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _agentBankSubscription?.cancel();
    _agentBankSubscription = null;
    _myAgentBankAccounts = [];
    notifyListeners();
  }

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

  Future<void> loadUserData(String phone) async {
    try {
      final doc = await _db.collection('users').doc(phone).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        int index = _usersDatabase.indexWhere((u) => u['phone'] == phone);
        if (index != -1) {
          _usersDatabase[index] = data;
        } else {
          _usersDatabase.add(data);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('خطأ في المزامنة اليدوية: $e');
    }
  }

  double get adminMainBalance => _adminMainBalance;
  int get totalSystemCards => _totalSystemCards;
  List<String> get announcements => _announcements;
  double get newsScrollSpeed => _newsScrollSpeed;

  bool get isMaintenanceMode => _isMaintenanceMode;
  bool get isForcedUpdate => _isForcedUpdate;
  bool get showNewsBar => _showNewsBar;
  bool get isCurrencyAutoRounding => _isCurrencyAutoRounding;
  String get minimumChargeLimit => _minimumChargeLimit;
  String get termsAndConditions => _termsAndConditions;
  String get supportNumbers => _supportNumbers;

  String get appName => _appName;
  String get appLogoUrl => _appLogoUrl;
  int get loginBgColor => _loginBgColor;
  List<String> get loginCarouselImages => _loginCarouselImages;
  String get loginWelcomeMessage => _loginWelcomeMessage;
  int get carouselIntervalSeconds => _carouselIntervalSeconds;
  String get marqueeDirection => _marqueeDirection;
  int get marqueeTextColor => _marqueeTextColor;
  int get marqueeBgColor => _marqueeBgColor;
  double get marqueeFontSize => _marqueeFontSize;

  String get appNameAlign => _appNameAlign;
  String get appNameFont => _appNameFont;
  int get appNameColor => _appNameColor;

  List<String> get agentUniversalHiddenSections => _agentUniversalHiddenSections;
  List<Map<String, dynamic>> get agentBanners => _agentBanners;
  Map<String, dynamic> get agentEmergencyAlert => _agentEmergencyAlert;
  bool get hideProfitEnabled => _hideProfitEnabled;
  bool get leaderboardEnabled => _leaderboardEnabled;
  bool get forceAgentTheme => _forceAgentTheme;

  List<String> get userUniversalHiddenSections => _userUniversalHiddenSections;
  bool get guestModeEnabled => _guestModeEnabled;
  bool get kycRequired => _kycRequired;
  Map<String, dynamic> get userPromoPopup => _userPromoPopup;
  Map<String, dynamic> get socialLinks => _socialLinks;
  bool get loyaltySystemEnabled => _loyaltySystemEnabled;

  List<Map<String, dynamic>> get targetedNews => _targetedNews;

  List<Map<String, dynamic>> get agentsList =>
      _usersDatabase.where((user) => user['role'] == 'agent').toList();
  List<Map<String, dynamic>> get usersList => _usersDatabase
      .where((user) => user['role'] == 'user' || user['role'] == 'pos')
      .toList();
  List<Map<String, dynamic>> get pendingRechargeRequests => _rechargeRequests;
  List<Map<String, dynamic>> get transactionsLedger => _transactionsLedger;
  List<Map<String, dynamic>> get auditLogs => _auditLogs;
  bool get isAutoBackupEnabled => _isAutoBackupEnabled;
  String get backupFrequency => _backupFrequency;
  String get backupTime => _backupTime;
  String get emergencyEmail => _emergencyEmail;
  bool get isDriveLinked => _isDriveLinked;
  bool get isDropboxLinked => _isDropboxLinked;
  List<Map<String, dynamic>> get backupsList => _backupsList;
  List<Map<String, dynamic>> get bankAccounts => _bankAccounts;
  List<Map<String, dynamic>> get coupons => _coupons;

  List<Map<String, dynamic>> get myAgentBankAccounts => _myAgentBankAccounts;

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadNotificationsCount =>
      _notifications.where((n) => n['isReadLocal'] == false).length;

  String get currentUserRole => _currentUserRole;

  void setDashboardDateRange(DateTimeRange? range) {
    _dashboardDateRange = range;
    notifyListeners();
  }

  DateTimeRange? get dashboardDateRange => _dashboardDateRange;
  int get smsBalance => _smsBalance;

  String get currentUserNetwork {
    if (_activeUserPhone == null) return 'غير محدد';
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _activeUserPhone,
        orElse: () => {'networkName': 'غير محدد'});
    return user['networkName'] ?? 'غير محدد';
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

  String get currentUserName {
    if (_activeUserPhone == null) return '';
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _activeUserPhone,
        orElse: () => {'name': ''});
    return user['name'] ?? '';
  }

  String get currentUserPhone => _activeUserPhone ?? '';

  bool hasPermission(String permissionName) {
    if (_currentUserRole == 'super_admin') return true;
    return _currentUserPermissions[permissionName] ?? false;
  }

  String get currentUserPin {
    if (_activeUserPhone == null) return '';
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _activeUserPhone,
        orElse: () => {'pin': '123456'});
    return user['pin'] ?? '123456';
  }

  double get currentUserBalance {
    if (_activeUserPhone == null) return 0.0;
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _activeUserPhone,
        orElse: () => {'balance': 0.0});
    if (user['role'] == 'user' || user['role'] == 'pos') {
      Map<String, dynamic> wallets = user['wallets'] ?? {};
      return wallets.values.fold(0.0, (sum, val) => sum + (val as num).toDouble());
    }
    return (user['balance'] ?? 0.0).toDouble();
  }

  double getWalletBalance(String agentPhone) {
    if (_activeUserPhone == null) return 0.0;
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _activeUserPhone,
        orElse: () => {'wallets': {}});
    Map<String, dynamic> wallets = user['wallets'] ?? {};
    return (wallets[agentPhone] ?? 0.0).toDouble();
  }

  List<Map<String, dynamic>> get userPurchasedCards {
    if (_activeUserPhone == null) return [];
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _activeUserPhone,
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

  List<String> get currentUserHiddenSections {
    if (_activeUserPhone == null) return [];
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _activeUserPhone,
        orElse: () => {'role': 'user', 'hiddenSections': <String>[]});
    List<String> personalHidden = List<String>.from(user['hiddenSections'] ?? []);
    List<String> universalHidden = user['role'] == 'agent'
        ? _agentUniversalHiddenSections
        : _userUniversalHiddenSections;
    return {...personalHidden, ...universalHidden}.toList();
  }

  bool get isBiometricCurrentlyEnabled {
    if (_activeUserPhone == null) return false;
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _activeUserPhone,
        orElse: () => {'isBiometricEnabled': false});
    return user['isBiometricEnabled'] ?? false;
  }

  Future<void> logAction(
      {required String action,
      required String details,
      required String severity,
      String? targetPhone}) async {
    if (_activeUserPhone == null) return;
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _activeUserPhone,
        orElse: () => {'name': 'غير معروف', 'role': 'Unknown'});
    final now = DateTime.now();
    final formattedDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    try {
      await _db.collection('audit_logs').add({
        'name': user['name'] ?? 'غير معروف',
        'phone': _activeUserPhone,
        'role': user['role'] ?? 'Unknown',
        'action': action,
        'details': details,
        'datetime': formattedDate,
        'timestamp': FieldValue.serverTimestamp(),
        'ip': 'Cloud System',
        'severity': severity,
        'targetPhone': targetPhone,
      });
    } catch (e) {}
  }

  Future<void> updateGlobalAppName(String newName) async {
    await _db
        .collection('system')
        .doc('main_info')
        .update({'appName': newName});
    _appName = newName;
    notifyListeners();
    logAction(
        action: 'تغيير هوية النظام',
        details: 'تم تغيير اسم النظام إلى: $newName',
        severity: 'critical');
  }

  Future<void> updateAdvancedLoginSettings(
      {required String name,
      required String logoUrl,
      required int bgColor,
      required List<String> images,
      required String welcomeMsg,
      required int intervalSeconds,
      required String marqueeDir,
      required int marqueeTextCol,
      required int marqueeBgCol,
      required String appNameAlign,
      required String appNameFont,
      required int appNameColor}) async {
    _appName = name;
    _appLogoUrl = logoUrl;
    _loginBgColor = bgColor;
    _loginCarouselImages = images;
    _loginWelcomeMessage = welcomeMsg;
    _carouselIntervalSeconds = intervalSeconds;
    _marqueeDirection = marqueeDir;
    _marqueeTextColor = marqueeTextCol;
    _marqueeBgColor = marqueeBgCol;
    _appNameAlign = appNameAlign;
    _appNameFont = appNameFont;
    _appNameColor = appNameColor;
    notifyListeners();

    await _db.collection('system').doc('main_info').update({
      'appName': name,
      'appLogoUrl': logoUrl,
      'loginBgColor': bgColor,
      'loginCarouselImages': images,
      'loginWelcomeMessage': welcomeMsg,
      'carouselIntervalSeconds': intervalSeconds,
      'marqueeDirection': marqueeDir,
      'marqueeTextColor': marqueeTextCol,
      'marqueeBgColor': marqueeBgCol,
      'appNameAlign': appNameAlign,
      'appNameFont': appNameFont,
      'appNameColor': appNameColor,
    });
    logAction(
        action: 'تحديث بوابة الدخول',
        details: 'تحديث المظهر واسم التطبيق',
        severity: 'critical');
  }

  Future<void> updateAgentPortalSettings(
      {required bool hideProfit,
      required bool leaderboard,
      required bool forceTheme,
      required List<String> universalHidden}) async {
    _hideProfitEnabled = hideProfit;
    _leaderboardEnabled = leaderboard;
    _forceAgentTheme = forceTheme;
    _agentUniversalHiddenSections = universalHidden;
    notifyListeners();

    await _db.collection('system').doc('main_info').update({
      'hideProfitEnabled': hideProfit,
      'leaderboardEnabled': leaderboard,
      'forceAgentTheme': forceTheme,
      'agentUniversalHiddenSections': universalHidden
    });
    logAction(
        action: 'تحديث بوابة الوكلاء',
        details: 'تم تعديل سياسات لوحة الوكلاء',
        severity: 'medium');
  }

  Future<void> updateUserPortalSettings(
      {required bool guestMode,
      required bool kyc,
      required bool loyalty,
      required List<String> universalHidden,
      required Map<String, dynamic> social}) async {
    _guestModeEnabled = guestMode;
    _kycRequired = kyc;
    _loyaltySystemEnabled = loyalty;
    _userUniversalHiddenSections = universalHidden;
    _socialLinks = social;
    notifyListeners();

    await _db.collection('system').doc('main_info').update({
      'guestModeEnabled': guestMode,
      'kycRequired': kyc,
      'loyaltySystemEnabled': loyalty,
      'userUniversalHiddenSections': universalHidden,
      'socialLinks': social
    });
    logAction(
        action: 'تحديث بوابة المستخدمين',
        details: 'تم تعديل سياسات لوحة المستخدمين',
        severity: 'medium');
  }

  Future<void> toggleSectionForSpecificUsers(
      {required String sectionId,
      required List<String> targetPhones,
      required bool hide}) async {
    WriteBatch batch = _db.batch();
    for (String phone in targetPhones) {
      DocumentReference ref = _db.collection('users').doc(phone);
      if (hide) {
        batch.update(ref, {'hiddenSections': FieldValue.arrayUnion([sectionId])});
      } else {
        batch
            .update(ref, {'hiddenSections': FieldValue.arrayRemove([sectionId])});
      }
    }
    await batch.commit();
    logAction(
        action: 'استهداف الأقسام',
        details:
            'تم ${hide ? "إخفاء" : "إظهار"} قسم $sectionId لعدد ${targetPhones.length} مستخدم',
        severity: 'critical');
  }

  Future<void> postTargetedBanner(
      {required String imageUrl,
      required String targetType,
      required List<String> targetPhones}) async {
    final newBanner = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'imageUrl': imageUrl,
      'targetType': targetType,
      'targetPhones': targetPhones
    };
    await _db.collection('system').doc('main_info').update({
      'agentBanners': FieldValue.arrayUnion([newBanner])
    });
    logAction(
        action: 'إعلان موجه',
        details: 'تم نشر بانر إعلاني بنظام الاستهداف: $targetType',
        severity: 'normal');
  }

  Future<void> setEmergencyAlert(
      {required bool isActive,
      required String text,
      required String targetType,
      required List<String> targetPhones}) async {
    await _db.collection('system').doc('main_info').update({
      'agentEmergencyAlert': {
        'isActive': isActive,
        'text': text,
        'targetType': targetType,
        'targetPhones': targetPhones
      }
    });
    logAction(
        action: 'تنبيه طوارئ',
        details: 'حالة الطوارئ: $isActive | الاستهداف: $targetType',
        severity: 'critical');
  }

  Future<void> updateSystemStatusSettings(
      {required bool maintenance,
      required bool forcedUpdate,
      required bool showNews}) async {
    _isMaintenanceMode = maintenance;
    _isForcedUpdate = forcedUpdate;
    _showNewsBar = showNews;
    notifyListeners();

    await _db.collection('system').doc('main_info').update({
      'isMaintenanceMode': maintenance,
      'isForcedUpdate': forcedUpdate,
      'showNewsBar': showNews
    });
  }

  Future<void> updatePoliciesSettings(
      {required String terms,
      required String support,
      required String minCharge,
      required bool autoRounding}) async {
    _termsAndConditions = terms;
    _supportNumbers = support;
    _minimumChargeLimit = minCharge;
    _isCurrencyAutoRounding = autoRounding;
    notifyListeners();

    await _db.collection('system').doc('main_info').update({
      'termsAndConditions': terms,
      'supportNumbers': support,
      'minimumChargeLimit': minCharge,
      'isCurrencyAutoRounding': autoRounding
    });
  }

  Future<void> addTargetedNews(
      {required String text, required String targetRole}) async {
    final newNews = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'text': text,
      'target': targetRole
    };
    await _db.collection('system').doc('main_info').update({
      'targetedNews': FieldValue.arrayUnion([newNews])
    });
  }

  Future<void> removeTargetedNews(Map<String, dynamic> newsItem) async {
    await _db.collection('system').doc('main_info').update({
      'targetedNews': FieldValue.arrayRemove([newsItem])
    });
  }

  Future<bool> changeUserName(String newName) async {
    if (_activeUserPhone == null) return false;
    try {
      await _db
          .collection('users')
          .doc(_activeUserPhone)
          .update({'name': newName});
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> changeUserPin(String oldPin, String newPin) async {
    if (_activeUserPhone == null) return false;
    if (currentUserPin == oldPin) {
      await _db
          .collection('users')
          .doc(_activeUserPhone)
          .update({'pin': newPin});
      return true;
    }
    return false;
  }

  Future<void> updateNewsSpeed(double newSpeed) async {
    _newsScrollSpeed = newSpeed;
    notifyListeners();
    await _db
        .collection('system')
        .doc('main_info')
        .update({'newsScrollSpeed': newSpeed});
  }

  Future<bool> checkUserExists(String phone) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(phone)
          .get()
          .timeout(const Duration(seconds: 5));
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> loginUser(String phone, String password) async {
    clearAllData();

    if (phone == '774578241' && password == '75486958aaa') {
      final superAdminData = {
        'id': 'SUPER_ADMIN_01',
        'name': 'مالك النظام',
        'phone': '774578241',
        'password': '75486958aaa',
        'role': 'super_admin',
        'balance': 0.0,
        'dangerLimit': 0.0,
        'status': 'نشط',
        'networkName': 'المركز الرئيسي',
        'pin': '123456',
        'purchasedCards': [],
        'isBiometricEnabled': false,
        'hiddenSections': [],
      };
      try {
        _db
            .collection('users')
            .doc('774578241')
            .set(superAdminData, SetOptions(merge: true));
      } catch (e) {}
      _activeUserPhone = phone;
      _currentUserRole = 'super_admin';
      _listenToUserNotifications();
      notifyListeners();
      return superAdminData;
    }
    try {
      final doc = await _db
          .collection('users')
          .doc(phone)
          .get()
          .timeout(const Duration(seconds: 7));
      if (doc.exists) {
        final userData = doc.data() as Map<String, dynamic>;
        if (userData['password'] == password) {
          _activeUserPhone = phone;
          _currentUserRole = userData['role'] ?? 'user';

          if (_currentUserRole == 'staff' && userData['permissions'] != null) {
            _currentUserPermissions =
                Map<String, bool>.from(userData['permissions']);
          }

          _listenToUserNotifications();
          notifyListeners();
          logAction(
              action: 'تسجيل دخول',
              details: 'تم تسجيل الدخول بواسطة: ${userData['name']}',
              severity: 'normal');
          return userData;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> registerNewUser(
      {required String name,
      required String phone,
      required String password,
      required String role}) async {
    try {
      await _db.collection('users').doc(phone).set({
        'id': 'USER_${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'phone': phone,
        'password': password,
        'role': role,
        'balance': 0.0,
        'wallets': {},
        'networkName': 'غير محدد',
        'dangerLimit': 0.0,
        'status': 'نشط',
        'purchasedCards': [],
        'pin': '123456',
        'isBiometricEnabled': false,
        'createdAt': FieldValue.serverTimestamp(),
        'hiddenSections': [],
      });
      _activeUserPhone = phone;
      _currentUserRole = role;
      _listenToUserNotifications();
      notifyListeners();
    } catch (e) {
      throw 'فشل تسجيل المستخدم: $e';
    }
  }

  Future<void> addAgent(
      {required String name,
      required String phone,
      required String password,
      String? networkName,
      String? profitMargin,
      String? location}) async {
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
          'balance': 0.0,
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
        });
        logAction(
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

  Future<void> updateAgentDetails(
      {required String oldPhone,
      required String newPhone,
      required String newName,
      required String newNetwork,
      required String newLocation,
      required String newProfit,
      required String newPassword}) async {
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

  Future<String> executeRealPurchase(
      double price, String cardTitle, String agentPhone) async {
    if (_activeUserPhone == null) throw 'يرجى تسجيل الدخول أولاً لإتمام الشراء.';

    final userRef = _db.collection('users').doc(_activeUserPhone);

    final availableCardsQuery = await _db
        .collection('cards')
        .where('agentPhone', isEqualTo: agentPhone)
        .where('cardTitle', isEqualTo: cardTitle)
        .where('status', isEqualTo: 'متاح')
        .limit(1)
        .get();

    if (availableCardsQuery.docs.isEmpty) {
      throw 'عذراً، لقد نفدت الكمية الحقيقية من هذا الكرت! يرجى المحاولة لاحقاً.';
    }

    final cardDoc = availableCardsQuery.docs.first;
    final cardData = cardDoc.data() as Map<String, dynamic>;
    final String actualPin = cardData['pin'] ?? 'رقم غير معروف';
    final String cardId = cardDoc.id;

    await _db.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) throw 'حدث خطأ: حساب المستخدم غير موجود.';

      final userData = userSnapshot.data() as Map<String, dynamic>;
      Map<String, dynamic> wallets = userData['wallets'] ?? {};
      double currentWalletBalance = (wallets[agentPhone] ?? 0.0).toDouble();

      double creditLimit = 0.0;
      if (userData['role'] == 'pos') {
        Map<String, dynamic> relations = userData['agent_relations'] ?? {};
        Map<String, dynamic> myRel = relations[agentPhone] ?? {};
        creditLimit = (myRel['creditLimit'] ?? 0.0).toDouble();
      }

      if ((currentWalletBalance + creditLimit) < price) {
        throw 'الرصيد أو الحد الائتماني المسموح لا يكفي لإتمام العملية.';
      }

      transaction.update(userRef, {
        'wallets.$agentPhone': FieldValue.increment(-price),
      });

      transaction.update(_db.collection('cards').doc(cardId), {
        'status': 'مباع',
        'buyerPhone': _activeUserPhone,
        'soldAt': FieldValue.serverTimestamp(),
      });

      final Map<String, dynamic> purchaseInvoice = {
        'title': cardTitle,
        'pin': actualPin,
        'price': price,
        'agentPhone': agentPhone,
        'date': DateTime.now().toIso8601String(),
      };

      transaction.update(userRef, {
        'purchasedCards': FieldValue.arrayUnion([purchaseInvoice])
      });

      transaction.update(_db.collection('system').doc('main_info'), {
        'totalSystemCards': FieldValue.increment(-1)
      });

      DocumentReference txnRef = _db.collection('transactions').doc();
      transaction.set(txnRef, {
        'fromPhone': _activeUserPhone,
        'toPhone': agentPhone,
        'agentPhone': agentPhone,
        'agentName': currentUserName,
        'targetName': userData['name'] ?? 'زبون',
        'networkName': userData['networkName'] ?? 'غير محدد',
        'amount': price,
        'fee': 0.0,
        'paymentMethod': 'خصم من المحفظة',
        'type': 'sale',
        'title': 'بيع كرت: $cardTitle لـ ${userData['name'] ?? 'زبون'}',
        'reference': 'SAL-$cardId',
        'timestamp': FieldValue.serverTimestamp()
      });
    });

    return actualPin;
  }

  Future<void> upgradeUserToPos({
    required String posPhone,
    required String storeName,
    required String location,
    required double creditLimit,
    required String commission,
    required List<String> allowedCategories,
  }) async {
    if (_activeUserPhone == null) return;
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
        'pos_agents': FieldValue.arrayUnion([_activeUserPhone]),
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
            'pos_agents': FieldValue.arrayUnion([_activeUserPhone]),
            'status': 'نشط',
          },
          SetOptions(merge: true));

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
  }) async {
    if (_activeUserPhone == null) return;
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

      await batch.commit();
    } catch (e) {
      throw 'فشل التعديل: $e';
    }
  }

  Future<void> fundSubAgent(String posPhone, double amount) async {
    if (_activeUserPhone == null) return;

    final agentDoc = await _db.collection('users').doc(_activeUserPhone).get();
    final agentData = agentDoc.data() as Map<String, dynamic>? ?? {};
    if ((agentData['balance'] ?? 0.0) < amount) {
      throw 'رصيد الحصة غير كافٍ لإتمام التحويل.';
    }

    final posDoc = await _db.collection('users').doc(posPhone).get();
    final posData = posDoc.data() as Map<String, dynamic>? ?? {};

    WriteBatch batch = _db.batch();

    batch.update(agentDoc.reference, {'balance': FieldValue.increment(-amount)});
    batch.update(_db.collection('users').doc(posPhone),
        {'wallets.$_activeUserPhone': FieldValue.increment(amount)});

    batch.set(_db.collection('transactions').doc(), {
      'fromPhone': _activeUserPhone,
      'toPhone': posPhone,
      'agentPhone': _activeUserPhone,
      'agentName': currentUserName,
      'targetName': posData['name'] ?? 'نقطة بيع',
      'networkName': posData['networkName'] ?? 'غير محدد',
      'amount': amount,
      'fee': 0.0,
      'type': 'transfer',
      'paymentMethod': 'آجل (من حصة الوكيل)',
      'title': 'تغذية محفظة نقطة البيع: ${posData['name'] ?? ''}',
      'reference': 'FND-${DateTime.now().millisecondsSinceEpoch}',
      'timestamp': FieldValue.serverTimestamp()
    });

    batch.set(_db.collection('notifications').doc(), {
      'targetPhones': [posPhone],
      'title': 'تغذية رصيد 💰',
      'body': 'تم تحويل $amount ريال لمحفظتك من الوكيل $currentUserName.',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'readBy': [],
    });

    await batch.commit();
  }

  Future<void> receivePosPayment(
      String posPhone, double amount, String note) async {
    if (_activeUserPhone == null) return;
    try {
      final posDoc = await _db.collection('users').doc(posPhone).get();
      final posData = posDoc.data() as Map<String, dynamic>? ?? {};

      WriteBatch batch = _db.batch();

      batch.update(_db.collection('users').doc(posPhone),
          {'wallets.$_activeUserPhone': FieldValue.increment(amount)});

      batch.set(_db.collection('transactions').doc(), {
        'fromPhone': posPhone,
        'toPhone': _activeUserPhone,
        'agentPhone': _activeUserPhone,
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

  // الدوال المعبرية
  Future<void> requestWalletRecharge(String targetPhone, double amount) async {
    await submitSaaSRechargeRequest(
        quotaAmount: amount,
        feeAmount: 0.0,
        adminBankName: 'غير محدد',
        transferSource: 'طلب قديم',
        reference: 'N/A',
        base64Image: '');
  }

  Future<void> acceptRechargeRequest(
      {required String requestId,
      required String agentPhone,
      required String agentName,
      required double amount}) async {
    await adminAcceptSaaSRecharge(requestId, agentPhone, amount, 0.0);
  }

  Future<void> agentAcceptUserRecharge(
      String requestId, String requesterPhone, double amount) async {
    if (_activeUserPhone == null) return;

    final myDoc = await _db.collection('users').doc(_activeUserPhone).get();
    final myData = myDoc.data() as Map<String, dynamic>? ?? {};
    if ((myData['balance'] ?? 0.0) < amount) {
      throw 'رصيدك لا يكفي! قم بتغذية رصيدك أولاً لتتمكن من إعطاء رصيد للآخرين.';
    }

    final requesterDoc =
        await _db.collection('users').doc(requesterPhone).get();
    final requesterData = requesterDoc.data() as Map<String, dynamic>? ?? {};

    WriteBatch batch = _db.batch();

    batch.update(
        _db.collection('user_recharges').doc(requestId), {'status': 'مقبول'});
    batch.update(myDoc.reference, {'balance': FieldValue.increment(-amount)});

    batch.update(requesterDoc.reference,
        {'wallets.$_activeUserPhone': FieldValue.increment(amount)});

    batch.set(_db.collection('transactions').doc(), {
      'fromPhone': _activeUserPhone,
      'toPhone': requesterPhone,
      'agentPhone': _activeUserPhone,
      'agentName': currentUserName,
      'targetName': requesterData['name'] ?? 'مستخدم',
      'networkName': requesterData['networkName'] ?? 'غير محدد',
      'amount': amount,
      'type': 'transfer',
      'paymentMethod': 'آجل (من حصة الوكيل)',
      'title': 'موافقة على طلب شحن من ${requesterData['name'] ?? 'مستخدم'}',
      'reference': 'RCH-$requestId',
      'timestamp': FieldValue.serverTimestamp()
    });

    DocumentReference notifRef = _db.collection('notifications').doc();
    batch.set(notifRef, {
      'targetPhones': [requesterPhone],
      'title': 'تم شحن محفظتك 🎉',
      'body': 'تمت الموافقة وإضافة $amount ريال لمحفظتك من $currentUserName.',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'readBy': [],
    });

    await batch.commit();
  }

  Future<void> submitSaaSRechargeRequest({
    required double quotaAmount,
    required double feeAmount,
    required String adminBankName,
    required String transferSource,
    required String reference,
    required String base64Image,
  }) async {
    if (_activeUserPhone == null) throw 'يرجى تسجيل الدخول.';

    await _db.collection('recharge_requests').add({
      'userPhone': _activeUserPhone,
      'userName': currentUserName,
      'networkName': currentUserNetwork,
      'targetPhone': '774578241',
      'amount': quotaAmount,
      'fee': feeAmount,
      'bankName': adminBankName,
      'transferSource': transferSource,
      'reference': reference,
      'hasReceipt': true,
      'receiptBase64': base64Image,
      'status': 'قيد الانتظار',
      'type': 'saas_quota',
      'timestamp': FieldValue.serverTimestamp(),
    });

    _sendNotification(
        targetPhones: ['774578241'],
        title: 'طلب شحن حصة جديد 🚀',
        body:
            'الوكيل $currentUserName يطلب حصة بقيمة $quotaAmount (الرسوم المودعة: $feeAmount).');
  }

  Future<void> adminAcceptSaaSRecharge(String requestId, String agentPhone,
      double quotaAmount, double feeAmount) async {
    try {
      WriteBatch batch = _db.batch();
      DocumentReference agentRef = _db.collection('users').doc(agentPhone);

      batch.update(agentRef, {'balance': FieldValue.increment(quotaAmount)});
      batch.update(_db.collection('recharge_requests').doc(requestId),
          {'status': 'مقبول'});

      final agentDoc = await _db.collection('users').doc(agentPhone).get();
      final agentData = agentDoc.data() as Map<String, dynamic>? ?? {};

      DocumentReference transactionRef = _db.collection('transactions').doc();
      batch.set(transactionRef, {
        'fromPhone': '774578241',
        'toPhone': agentPhone,
        'agentPhone': agentPhone,
        'agentName': agentData['name'] ?? 'وكيل',
        'targetName': 'المركز الرئيسي ($_appName)',
        'networkName': 'النظام',
        'type': 'deposit',
        'paymentMethod': 'حوالة بنكية',
        'title': 'تغذية حصة مبيعات (Quota)',
        'amount': quotaAmount,
        'fee': feeAmount,
        'reference': 'DEP-$requestId',
        'timestamp': FieldValue.serverTimestamp()
      });

      DocumentReference notifRef = _db.collection('notifications').doc();
      batch.set(notifRef, {
        'targetPhones': [agentPhone],
        'title': 'تمت الموافقة على حصتك 🚀',
        'body': 'تمت إضافة حصة مبيعات بقيمة $quotaAmount إلى محفظتك بنجاح.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'readBy': [],
      });

      await batch.commit();
    } catch (e) {
      throw 'فشل في قبول الشحن: $e';
    }
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

  Future<Map<String, dynamic>?> searchUserForTransfer(
      String targetPhone) async {
    if (_activeUserPhone == null) throw 'يرجى تسجيل الدخول.';
    if (targetPhone == _activeUserPhone) throw 'لا يمكنك تحويل الرصيد لنفسك!';

    try {
      final doc = await _db.collection('users').doc(targetPhone).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;

      var lastTxn = await _db
          .collection('transactions')
          .where('toPhone', isEqualTo: targetPhone)
          .where('fromPhone', isEqualTo: _activeUserPhone)
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
        displayBalance = (wallets[_activeUserPhone] ?? 0.0).toDouble();
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

  Future<void> advancedSecureTransferBalance({
    required String targetPhone,
    required String targetName,
    required double amount,
    required double taxPercentage,
    required String note,
    required String paymentMethod,
    required String password,
  }) async {
    if (_activeUserPhone == null) throw 'يرجى تسجيل الدخول.';

    final myData = _usersDatabase.firstWhere(
        (u) => u['phone'] == _activeUserPhone,
        orElse: () => {});
    if (myData['password'] != password) {
      throw 'كلمة المرور غير صحيحة ❌';
    }

    if (currentUserBalance < amount) {
      throw 'رصيد حصتك غير كافٍ لإتمام التحويل ❌';
    }

    double taxAmount = amount * (taxPercentage / 100);
    double totalDebt = amount + taxAmount;

    await _db.runTransaction((transaction) async {
      DocumentReference senderRef = _db.collection('users').doc(_activeUserPhone);
      DocumentReference receiverRef = _db.collection('users').doc(targetPhone);

      var senderDoc = await transaction.get(senderRef);
      var receiverDoc = await transaction.get(receiverRef);

      if (!senderDoc.exists || !receiverDoc.exists) {
        throw 'أحد الحسابات غير موجود في النظام.';
      }

      var sData = senderDoc.data() as Map<String, dynamic>;
      var rData = receiverDoc.data() as Map<String, dynamic>;

      double currentSenderBalance = (sData['balance'] ?? 0.0).toDouble();
      if (currentSenderBalance < amount) throw 'رصيد المحفظة الفعلي غير كافٍ.';

      transaction.update(senderRef, {'balance': FieldValue.increment(-amount)});

      if (rData['role'] == 'user' || rData['role'] == 'pos') {
        transaction.update(receiverRef,
            {'wallets.$_activeUserPhone': FieldValue.increment(amount)});
      } else {
        transaction
            .update(receiverRef, {'balance': FieldValue.increment(amount)});
      }

      if (paymentMethod == 'آجل') {
        transaction.update(receiverRef,
            {'agent_debts.$_activeUserPhone': FieldValue.increment(totalDebt)});
      }

      DocumentReference txnRef = _db.collection('transactions').doc();
      transaction.set(txnRef, {
        'fromPhone': _activeUserPhone,
        'toPhone': targetPhone,
        'agentPhone': _activeUserPhone,
        'agentName': currentUserName,
        'targetName': targetName,
        'networkName': rData['networkName'] ?? 'غير محدد',
        'amount': amount,
        'fee': taxAmount,
        'totalDebt': paymentMethod == 'آجل' ? totalDebt : 0,
        'paymentMethod': paymentMethod,
        'note': note,
        'type': 'transfer',
        'title': 'تحويل رصيد إلى $targetName',
        'reference': 'TRX-${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': FieldValue.serverTimestamp()
      });

      DocumentReference notifRef = _db.collection('notifications').doc();
      transaction.set(notifRef, {
        'targetPhones': [targetPhone],
        'title': 'حوالة واردة 💸',
        'body':
            'تم إيداع مبلغ $amount ريال إلى محفظتك من الوكيل $currentUserName.\nطريقة الدفع: $paymentMethod',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'readBy': [],
      });
    });
  }

  Future<void> secureTransferBalance(
      {required String targetPhone,
      required String targetName,
      required double amount,
      required String password}) async {
    await advancedSecureTransferBalance(
        targetPhone: targetPhone,
        targetName: targetName,
        amount: amount,
        taxPercentage: 0.0,
        note: '',
        paymentMethod: 'نقد',
        password: password);
  }

  Future<void> addAgentBankAccount(String networkName, String agentName,
      String bankName, String accNumber, String note) async {
    if (_activeUserPhone == null) return;
    try {
      int newOrder = _myAgentBankAccounts.length;
      await _db.collection('agent_bank_accounts').add({
        'agentPhone': _activeUserPhone,
        'networkName': networkName,
        'agentName': agentName,
        'bankName': bankName,
        'accountNumber': accNumber,
        'note': note.isNotEmpty ? note : 'لا توجد ملاحظات',
        'status': 'نشط',
        'order': newOrder,
        'createdAt': FieldValue.serverTimestamp()
      });
    } catch (e) {
      throw 'خطأ في إضافة الحساب: $e';
    }
  }

  Future<void> updateAgentBankAccount(String docId, String networkName,
      String agentName, String bankName, String accNumber, String note) async {
    await _db.collection('agent_bank_accounts').doc(docId).update({
      'networkName': networkName,
      'agentName': agentName,
      'bankName': bankName,
      'accountNumber': accNumber,
      'note': note
    });
  }

  Future<void> toggleAgentBankAccountStatus(
      String docId, String currentStatus) async {
    String newStatus = currentStatus == 'نشط' ? 'موقوف' : 'نشط';
    await _db
        .collection('agent_bank_accounts')
        .doc(docId)
        .update({'status': newStatus});
  }

  Future<void> deleteAgentBankAccount(String docId) async {
    await _db.collection('agent_bank_accounts').doc(docId).delete();
  }

  Future<void> reorderAgentBankAccounts(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _myAgentBankAccounts.removeAt(oldIndex);
    _myAgentBankAccounts.insert(newIndex, item);
    notifyListeners();
    WriteBatch batch = _db.batch();
    for (int i = 0; i < _myAgentBankAccounts.length; i++) {
      batch.update(
          _db.collection('agent_bank_accounts').doc(_myAgentBankAccounts[i]['docId']),
          {'order': i});
    }
    await batch.commit();
  }

  Future<void> updateDangerLimit(String phone, double newLimit) async {
    await _db
        .collection('users')
        .doc(phone)
        .update({'dangerLimit': newLimit});
  }

  Future<void> manualSettlement(
      {required String agentPhone,
      required String agentName,
      required double amount,
      required String reason}) async {
    try {
      WriteBatch batch = _db.batch();
      DocumentReference agentRef = _db.collection('users').doc(agentPhone);
      batch.update(agentRef, {'balance': FieldValue.increment(amount)});

      final agentDoc = await _db.collection('users').doc(agentPhone).get();
      final agentData = agentDoc.data() as Map<String, dynamic>? ?? {};

      DocumentReference transactionRef = _db.collection('transactions').doc();
      batch.set(transactionRef, {
        'fromPhone': '774578241',
        'toPhone': agentPhone,
        'agentPhone': agentPhone,
        'agentName': agentName,
        'targetName': 'المركز الرئيسي',
        'networkName': agentData['networkName'] ?? 'غير محدد',
        'type': amount > 0 ? 'deposit' : 'expense',
        'title': amount > 0
            ? 'تسوية يدوية للحصة (إضافة)'
            : 'تسوية يدوية للحصة (خصم)',
        'amount': amount.abs(),
        'fee': 0.0,
        'paymentMethod': 'تسوية إدارية',
        'reason': reason,
        'reference': 'SET-${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': FieldValue.serverTimestamp()
      });

      DocumentReference notifRef = _db.collection('notifications').doc();
      batch.set(notifRef, {
        'targetPhones': [agentPhone],
        'title': 'تسوية يدوية لحصتك ⚙️',
        'body':
            'تم ${amount > 0 ? "إضافة" : "خصم"} مبلغ ${amount.abs()} ريال.\nالسبب: $reason',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'readBy': [],
      });

      await batch.commit();
    } catch (e) {
      throw 'فشل التسوية اليدوية: $e';
    }
  }

  Future<void> _sendNotification(
      {required List<String> targetPhones,
      required String title,
      required String body}) async {
    await _db.collection('notifications').add({
      'targetPhones': targetPhones,
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'readBy': [],
    });
  }

  Future<void> markNotificationsAsRead() async {
    if (_activeUserPhone == null) return;

    WriteBatch batch = _db.batch();
    for (var notif in _notifications) {
      if (notif['isReadLocal'] == false) {
        DocumentReference ref =
            _db.collection('notifications').doc(notif['docId']);
        batch.update(ref, {'readBy': FieldValue.arrayUnion([_activeUserPhone])});
      }
    }
    await batch.commit();
  }

  Future<void> applySubscriptionPlan(
      {required int targetingFilter,
      required String planName,
      required double planPrice,
      required int durationMonths,
      String? targetAgentPhone}) async {
    try {
      WriteBatch batch = _db.batch();
      final DateTime newExpiry =
          DateTime.now().add(Duration(days: durationMonths * 30));
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

  Future<void> createSmartCoupon(
      {required String code,
      required String discountDetails,
      required int maxUses,
      required String sendMethod}) async {
    try {
      final existing =
          await _db.collection('coupons').where('code', isEqualTo: code).get();
      if (existing.docs.isNotEmpty) throw 'كود الكوبون مستخدم مسبقاً!';

      await _db.collection('coupons').add({
        'code': code.toUpperCase(),
        'discountDetails': discountDetails,
        'maxUses': maxUses,
        'usedCount': 0,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('outbox_messages').add({
        'type': sendMethod,
        'content': 'تم إصدار كوبون جديد: $code بخصم $discountDetails',
        'target': 'all_agents',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent'
      });

      _sendNotification(
          targetPhones: ['all_agents'],
          title: 'كوبون جديد متاح! 🎟️',
          body: 'استخدم الكود $code للحصول على $discountDetails');
    } catch (e) {
      throw 'فشل إنشاء الكوبون: $e';
    }
  }

  Future<void> deactivateCoupon(String docId, String code) async {
    try {
      await _db.collection('coupons').doc(docId).update({'isActive': false});
    } catch (e) {
      throw 'فشل إيقاف الكوبون: $e';
    }
  }

  Future<void> updateAgentGracePeriod(
      String agentPhone, String newExpiryDate) async {
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

  Future<void> toggleSubscriptionStatus(
      String agentPhone, String currentStatus) async {
    try {
      String newStatus = currentStatus == 'موقوف مؤقتاً' ? 'نشط' : 'موقوف مؤقتاً';
      await _db
          .collection('users')
          .doc(agentPhone)
          .update({'subStatus': newStatus});
      _sendNotification(
          targetPhones: [agentPhone],
          title: 'حالة الحساب',
          body: 'تم تحويل حالة حسابك إلى: $newStatus');
    } catch (e) {
      throw 'فشل التغيير: $e';
    }
  }

  bool changeUserPassword(String oldPassword, String newPassword) {
    if (_activeUserPhone == null) return false;
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone);
    if (user['password'] == oldPassword) {
      _db
          .collection('users')
          .doc(_activeUserPhone)
          .update({'password': newPassword});
      return true;
    }
    return false;
  }

  void toggleBiometric(bool isEnabled) {
    if (_activeUserPhone == null) return;
    _db
        .collection('users')
        .doc(_activeUserPhone)
        .update({'isBiometricEnabled': isEnabled});
  }

  Future<void> updateAutoBackupSettings(
      bool isEnabled, String freq, String time, String email) async {
    await _db.collection('system').doc('backup_settings').update({
      'isAutoBackupEnabled': isEnabled,
      'backupFrequency': freq,
      'backupTime': time,
      'emergencyEmail': email
    });
  }

  Future<void> toggleCloudLink(String service, bool isLinked) async {
    if (service == 'drive') {
      await _db
          .collection('system')
          .doc('backup_settings')
          .update({'isDriveLinked': isLinked});
    } else {
      await _db
          .collection('system')
          .doc('backup_settings')
          .update({'isDropboxLinked': isLinked});
    }
  }

  Future<void> takeManualBackup() async {
    final now = DateTime.now();
    final formattedDate =
        '${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}';

    await _db.collection('backups').add({
      'date': formattedDate,
      'size': '45 MB',
      'type': 'يدوي (محلي)',
      'timestamp': FieldValue.serverTimestamp()
    });

    await _db.collection('system').doc('backup_settings').update({
      'manualTrigger': FieldValue.serverTimestamp(),
    });

    await logAction(
        action: 'تصدير نسخة احتياطية',
        details: 'تم طلب نسخة احتياطية فورية',
        severity: 'critical');
  }

  Future<void> deleteBackup(String docId) async {
    await _db.collection('backups').doc(docId).delete();
  }

  Future<void> logRestoreAttempt(bool isSuccess, String backupDate) async {
    logAction(
        action: isSuccess ? 'استعادة (ناجحة)' : 'استعادة (فاشلة)',
        details: 'استعادة للنقطة $backupDate',
        severity: 'critical');
  }

  Future<void> addBankAccount(
      String bankName, String accNumber, String beneficiary) async {
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

  Future<void> updateBankAccount(
      String docId, String bankName, String accNumber, String beneficiary) async {
    await _db.collection('bank_accounts').doc(docId).update({
      'bankName': bankName,
      'accountNumber': accNumber,
      'beneficiary': beneficiary
    });
  }

  Future<void> toggleBankAccountStatus(
      String docId, String currentStatus) async {
    String newStatus = currentStatus == 'نشط' ? 'موقوف' : 'نشط';
    await _db
        .collection('bank_accounts')
        .doc(docId)
        .update({'status': newStatus});
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

  // ==================== دوال المحفظة ====================
  Stream<List<Map<String, dynamic>>> getMyPendingQuotaRequests() {
    if (_activeUserPhone == null) return Stream.value([]);
    return _db
        .collection('recharge_requests')
        .where('userPhone', isEqualTo: _activeUserPhone)
        .where('type', isEqualTo: 'saas_quota')
        .where('status', isEqualTo: 'قيد الانتظار')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['docId'] = doc.id;
              return data;
            }).toList());
  }

  Stream<List<Map<String, dynamic>>> getPendingPosRechargeRequests() {
    if (_activeUserPhone == null) return Stream.value([]);
    return _db
        .collection('user_recharges')
        .where('targetPhone', isEqualTo: _activeUserPhone)
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

  // ==================== دوال إعدادات المستخدم ====================
  Future<void> saveUserPreferredColor(Color color) async {
    if (_activeUserPhone == null) return;
    final colorValue = color.value;
    await _db.collection('users').doc(_activeUserPhone).update({
      'preferredColor': colorValue,
    });
  }

  Future<Color?> getUserPreferredColor() async {
    if (_activeUserPhone == null) return null;
    try {
      final doc = await _db.collection('users').doc(_activeUserPhone).get();
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

  Future<void> updateUserPin(String pin) async {
    if (_activeUserPhone == null) return;
    await _db.collection('users').doc(_activeUserPhone).update({'pin': pin});
    final index = _usersDatabase.indexWhere((u) => u['phone'] == _activeUserPhone);
    if (index != -1) {
      _usersDatabase[index]['pin'] = pin;
      notifyListeners();
    }
  }

  Future<void> updateUserDailyLimit(double limit) async {
    if (_activeUserPhone == null) return;
    await _db.collection('users').doc(_activeUserPhone).update({'dailyLimit': limit});
    final index = _usersDatabase.indexWhere((u) => u['phone'] == _activeUserPhone);
    if (index != -1) {
      _usersDatabase[index]['dailyLimit'] = limit;
      notifyListeners();
    }
  }

  Future<bool> deleteUserAccount(String password) async {
    if (_activeUserPhone == null) return false;
    try {
      final doc = await _db.collection('users').doc(_activeUserPhone).get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;
      if (data['password'] != password) return false;

      await _db.collection('users').doc(_activeUserPhone).delete();
      clearAllData();
      return true;
    } catch (e) {
      debugPrint('خطأ في حذف الحساب: $e');
      return false;
    }
  }

  Future<void> updatePrivacySetting(String key, bool value) async {
    if (_activeUserPhone == null) return;
    await _db.collection('users').doc(_activeUserPhone).update({'privacy_$key': value});
  }

  // ==================== دوال الترقية والشرائح (Discount Tiers) ====================

  /// جلب أعلى شريحة خصم مؤهلة للمستخدم الحالي مع وكيل معين
  Future<Map<String, dynamic>?> getUserTierForAgent(String agentPhone) async {
    if (_activeUserPhone == null) return null;

    // رصيد المستخدم لدى هذا الوكيل
    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _activeUserPhone,
        orElse: () => {});
    Map<String, dynamic> wallets = user['wallets'] ?? {};
    double walletBalance = (wallets[agentPhone] ?? 0.0).toDouble();

    // جلب جميع الشرائح النشطة لهذا الوكيل
    final tierQuery = await _db.collection('discount_tiers')
        .where('agentPhone', isEqualTo: agentPhone)
        .where('isActive', isEqualTo: true)
        .get();

    if (tierQuery.docs.isEmpty) return null;

    List<Map<String, dynamic>> tiers = tierQuery.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();

    // ترتيب تنازلي حسب الشرط (أكبر عتبة أولاً)
    tiers.sort((a, b) => (b['condition'] as int).compareTo(a['condition'] as int));

    // البحث عن أول شريحة شرطها ≤ الرصيد
    for (var tier in tiers) {
      if (walletBalance >= (tier['condition'] as num).toDouble()) {
        return tier;
      }
    }
    return null; // لا يوجد شريحة مؤهلة
  }

  /// جلب أعلى شريحة عبر جميع الوكلاء (للقائمة الجانبية)
  Future<Map<String, dynamic>?> getUserHighestTier() async {
    if (_activeUserPhone == null) return null;

    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _activeUserPhone,
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

  // ==================== PIN مع التحقق الثلاثي ====================
  Future<String> changeUserPinWithOld(String oldPin, String newPin, String confirmPin) async {
    if (_activeUserPhone == null) return 'يرجى تسجيل الدخول.';
    if (newPin.length != 6) return 'يجب أن يتكون رمز PIN من 6 أرقام.';
    if (newPin != confirmPin) return 'رمز PIN الجديد غير متطابق.';

    final user = _usersDatabase.firstWhere(
        (u) => u['phone'] == _activeUserPhone,
        orElse: () => {});
    if (user.isEmpty) return 'المستخدم غير موجود.';

    String storedPin = user['pin'] ?? '123456';
    if (storedPin != oldPin) return 'رمز PIN القديم غير صحيح.';

    await _db.collection('users').doc(_activeUserPhone).update({'pin': newPin});
    final index = _usersDatabase.indexWhere((u) => u['phone'] == _activeUserPhone);
    if (index != -1) {
      _usersDatabase[index]['pin'] = newPin;
      notifyListeners();
    }
    return 'تم تحديث رمز PIN بنجاح.';
  }

  bool validatePin(String pin) {
    if (_activeUserPhone == null) return false;
    return currentUserPin == pin;
  }

  // ==================== دوال اللغة ====================
  Future<void> saveLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', langCode);
  }

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('language') ?? 'ar';
  }
}
