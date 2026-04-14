import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

class SystemProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  double _adminMainBalance = 10000000.0; 
  int _totalSystemCards = 5000; 
  String? _activeUserPhone; 
  double _newsScrollSpeed = 40.0; 

  String _currentUserRole = 'guest';
  Map<String, bool> _currentUserPermissions = {};

  // ==========================================
  // ⚙️ 1. إعدادات النظام الأساسية
  // ==========================================
  bool _isMaintenanceMode = false;
  bool _isForcedUpdate = false;
  bool _showNewsBar = true;
  bool _isCurrencyAutoRounding = true;
  String _minimumChargeLimit = '1000';
  String _termsAndConditions = '';
  String _supportNumbers = '';

  // ==========================================
  // 🚪 2. إعدادات بوابة تسجيل الدخول (Public Portal)
  // ==========================================
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

  // ==========================================
  // 💼 3. إعدادات بوابة الوكلاء (Agents Portal)
  // ==========================================
  List<String> _agentUniversalHiddenSections = [];
  List<Map<String, dynamic>> _agentBanners = [];
  Map<String, dynamic> _agentEmergencyAlert = {'isActive': false, 'text': '', 'targetType': 'all', 'targetPhones': []};
  bool _hideProfitEnabled = false;
  bool _leaderboardEnabled = false;
  bool _forceAgentTheme = false;

  // ==========================================
  // 👥 4. إعدادات بوابة المستخدمين (Users Portal)
  // ==========================================
  List<String> _userUniversalHiddenSections = [];
  bool _guestModeEnabled = false;
  bool _kycRequired = false;
  Map<String, dynamic> _userPromoPopup = {'isActive': false, 'imageUrl': '', 'targetType': 'all', 'targetPhones': []};
  Map<String, dynamic> _socialLinks = {'whatsapp': '', 'facebook': '', 'telegram': ''};
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

  // 👈 إضافة قائمة الإشعارات
  List<Map<String, dynamic>> _notifications = [];

  SystemProvider() {
    _initDatabaseSync();
  }

  void _initDatabaseSync() {
    _db.collection('system').doc('main_info').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        _adminMainBalance = (data['adminMainBalance'] ?? 10000000.0).toDouble();
        _totalSystemCards = data['totalSystemCards'] ?? 5000;
        _announcements = List<String>.from(data['announcements'] ?? ['أهلاً بك في شبكة كروت نت...']);
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
        _loginCarouselImages = List<String>.from(data['loginCarouselImages'] ?? []);
        _loginWelcomeMessage = data['loginWelcomeMessage'] ?? 'مرحباً بك في نظام كروت نت';
        _carouselIntervalSeconds = data['carouselIntervalSeconds'] ?? 5;
        _marqueeDirection = data['marqueeDirection'] ?? 'rtl';
        _marqueeTextColor = data['marqueeTextColor'] ?? 0xFFFFFFFF;
        _marqueeBgColor = data['marqueeBgColor'] ?? 0x4DFFC107;
        _marqueeFontSize = (data['marqueeFontSize'] ?? 14.0).toDouble();
        
        _appNameAlign = data['appNameAlign'] ?? 'center';
        _appNameFont = data['appNameFont'] ?? 'Cairo';
        _appNameColor = data['appNameColor'] ?? 0xFF2196F3;

        _agentUniversalHiddenSections = List<String>.from(data['agentUniversalHiddenSections'] ?? []);
        _userUniversalHiddenSections = List<String>.from(data['userUniversalHiddenSections'] ?? []);
        _hideProfitEnabled = data['hideProfitEnabled'] ?? false;
        _leaderboardEnabled = data['leaderboardEnabled'] ?? false;
        _forceAgentTheme = data['forceAgentTheme'] ?? false;
        
        _guestModeEnabled = data['guestModeEnabled'] ?? false;
        _kycRequired = data['kycRequired'] ?? false;
        _loyaltySystemEnabled = data['loyaltySystemEnabled'] ?? false;
        
        if (data['socialLinks'] != null) _socialLinks = Map<String, dynamic>.from(data['socialLinks']);
        if (data['agentEmergencyAlert'] != null) _agentEmergencyAlert = Map<String, dynamic>.from(data['agentEmergencyAlert']);
        if (data['userPromoPopup'] != null) _userPromoPopup = Map<String, dynamic>.from(data['userPromoPopup']);
        if (data['agentBanners'] != null) _agentBanners = List<Map<String, dynamic>>.from(data['agentBanners']);
        if (data['targetedNews'] != null) _targetedNews = List<Map<String, dynamic>>.from(data['targetedNews']);
        
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

    _db.collection('recharge_requests').where('status', isEqualTo: 'قيد الانتظار').snapshots().listen((snapshot) {
      _rechargeRequests = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    _db.collection('transactions').orderBy('timestamp', descending: true).snapshots().listen((snapshot) {
      _transactionsLedger = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    _db.collection('audit_logs').orderBy('timestamp', descending: true).limit(50).snapshots().listen((snapshot) {
      _auditLogs = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    _db.collection('system').doc('backup_settings').snapshots().listen((snapshot) {
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

    _db.collection('backups').orderBy('timestamp', descending: true).snapshots().listen((snapshot) {
      _backupsList = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    _db.collection('bank_accounts').orderBy('order').snapshots().listen((snapshot) {
      _bankAccounts = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    _db.collection('coupons').orderBy('createdAt', descending: true).snapshots().listen((snapshot) {
      _coupons = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    _db.collection('support_tickets').snapshots().listen((snapshot) {
      _supportTickets = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });

    _db.collection('sales').snapshots().listen((snapshot) {
      _salesList = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data()}).toList();
      notifyListeners();
    });
  }

  // 👈 إضافة مستمع للإشعارات يعمل بمجرد تسجيل الدخول
  void _listenToUserNotifications() {
    if (_activeUserPhone == null) return;

    // استهداف جميع الإشعارات الموجهة إما لرقم المستخدم أو الموجهة لجميع الوكلاء/المستخدمين بناءً على دوره
    _db.collection('notifications')
      .where('targetPhones', arrayContainsAny: [_activeUserPhone, 'all', _currentUserRole == 'agent' ? 'all_agents' : 'all_users'])
      .orderBy('timestamp', descending: true)
      .limit(30)
      .snapshots()
      .listen((snapshot) {
        _notifications = snapshot.docs.map((doc) {
          final data = doc.data();
          // فحص حالة القراءة الخاصة بهذا المستخدم تحديداً إذا كان الإشعار جماعياً
          List readBy = data['readBy'] ?? [];
          bool isRead = readBy.contains(_activeUserPhone) || data['isRead'] == true;
          return {'docId': doc.id, ...data, 'isReadLocal': isRead};
        }).toList();
        notifyListeners();
    });
  }

  void _runAutoRadar(List<Map<String, dynamic>> users) {
    final now = DateTime.now();
    WriteBatch batch = _db.batch();
    bool needsUpdate = false;

    for (var user in users) {
      if (user['role'] == 'agent' && user['subExpiry'] != null && user['subStatus'] == 'نشط') {
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

  // ==========================================
  // 🔍 دوال القراءة (Getters) 
  // ==========================================
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

  List<Map<String, dynamic>> get agentsList => _usersDatabase.where((user) => user['role'] == 'agent').toList();
  List<Map<String, dynamic>> get usersList => _usersDatabase.where((user) => user['role'] == 'user').toList();
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

  // 👈 إضافة جلب الإشعارات
  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadNotificationsCount => _notifications.where((n) => n['isReadLocal'] == false).length;

  void setDashboardDateRange(DateTimeRange? range) {
    _dashboardDateRange = range;
    notifyListeners();
  }

  DateTimeRange? get dashboardDateRange => _dashboardDateRange;
  int get smsBalance => _smsBalance;

  double get filteredSales {
    return _salesList.where((sale) {
      final dateStr = sale['date'] ?? DateTime.now().toIso8601String();
      try {
        final date = DateTime.parse(dateStr);
        if (_dashboardDateRange != null) {
          return date.isAfter(_dashboardDateRange!.start.subtract(const Duration(days: 1))) &&
                 date.isBefore(_dashboardDateRange!.end.add(const Duration(days: 1)));
        }
        return date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;
      } catch (e) { return false; }
    }).fold(0.0, (sum, sale) => sum + ((sale['amount'] ?? 0.0) as num));
  }

  double get filteredProfit {
    return _salesList.where((sale) {
      final dateStr = sale['date'] ?? DateTime.now().toIso8601String();
      try {
        final date = DateTime.parse(dateStr);
        if (_dashboardDateRange != null) {
          return date.isAfter(_dashboardDateRange!.start.subtract(const Duration(days: 1))) &&
                 date.isBefore(_dashboardDateRange!.end.add(const Duration(days: 1)));
        }
        return date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;
      } catch (e) { return false; }
    }).fold(0.0, (sum, sale) => sum + ((sale['profit'] ?? 0.0) as num));
  }

  int get openTicketsCount => _supportTickets.where((ticket) => ticket['status'] == 'مفتوحة').length;
  int get criticalTicketsCount => _supportTickets.where((ticket) => ticket['status'] == 'مفتوحة' && ticket['priority'] == 'عالية').length;

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
    return {'active': active, 'expiringSoon': expiringSoon, 'frozen': frozen, 'expectedRevenue': realExpectedRevenue};
  }

  String get currentUserName {
    if (_activeUserPhone == null) return 'مستخدم غير معروف';
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {'name': 'مستخدم غير معروف'});
    return user['name'] ?? 'مستخدم غير معروف';
  }

  String get currentUserPhone => _activeUserPhone ?? 'لا يوجد رقم';

  bool hasPermission(String permissionName) {
    if (_currentUserRole == 'super_admin') return true; 
    return _currentUserPermissions[permissionName] ?? false; 
  }

  String get currentUserPin {
    if (_activeUserPhone == null) return '';
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {'pin': ''});
    return user['pin'] ?? '123456'; 
  }

  double get currentUserBalance {
    if (_activeUserPhone == null) return 0.0;
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {'balance': 0.0});
    return (user['balance'] ?? 0.0).toDouble();
  }

  List<String> get userPurchasedCards {
    if (_activeUserPhone == null) return [];
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {'purchasedCards': <String>[]});
    return List<String>.from(user['purchasedCards'] ?? []);
  }

  List<String> get currentUserHiddenSections {
    if (_activeUserPhone == null) return [];
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {'role': 'user', 'hiddenSections': <String>[]});
    List<String> personalHidden = List<String>.from(user['hiddenSections'] ?? []);
    List<String> universalHidden = user['role'] == 'agent' ? _agentUniversalHiddenSections : _userUniversalHiddenSections;
    return {...personalHidden, ...universalHidden}.toList();
  }

  bool get isBiometricCurrentlyEnabled {
    if (_activeUserPhone == null) return false;
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {'isBiometricEnabled': false});
    return user['isBiometricEnabled'] ?? false;
  }

  Future<void> logAction({required String action, required String details, required String severity, String? targetPhone}) async {
    if (_activeUserPhone == null) return; 
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone, orElse: () => {'name': 'غير معروف', 'role': 'Unknown'});
    final now = DateTime.now();
    final formattedDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    try {
      await _db.collection('audit_logs').add({
        'name': user['name'] ?? 'غير معروف', 'phone': _activeUserPhone, 'role': user['role'] ?? 'Unknown',
        'action': action, 'details': details, 'datetime': formattedDate,
        'timestamp': FieldValue.serverTimestamp(), 'ip': 'Cloud System', 'severity': severity, 'targetPhone': targetPhone, 
      });
    } catch (e) {}
  }

  // ==========================================
  // 🚀 5. دوال الإدارة والتحكم 
  // ==========================================
  
  Future<void> updateAdvancedLoginSettings({
    required String name, required String logoUrl, required int bgColor,
    required List<String> images, required String welcomeMsg, required int intervalSeconds,
    required String marqueeDir, required int marqueeTextCol, required int marqueeBgCol,
    required String appNameAlign, required String appNameFont, required int appNameColor,
  }) async {
    _appName = name; _appLogoUrl = logoUrl; _loginBgColor = bgColor;
    _loginCarouselImages = images; _loginWelcomeMessage = welcomeMsg; _carouselIntervalSeconds = intervalSeconds;
    _marqueeDirection = marqueeDir; _marqueeTextColor = marqueeTextCol; _marqueeBgColor = marqueeBgCol; 
    _appNameAlign = appNameAlign; _appNameFont = appNameFont; _appNameColor = appNameColor;
    notifyListeners(); 

    await _db.collection('system').doc('main_info').update({
      'appName': name, 'appLogoUrl': logoUrl, 'loginBgColor': bgColor,
      'loginCarouselImages': images, 'loginWelcomeMessage': welcomeMsg, 'carouselIntervalSeconds': intervalSeconds,
      'marqueeDirection': marqueeDir, 'marqueeTextColor': marqueeTextCol, 'marqueeBgColor': marqueeBgCol,
      'appNameAlign': appNameAlign, 'appNameFont': appNameFont, 'appNameColor': appNameColor,
    });
    logAction(action: 'تحديث بوابة الدخول', details: 'تحديث المظهر واسم التطبيق', severity: 'critical');
  }

  Future<void> updateAgentPortalSettings({required bool hideProfit, required bool leaderboard, required bool forceTheme, required List<String> universalHidden}) async {
    _hideProfitEnabled = hideProfit; _leaderboardEnabled = leaderboard; _forceAgentTheme = forceTheme; _agentUniversalHiddenSections = universalHidden;
    notifyListeners();

    await _db.collection('system').doc('main_info').update({
      'hideProfitEnabled': hideProfit, 'leaderboardEnabled': leaderboard, 'forceAgentTheme': forceTheme,
      'agentUniversalHiddenSections': universalHidden
    });
    logAction(action: 'تحديث بوابة الوكلاء', details: 'تم تعديل سياسات لوحة الوكلاء', severity: 'medium');
  }

  Future<void> updateUserPortalSettings({required bool guestMode, required bool kyc, required bool loyalty, required List<String> universalHidden, required Map<String, dynamic> social}) async {
    _guestModeEnabled = guestMode; _kycRequired = kyc; _loyaltySystemEnabled = loyalty; _userUniversalHiddenSections = universalHidden; _socialLinks = social;
    notifyListeners();

    await _db.collection('system').doc('main_info').update({
      'guestModeEnabled': guestMode, 'kycRequired': kyc, 'loyaltySystemEnabled': loyalty,
      'userUniversalHiddenSections': universalHidden, 'socialLinks': social
    });
    logAction(action: 'تحديث بوابة المستخدمين', details: 'تم تعديل سياسات لوحة المستخدمين', severity: 'medium');
  }

  Future<void> toggleSectionForSpecificUsers({required String sectionId, required List<String> targetPhones, required bool hide}) async {
    WriteBatch batch = _db.batch();
    for (String phone in targetPhones) {
      DocumentReference ref = _db.collection('users').doc(phone);
      if (hide) {
        batch.update(ref, {'hiddenSections': FieldValue.arrayUnion([sectionId])});
      } else {
        batch.update(ref, {'hiddenSections': FieldValue.arrayRemove([sectionId])});
      }
    }
    await batch.commit();
    logAction(action: 'استهداف الأقسام', details: 'تم ${hide ? "إخفاء" : "إظهار"} قسم $sectionId لعدد ${targetPhones.length} مستخدم', severity: 'critical');
  }

  Future<void> postTargetedBanner({required String imageUrl, required String targetType, required List<String> targetPhones}) async {
    final newBanner = {'id': DateTime.now().millisecondsSinceEpoch.toString(), 'imageUrl': imageUrl, 'targetType': targetType, 'targetPhones': targetPhones};
    await _db.collection('system').doc('main_info').update({
      'agentBanners': FieldValue.arrayUnion([newBanner])
    });
    logAction(action: 'إعلان موجه', details: 'تم نشر بانر إعلاني بنظام الاستهداف: $targetType', severity: 'normal');
  }

  Future<void> setEmergencyAlert({required bool isActive, required String text, required String targetType, required List<String> targetPhones}) async {
    await _db.collection('system').doc('main_info').update({
      'agentEmergencyAlert': {'isActive': isActive, 'text': text, 'targetType': targetType, 'targetPhones': targetPhones}
    });
    logAction(action: 'تنبيه طوارئ', details: 'حالة الطوارئ: $isActive | الاستهداف: $targetType', severity: 'critical');
  }

  Future<void> updateSystemStatusSettings({required bool maintenance, required bool forcedUpdate, required bool showNews}) async {
    _isMaintenanceMode = maintenance; _isForcedUpdate = forcedUpdate; _showNewsBar = showNews;
    notifyListeners(); 

    await _db.collection('system').doc('main_info').update({'isMaintenanceMode': maintenance, 'isForcedUpdate': forcedUpdate, 'showNewsBar': showNews});
  }

  Future<void> updatePoliciesSettings({required String terms, required String support, required String minCharge, required bool autoRounding}) async {
    _termsAndConditions = terms; _supportNumbers = support; _minimumChargeLimit = minCharge; _isCurrencyAutoRounding = autoRounding;
    notifyListeners(); 

    await _db.collection('system').doc('main_info').update({'termsAndConditions': terms, 'supportNumbers': support, 'minimumChargeLimit': minCharge, 'isCurrencyAutoRounding': autoRounding});
  }

  Future<void> addTargetedNews({required String text, required String targetRole}) async {
    final newNews = {'id': DateTime.now().millisecondsSinceEpoch.toString(), 'text': text, 'target': targetRole};
    await _db.collection('system').doc('main_info').update({'targetedNews': FieldValue.arrayUnion([newNews])});
  }

  Future<void> removeTargetedNews(Map<String, dynamic> newsItem) async {
    await _db.collection('system').doc('main_info').update({'targetedNews': FieldValue.arrayRemove([newsItem])});
  }

  Future<bool> changeUserName(String newName) async {
    if (_activeUserPhone == null) return false;
    try {
      await _db.collection('users').doc(_activeUserPhone).update({'name': newName});
      return true;
    } catch (e) { return false; }
  }

  Future<bool> changeUserPin(String oldPin, String newPin) async {
    if (_activeUserPhone == null) return false;
    if (currentUserPin == oldPin) {
      await _db.collection('users').doc(_activeUserPhone).update({'pin': newPin});
      return true; 
    }
    return false; 
  }

  // ==========================================
  // 👥 6. دوال إدارة الحسابات والمصادقة
  // ==========================================

  Future<void> updateNewsSpeed(double newSpeed) async { 
    _newsScrollSpeed = newSpeed;
    notifyListeners();
    await _db.collection('system').doc('main_info').update({'newsScrollSpeed': newSpeed}); 
  }

  Future<bool> checkUserExists(String phone) async {
    try {
      final doc = await _db.collection('users').doc(phone).get().timeout(const Duration(seconds: 5));
      return doc.exists;
    } catch (e) { return false; }
  }

  Future<Map<String, dynamic>?> loginUser(String phone, String password) async {
    _currentUserPermissions = {};
    _currentUserRole = 'guest';

    if (phone == '774578241' && password == '75486958aaa') {
      final superAdminData = {
        'id': 'SUPER_ADMIN_01', 'name': 'مالك النظام', 'phone': '774578241', 'password': '75486958aaa',
        'role': 'super_admin', 'balance': 0.0, 'dangerLimit': 0.0, 'status': 'نشط',
        'pin': '123456', 'purchasedCards': [], 'isBiometricEnabled': false, 'hiddenSections': [], 
      };
      try {
        _db.collection('users').doc('774578241').set(superAdminData, SetOptions(merge: true));
        _db.collection('system').doc('main_info').set({
          'adminMainBalance': 10000000.0, 'totalSystemCards': 5000,
        }, SetOptions(merge: true));
      } catch (e) {}
      _activeUserPhone = phone;
      _currentUserRole = 'super_admin'; 
      _listenToUserNotifications(); // 👈 تفعيل مستمع الإشعارات بعد الدخول
      notifyListeners();
      return superAdminData; 
    }
    try {
      final doc = await _db.collection('users').doc(phone).get().timeout(const Duration(seconds: 7));
      if (doc.exists) {
        final userData = doc.data() as Map<String, dynamic>;
        if (userData['password'] == password) {
          _activeUserPhone = phone;
          _currentUserRole = userData['role'] ?? 'user'; 

          if (_currentUserRole == 'staff' && userData['permissions'] != null) {
            _currentUserPermissions = Map<String, bool>.from(userData['permissions']);
          }

          _listenToUserNotifications(); // 👈 تفعيل المستمع
          notifyListeners();
          logAction(action: 'تسجيل دخول', details: 'تم تسجيل الدخول بواسطة: ${userData['name']}', severity: 'normal');
          return userData;
        }
      }
      return null; 
    } catch (e) { return null; }
  }

  Future<void> registerNewUser({required String name, required String phone, required String password, required String role}) async {
    try {
      await _db.collection('users').doc(phone).set({
        'id': 'USER_${DateTime.now().millisecondsSinceEpoch}', 'name': name, 'phone': phone, 'password': password,
        'role': role, 'balance': 0.0, 'dangerLimit': 0.0, 'status': 'نشط', 'purchasedCards': [], 
        'pin': '123456', 'isBiometricEnabled': false, 'createdAt': FieldValue.serverTimestamp(),
        'hiddenSections': [], 
      });
      _activeUserPhone = phone;
      _currentUserRole = role; 
      _listenToUserNotifications(); // 👈 تفعيل المستمع
      notifyListeners();
    } catch (e) { throw 'فشل تسجيل المستخدم: $e'; }
  }

  Future<void> addAgent({required String name, required String phone, required String password, String? networkName, String? profitMargin, String? location}) async {
    try {
      bool exists = await checkUserExists(phone);
      if (!exists) {
        final DateTime nextMonth = DateTime.now().add(const Duration(days: 30));
        final String expiryDate = '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}-${nextMonth.day.toString().padLeft(2, '0')}';

        await _db.collection('users').doc(phone).set({
          'id': 'AGENT_${DateTime.now().millisecondsSinceEpoch}', 'name': name, 'phone': phone, 'password': password,
          'role': 'agent', 'networkName': networkName ?? 'غير محدد', 'profitMargin': profitMargin ?? 'غير محدد',
          'location': location ?? 'غير محدد', 'balance': 0.0, 'dangerLimit': 0.0, 'status': 'نشط',
          'pin': '123456', 'subPlan': 'باقة افتراضية', 'subPrice': 0.0, 'subStatus': 'نشط', 'subExpiry': expiryDate,  
          'purchasedCards': [], 'isBiometricEnabled': false, 'createdAt': FieldValue.serverTimestamp(),
          'hiddenSections': [], 
        });
        logAction(action: 'إضافة وكيل جديد', details: 'تم إضافة وكيل جديد باسم "$name" ورقم $phone', severity: 'medium');
        
        // 👈 إرسال إشعار ترحيبي للوكيل
        _sendNotification(targetPhones: [phone], title: 'أهلاً بك كوكيل جديد! 🎉', body: 'تم تفعيل حسابك كوكيل معتمد في النظام.');
      } else { throw 'رقم الهاتف مسجل مسبقاً في النظام!'; }
    } catch (e) { throw 'حدث خطأ: $e'; }
  }

  Future<void> updateAgentDetails({required String oldPhone, required String newPhone, required String newName, required String newNetwork, required String newLocation, required String newProfit, required String newPassword}) async {
    try {
      final doc = await _db.collection('users').doc(oldPhone).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data()!;
        data.addAll({'phone': newPhone, 'name': newName, 'networkName': newNetwork, 'location': newLocation, 'profitMargin': newProfit, 'password': newPassword});
        WriteBatch batch = _db.batch();
        batch.set(_db.collection('users').doc(newPhone), data);
        if (oldPhone != newPhone) batch.delete(_db.collection('users').doc(oldPhone));
        await batch.commit();
      }
    } catch (e) { throw 'فشل تعديل بيانات الوكيل: $e'; }
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

  bool userBuyCard(double price, String cardName) {
    if (_activeUserPhone == null) return false;
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone);
    if (user['balance'] >= price && _totalSystemCards > 0) {
      _db.collection('system').doc('main_info').update({'totalSystemCards': FieldValue.increment(-1)});
      _db.collection('users').doc(_activeUserPhone).update({'balance': FieldValue.increment(-price), 'purchasedCards': FieldValue.arrayUnion([cardName])});
      return true;
    }
    return false;
  }

  Future<void> updateDangerLimit(String phone, double newLimit) async {
    await _db.collection('users').doc(phone).update({'dangerLimit': newLimit});
  }

  Future<void> acceptRechargeRequest({required String requestId, required String agentPhone, required String agentName, required double amount}) async {
    try {
      WriteBatch batch = _db.batch();
      DocumentReference agentRef = _db.collection('users').doc(agentPhone);
      batch.update(agentRef, {'balance': FieldValue.increment(amount)});
      DocumentReference requestRef = _db.collection('recharge_requests').doc(requestId);
      batch.update(requestRef, {'status': 'مقبول'});
      DocumentReference transactionRef = _db.collection('transactions').doc();
      batch.set(transactionRef, {'agentPhone': agentPhone, 'agentName': agentName, 'type': 'إيداع حوالة', 'amount': amount, 'timestamp': FieldValue.serverTimestamp()});
      
      // 👈 إرسال إشعار للوكيل
      DocumentReference notifRef = _db.collection('notifications').doc();
      batch.set(notifRef, {
        'targetPhones': [agentPhone],
        'title': 'تمت الموافقة على الشحن 💸',
        'body': 'تمت إضافة مبلغ $amount ريال إلى محفظتك بنجاح.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'readBy': [],
      });

      await batch.commit(); 
    } catch (e) { throw 'فشل في قبول الشحن: $e'; }
  }

  Future<void> rejectRechargeRequest(String requestId, String reason) async {
    try {
      final reqDoc = await _db.collection('recharge_requests').doc(requestId).get();
      if(reqDoc.exists){
         String agentPhone = reqDoc.data()!['agentPhone'];
         
         WriteBatch batch = _db.batch();
         batch.update(reqDoc.reference, {'status': 'مرفوض', 'rejectReason': reason});
         
         // 👈 إرسال إشعار للوكيل بالرفض والسبب
         DocumentReference notifRef = _db.collection('notifications').doc();
         batch.set(notifRef, {
           'targetPhones': [agentPhone],
           'title': 'تم رفض طلب الشحن ❌',
           'body': 'السبب: $reason',
           'timestamp': FieldValue.serverTimestamp(),
           'isRead': false,
           'readBy': [],
         });

         await batch.commit();
      }
    } catch(e){}
  }

  Future<void> manualSettlement({required String agentPhone, required String agentName, required double amount, required String reason}) async {
    try {
      WriteBatch batch = _db.batch();
      DocumentReference agentRef = _db.collection('users').doc(agentPhone);
      batch.update(agentRef, {'balance': FieldValue.increment(amount)});
      DocumentReference transactionRef = _db.collection('transactions').doc();
      batch.set(transactionRef, {'agentPhone': agentPhone, 'agentName': agentName, 'type': amount > 0 ? 'تسوية يدوية (إضافة)' : 'تسوية يدوية (خصم)', 'amount': amount, 'reason': reason, 'timestamp': FieldValue.serverTimestamp()});
      
      // 👈 إرسال إشعار للوكيل بالتسوية
      DocumentReference notifRef = _db.collection('notifications').doc();
      batch.set(notifRef, {
        'targetPhones': [agentPhone],
        'title': 'تسوية يدوية لمحفظتك ⚙️',
        'body': 'تم ${amount > 0 ? "إضافة" : "خصم"} مبلغ ${amount.abs()} ريال.\nالسبب: $reason',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'readBy': [],
      });

      await batch.commit();
    } catch (e) { throw 'فشل التسوية اليدوية: $e'; }
  }

  // 👈 دالة مساعدة لإنشاء إشعارات
  Future<void> _sendNotification({required List<String> targetPhones, required String title, required String body}) async {
    await _db.collection('notifications').add({
      'targetPhones': targetPhones,
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'readBy': [],
    });
  }

  // 👈 دالة لجعل الإشعارات "مقروءة" عندما يضغط المستخدم على الجرس
  Future<void> markNotificationsAsRead() async {
    if (_activeUserPhone == null) return;
    
    WriteBatch batch = _db.batch();
    for (var notif in _notifications) {
      if (notif['isReadLocal'] == false) {
        DocumentReference ref = _db.collection('notifications').doc(notif['docId']);
        // إضافة رقم المستخدم لقائمة من قرأ الإشعار
        batch.update(ref, {'readBy': FieldValue.arrayUnion([_activeUserPhone])});
      }
    }
    await batch.commit();
  }

  Future<void> applySubscriptionPlan({required int targetingFilter, required String planName, required double planPrice, required int durationMonths, String? targetAgentPhone}) async {
    try {
      WriteBatch batch = _db.batch();
      final DateTime newExpiry = DateTime.now().add(Duration(days: durationMonths * 30));
      final String formattedExpiry = '${newExpiry.year}-${newExpiry.month.toString().padLeft(2, '0')}-${newExpiry.day.toString().padLeft(2, '0')}';

      if (targetingFilter == 1) {
        for (var agent in agentsList) {
          DocumentReference ref = _db.collection('users').doc(agent['phone']);
          batch.update(ref, {'subPlan': planName, 'subPrice': planPrice, 'subExpiry': formattedExpiry, 'subStatus': 'نشط'});
        }
        _sendNotification(targetPhones: ['all_agents'], title: 'تحديث الباقة 🎁', body: 'تم تجديد باقتك إلى "$planName" بنجاح.');
      } else if (targetingFilter == 2 && targetAgentPhone != null) {
        DocumentReference ref = _db.collection('users').doc(targetAgentPhone);
        batch.update(ref, {'subPlan': planName, 'subPrice': planPrice, 'subExpiry': formattedExpiry, 'subStatus': 'نشط'});
        _sendNotification(targetPhones: [targetAgentPhone], title: 'تحديث الباقة 🎁', body: 'تم تجديد باقتك إلى "$planName" بنجاح.');
      }
      await batch.commit();
    } catch (e) { throw 'حدث خطأ: $e'; }
  }

  Future<void> createSmartCoupon({required String code, required String discountDetails, required int maxUses, required String sendMethod}) async {
    try {
      final existing = await _db.collection('coupons').where('code', isEqualTo: code).get();
      if (existing.docs.isNotEmpty) throw 'كود الكوبون مستخدم مسبقاً!';

      await _db.collection('coupons').add({
        'code': code.toUpperCase(), 'discountDetails': discountDetails, 'maxUses': maxUses, 'usedCount': 0,
        'isActive': true, 'createdAt': FieldValue.serverTimestamp(),
      });
      
      await _db.collection('outbox_messages').add({
         'type': sendMethod, 'content': 'تم إصدار كوبون جديد: $code بخصم $discountDetails',
         'target': 'all_agents', 'timestamp': FieldValue.serverTimestamp(), 'status': 'sent'
      });
      
      // إشعار فوري داخل التطبيق
      _sendNotification(targetPhones: ['all_agents'], title: 'كوبون جديد متاح! 🎟️', body: 'استخدم الكود $code للحصول على $discountDetails');
    } catch (e) { throw 'فشل إنشاء الكوبون: $e'; }
  }

  Future<void> deactivateCoupon(String docId, String code) async {
    try {
      await _db.collection('coupons').doc(docId).update({'isActive': false});
    } catch (e) { throw 'فشل إيقاف الكوبون: $e'; }
  }

  Future<void> updateAgentGracePeriod(String agentPhone, String newExpiryDate) async {
    try {
      await _db.collection('users').doc(agentPhone).update({'subExpiry': newExpiryDate, 'subStatus': 'إنذار'});
      _sendNotification(targetPhones: [agentPhone], title: 'تنبيه فترة السماح ⚠️', body: 'تم تعديل تاريخ انتهاء باقتك إلى $newExpiryDate');
    } catch (e) { throw 'فشل التحديث: $e'; }
  }

  Future<void> toggleSubscriptionStatus(String agentPhone, String currentStatus) async {
    try {
      String newStatus = currentStatus == 'موقوف مؤقتاً' ? 'نشط' : 'موقوف مؤقتاً';
      await _db.collection('users').doc(agentPhone).update({'subStatus': newStatus});
      _sendNotification(targetPhones: [agentPhone], title: 'حالة الحساب', body: 'تم تحويل حالة حسابك إلى: $newStatus');
    } catch (e) { throw 'فشل التغيير: $e'; }
  }

  // ==========================================
  // 🏦 8. الحسابات البنكية والنسخ الاحتياطي
  // ==========================================

  bool changeUserPassword(String oldPassword, String newPassword) {
    if (_activeUserPhone == null) return false;
    final user = _usersDatabase.firstWhere((u) => u['phone'] == _activeUserPhone);
    if (user['password'] == oldPassword) {
      _db.collection('users').doc(_activeUserPhone).update({'password': newPassword});
      return true; 
    }
    return false; 
  }

  void toggleBiometric(bool isEnabled) {
    if (_activeUserPhone == null) return;
    _db.collection('users').doc(_activeUserPhone).update({'isBiometricEnabled': isEnabled});
  }

  Future<void> updateAutoBackupSettings(bool isEnabled, String freq, String time, String email) async {
    await _db.collection('system').doc('backup_settings').update({
      'isAutoBackupEnabled': isEnabled, 
      'backupFrequency': freq, 
      'backupTime': time, 
      'emergencyEmail': email
    });
  }

  Future<void> toggleCloudLink(String service, bool isLinked) async {
    if (service == 'drive') await _db.collection('system').doc('backup_settings').update({'isDriveLinked': isLinked});
    else await _db.collection('system').doc('backup_settings').update({'isDropboxLinked': isLinked});
  }

  Future<void> takeManualBackup() async {
    final now = DateTime.now();
    final formattedDate = '${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}';
    
    await _db.collection('backups').add({'date': formattedDate, 'size': '45 MB', 'type': 'يدوي (محلي)', 'timestamp': FieldValue.serverTimestamp()});
    
    await _db.collection('system').doc('backup_settings').update({
      'manualTrigger': FieldValue.serverTimestamp(),
    });

    await logAction(
        action: 'تصدير نسخة احتياطية', 
        details: 'تم طلب نسخة احتياطية فورية', 
        severity: 'critical'
    );
  }

  Future<void> deleteBackup(String docId) async { await _db.collection('backups').doc(docId).delete(); }
  
  Future<void> logRestoreAttempt(bool isSuccess, String backupDate) async {
    logAction(action: isSuccess ? 'استعادة (ناجحة)' : 'استعادة (فاشلة)', details: 'استعادة للنقطة $backupDate', severity: 'critical');
  }

  Future<void> addBankAccount(String bankName, String accNumber, String beneficiary) async {
    try {
      int newOrder = _bankAccounts.length;
      await _db.collection('bank_accounts').add({'bankName': bankName, 'accountNumber': accNumber, 'beneficiary': beneficiary.isNotEmpty ? beneficiary : 'غير محدد', 'status': 'نشط', 'hasQR': false, 'order': newOrder, 'createdAt': FieldValue.serverTimestamp()});
    } catch (e) { throw 'خطأ: $e'; }
  }

  Future<void> updateBankAccount(String docId, String bankName, String accNumber, String beneficiary) async {
    await _db.collection('bank_accounts').doc(docId).update({'bankName': bankName, 'accountNumber': accNumber, 'beneficiary': beneficiary});
  }

  Future<void> toggleBankAccountStatus(String docId, String currentStatus) async {
    String newStatus = currentStatus == 'نشط' ? 'موقوف' : 'نشط';
    await _db.collection('bank_accounts').doc(docId).update({'status': newStatus});
  }

  Future<void> deleteBankAccount(String docId) async { await _db.collection('bank_accounts').doc(docId).delete(); }

  Future<void> reorderBankAccounts(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _bankAccounts.removeAt(oldIndex);
    _bankAccounts.insert(newIndex, item);
    notifyListeners();
    WriteBatch batch = _db.batch();
    for (int i = 0; i < _bankAccounts.length; i++) {
      batch.update(_db.collection('bank_accounts').doc(_bankAccounts[i]['docId']), {'order': i});
    }
    await batch.commit();
  }
}
