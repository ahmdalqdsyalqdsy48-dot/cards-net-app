import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------- الإعدادات العامة للتطبيق ----------
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

  // ---------- حالة النظام ----------
  bool _isMaintenanceMode = false;
  bool _isForcedUpdate = false;
  bool _showNewsBar = true;
  bool _isCurrencyAutoRounding = true;
  String _minimumChargeLimit = '1000';
  String _termsAndConditions = '';
  String _supportNumbers = '';

  // ---------- المالية العامة (للمدير العام) ----------
  double _adminMainBalance = 0.0;
  int _totalSystemCards = 0;

  // ---------- إعدادات بوابة الوكلاء ----------
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

  // ---------- إعدادات بوابة المستخدمين ----------
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

  // ---------- الشريط الإخباري والإعلانات ----------
  List<Map<String, dynamic>> _targetedNews = [];
  List<String> _announcements = [];
  double _newsScrollSpeed = 40.0;

  // ---------- متنوع ----------
  int _smsBalance = 0;
  bool _soundEnabled = true;
  SharedPreferences? _prefs;

  // ========== 🆕 الخصائص الجديدة للإعدادات الموسعة ==========
  double _transferFeeRate = 0.0;
  double _dailyTransferLimit = 5000.0;
  double _monthlyTransferLimit = 50000.0;
  int _sessionTimeoutMinutes = 30;
  int _maxLoginAttempts = 5;
  int _lowStockThreshold = 10;
  String _reportEmail = '';
  bool _notifyOnRecharge = true;
  bool _notifyOnCoupon = true;
  bool _notifyOnUpdate = true;
  bool _notifyOnTicket = true;
  bool _twoFactorEnabled = false;
  bool _autoPurchaseEnabled = false;
  bool _hideSoldCards = false;
  bool _weeklyReportsEnabled = false;
  bool _logProfitAsExpense = true;
  bool _pullToRefreshEnabled = true;
  bool _animationsEnabled = true;
  bool _forceDarkMode = false;

  // ---------- المُنشئ الأساسي ----------
  SettingsProvider() {
    _initSettingsSync();
    _initPrefs();
  }

  SettingsProvider.withSoundPref(bool soundEnabled) {
    _soundEnabled = soundEnabled;
    _initSettingsSync();
    _initPrefs(skipSound: true);
  }

  Future<void> _initPrefs({bool skipSound = false}) async {
    _prefs = await SharedPreferences.getInstance();
    if (!skipSound) {
      _soundEnabled = _prefs?.getBool('sound_enabled') ?? true;
    }
    // تحميل الإعدادات المحلية الجديدة
    _pullToRefreshEnabled = _prefs?.getBool('pull_to_refresh') ?? true;
    _animationsEnabled = _prefs?.getBool('animations_enabled') ?? true;
    _forceDarkMode = _prefs?.getBool('force_dark_mode') ?? false;
    notifyListeners();
  }

  void _initSettingsSync() {
    _db.collection('system').doc('main_info').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;

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

        _isMaintenanceMode = data['isMaintenanceMode'] ?? false;
        _isForcedUpdate = data['isForcedUpdate'] ?? false;
        _showNewsBar = data['showNewsBar'] ?? true;
        _isCurrencyAutoRounding = data['isCurrencyAutoRounding'] ?? true;
        _minimumChargeLimit = data['minimumChargeLimit'] ?? '1000';
        _termsAndConditions = data['termsAndConditions'] ?? '';
        _supportNumbers = data['supportNumbers'] ?? '';

        _adminMainBalance = (data['adminMainBalance'] ?? 0.0).toDouble();
        _totalSystemCards = data['totalSystemCards'] ?? 0;

        _agentUniversalHiddenSections = List<String>.from(data['agentUniversalHiddenSections'] ?? []);
        _hideProfitEnabled = data['hideProfitEnabled'] ?? false;
        _leaderboardEnabled = data['leaderboardEnabled'] ?? false;
        _forceAgentTheme = data['forceAgentTheme'] ?? false;

        _userUniversalHiddenSections = List<String>.from(data['userUniversalHiddenSections'] ?? []);
        _guestModeEnabled = data['guestModeEnabled'] ?? false;
        _kycRequired = data['kycRequired'] ?? false;
        _loyaltySystemEnabled = data['loyaltySystemEnabled'] ?? false;

        if (data['socialLinks'] != null) {
          _socialLinks = Map<String, dynamic>.from(data['socialLinks']);
        }
        if (data['agentEmergencyAlert'] != null) {
          _agentEmergencyAlert = Map<String, dynamic>.from(data['agentEmergencyAlert']);
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

        _announcements = List<String>.from(data['announcements'] ?? []);
        _newsScrollSpeed = (data['newsScrollSpeed'] ?? 40.0).toDouble();
        _smsBalance = data['smsBalance'] ?? 0;

        // 🆕 تحميل الإعدادات الجديدة من Firestore
        _transferFeeRate = (data['transferFeeRate'] ?? 0.0).toDouble();
        _dailyTransferLimit = (data['dailyTransferLimit'] ?? 5000.0).toDouble();
        _monthlyTransferLimit = (data['monthlyTransferLimit'] ?? 50000.0).toDouble();
        _sessionTimeoutMinutes = data['sessionTimeoutMinutes'] ?? 30;
        _maxLoginAttempts = data['maxLoginAttempts'] ?? 5;
        _lowStockThreshold = data['lowStockThreshold'] ?? 10;
        _reportEmail = data['reportEmail'] ?? '';
        _notifyOnRecharge = data['notifyOnRecharge'] ?? true;
        _notifyOnCoupon = data['notifyOnCoupon'] ?? true;
        _notifyOnUpdate = data['notifyOnUpdate'] ?? true;
        _notifyOnTicket = data['notifyOnTicket'] ?? true;
        _twoFactorEnabled = data['twoFactorEnabled'] ?? false;
        _autoPurchaseEnabled = data['autoPurchaseEnabled'] ?? false;
        _hideSoldCards = data['hideSoldCards'] ?? false;
        _weeklyReportsEnabled = data['weeklyReportsEnabled'] ?? false;
        _logProfitAsExpense = data['logProfitAsExpense'] ?? true;

        notifyListeners();
      }
    });
  }

  // ========== Getters الأساسية ==========
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

  bool get isMaintenanceMode => _isMaintenanceMode;
  bool get isForcedUpdate => _isForcedUpdate;
  bool get showNewsBar => _showNewsBar;
  bool get isCurrencyAutoRounding => _isCurrencyAutoRounding;
  String get minimumChargeLimit => _minimumChargeLimit;
  String get termsAndConditions => _termsAndConditions;
  String get supportNumbers => _supportNumbers;

  double get adminMainBalance => _adminMainBalance;
  int get totalSystemCards => _totalSystemCards;

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
  List<String> get announcements => _announcements;
  double get newsScrollSpeed => _newsScrollSpeed;
  int get smsBalance => _smsBalance;

  bool get isSoundEnabled => _soundEnabled;

  // ========== 🆕 Getters للخصائص الجديدة ==========
  double get transferFeeRate => _transferFeeRate;
  double get dailyTransferLimit => _dailyTransferLimit;
  double get monthlyTransferLimit => _monthlyTransferLimit;
  int get sessionTimeoutMinutes => _sessionTimeoutMinutes;
  int get maxLoginAttempts => _maxLoginAttempts;
  int get lowStockThreshold => _lowStockThreshold;
  String get reportEmail => _reportEmail;
  bool get notifyOnRecharge => _notifyOnRecharge;
  bool get notifyOnCoupon => _notifyOnCoupon;
  bool get notifyOnUpdate => _notifyOnUpdate;
  bool get notifyOnTicket => _notifyOnTicket;
  bool get twoFactorEnabled => _twoFactorEnabled;
  bool get autoPurchaseEnabled => _autoPurchaseEnabled;
  bool get hideSoldCards => _hideSoldCards;
  bool get weeklyReportsEnabled => _weeklyReportsEnabled;
  bool get logProfitAsExpense => _logProfitAsExpense;
  bool get pullToRefreshEnabled => _pullToRefreshEnabled;
  bool get animationsEnabled => _animationsEnabled;
  bool get forceDarkMode => _forceDarkMode;

  // ========== دوال التحديث الأساسية ==========
  Future<void> updateGlobalAppName(String newName) async {
    await _db.collection('system').doc('main_info').update({'appName': newName});
    _appName = newName;
    notifyListeners();
  }

  Future<void> updateAdvancedLoginSettings({
    required String name,
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
    required int appNameColor,
  }) async {
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
  }

  Future<void> updateAgentPortalSettings({
    required bool hideProfit,
    required bool leaderboard,
    required bool forceTheme,
    required List<String> universalHidden,
  }) async {
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
  }

  Future<void> updateUserPortalSettings({
    required bool guestMode,
    required bool kyc,
    required bool loyalty,
    required List<String> universalHidden,
    required Map<String, dynamic> social,
  }) async {
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
  }

  Future<void> toggleSectionForSpecificUsers({
    required String sectionId,
    required List<String> targetPhones,
    required bool hide,
  }) async {
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
  }

  Future<void> postTargetedBanner({
    required String imageUrl,
    required String targetType,
    required List<String> targetPhones,
  }) async {
    final newBanner = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'imageUrl': imageUrl,
      'targetType': targetType,
      'targetPhones': targetPhones
    };
    await _db.collection('system').doc('main_info').update({
      'agentBanners': FieldValue.arrayUnion([newBanner])
    });
  }

  Future<void> setEmergencyAlert({
    required bool isActive,
    required String text,
    required String targetType,
    required List<String> targetPhones,
  }) async {
    await _db.collection('system').doc('main_info').update({
      'agentEmergencyAlert': {
        'isActive': isActive,
        'text': text,
        'targetType': targetType,
        'targetPhones': targetPhones
      }
    });
  }

  Future<void> updateSystemStatusSettings({
    required bool maintenance,
    required bool forcedUpdate,
    required bool showNews,
  }) async {
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

  Future<void> updatePoliciesSettings({
    required String terms,
    required String support,
    required String minCharge,
    required bool autoRounding,
  }) async {
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

  Future<void> addTargetedNews({
    required String text,
    required String targetRole,
  }) async {
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

  Future<void> updateNewsSpeed(double newSpeed) async {
    _newsScrollSpeed = newSpeed;
    notifyListeners();
    await _db.collection('system').doc('main_info').update({'newsScrollSpeed': newSpeed});
  }

  // ========== 🆕 دوال التحكم في الخصائص الجديدة ==========
  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    if (_prefs != null) await _prefs!.setBool('sound_enabled', value);
    notifyListeners();
  }

  Future<void> setTwoFactorEnabled(bool value) async {
    _twoFactorEnabled = value;
    notifyListeners();
    await _db.collection('system').doc('main_info').update({'twoFactorEnabled': value});
  }

  Future<void> setAutoPurchaseEnabled(bool value) async {
    _autoPurchaseEnabled = value;
    notifyListeners();
    await _db.collection('system').doc('main_info').update({'autoPurchaseEnabled': value});
  }

  Future<void> setHideSoldCards(bool value) async {
    _hideSoldCards = value;
    notifyListeners();
    await _db.collection('system').doc('main_info').update({'hideSoldCards': value});
  }

  Future<void> setWeeklyReportsEnabled(bool value) async {
    _weeklyReportsEnabled = value;
    notifyListeners();
    await _db.collection('system').doc('main_info').update({'weeklyReportsEnabled': value});
  }

  Future<void> setLogProfitAsExpense(bool value) async {
    _logProfitAsExpense = value;
    notifyListeners();
    await _db.collection('system').doc('main_info').update({'logProfitAsExpense': value});
  }

  Future<void> setPullToRefreshEnabled(bool value) async {
    _pullToRefreshEnabled = value;
    if (_prefs != null) await _prefs!.setBool('pull_to_refresh', value);
    notifyListeners();
  }

  Future<void> setAnimationsEnabled(bool value) async {
    _animationsEnabled = value;
    if (_prefs != null) await _prefs!.setBool('animations_enabled', value);
    notifyListeners();
  }

  Future<void> setForceDarkMode(bool value) async {
    _forceDarkMode = value;
    if (_prefs != null) await _prefs!.setBool('force_dark_mode', value);
    notifyListeners();
  }

  Future<void> setNotifyOnRecharge(bool value) async {
    _notifyOnRecharge = value;
    notifyListeners();
    await _db.collection('system').doc('main_info').update({'notifyOnRecharge': value});
  }

  Future<void> setNotifyOnCoupon(bool value) async {
    _notifyOnCoupon = value;
    notifyListeners();
    await _db.collection('system').doc('main_info').update({'notifyOnCoupon': value});
  }

  Future<void> setNotifyOnUpdate(bool value) async {
    _notifyOnUpdate = value;
    notifyListeners();
    await _db.collection('system').doc('main_info').update({'notifyOnUpdate': value});
  }

  Future<void> setNotifyOnTicket(bool value) async {
    _notifyOnTicket = value;
    notifyListeners();
    await _db.collection('system').doc('main_info').update({'notifyOnTicket': value});
  }

  // ---------- إعدادات اللغة ----------
  String getLanguageSync() {
    if (_prefs == null) return 'ar';
    return _prefs!.getString('language') ?? 'ar';
  }

  Future<void> saveLanguage(String langCode) async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    await _prefs!.setString('language', langCode);
    notifyListeners();
  }

  Future<void> changeAppLanguage(String langCode) async {
    await saveLanguage(langCode);
    notifyListeners();
  }

  // ---------- إعدادات الطابعة ----------
  Future<void> setPrinterConnected(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('agent_printer_connected', value);
  }

  Future<bool> isPrinterConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('agent_printer_connected') ?? false;
  }
}
