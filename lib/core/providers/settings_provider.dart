import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------- متغيرات الإعدادات العامة ----------
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

  // ---------- متغيرات حالة النظام ----------
  bool _isMaintenanceMode = false;
  bool _isForcedUpdate = false;
  bool _showNewsBar = true;
  bool _isCurrencyAutoRounding = true;
  String _minimumChargeLimit = '1000';
  String _termsAndConditions = '';
  String _supportNumbers = '';

  // ---------- متغيرات المالية العامة ----------
  double _adminMainBalance = 0.0;
  int _totalSystemCards = 0;

  // ---------- متغيرات بوابة الوكلاء ----------
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

  // ---------- متغيرات بوابة المستخدمين ----------
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

  // ---------- أخبار موجهة (شريط الأخبار) ----------
  List<Map<String, dynamic>> _targetedNews = [];
  double _newsScrollSpeed = 40.0;

  // ---------- متنوع ----------
  int _smsBalance = 0;

  // ---------- SharedPreferences للغة والطابعة ----------
  SharedPreferences? _prefs;

  // ---------- المُنشئ مع مستمع Firestore ----------
  SettingsProvider() {
    _initSettingsSync();
    _initPrefs();
  }

  void _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    notifyListeners();
  }

  void _initSettingsSync() {
    _db.collection('system').doc('main_info').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;

        _appName = data['appName'] ?? 'كروت نت';
        _appLogoUrl = data['appLogoUrl'] ?? '';
        _loginBgColor = data['loginBgColor'] ?? 0xFFFFFFFF;
        _loginCarouselImages =
            List<String>.from(data['loginCarouselImages'] ?? []);
        _loginWelcomeMessage =
            data['loginWelcomeMessage'] ?? 'مرحباً بك في نظام كروت نت';
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

        // المفقودين
        _adminMainBalance = (data['adminMainBalance'] ?? 0.0).toDouble();
        _totalSystemCards = data['totalSystemCards'] ?? 0;

        _agentUniversalHiddenSections =
            List<String>.from(data['agentUniversalHiddenSections'] ?? []);
        _hideProfitEnabled = data['hideProfitEnabled'] ?? false;
        _leaderboardEnabled = data['leaderboardEnabled'] ?? false;
        _forceAgentTheme = data['forceAgentTheme'] ?? false;

        _userUniversalHiddenSections =
            List<String>.from(data['userUniversalHiddenSections'] ?? []);
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
          _agentBanners =
              List<Map<String, dynamic>>.from(data['agentBanners']);
        }
        if (data['targetedNews'] != null) {
          _targetedNews =
              List<Map<String, dynamic>>.from(data['targetedNews']);
        }

        _newsScrollSpeed = (data['newsScrollSpeed'] ?? 40.0).toDouble();
        _smsBalance = data['smsBalance'] ?? 0;

        notifyListeners();
      }
    });
  }

  // ---------- Getters ----------
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
  double get newsScrollSpeed => _newsScrollSpeed;
  int get smsBalance => _smsBalance;

  // ---------- دوال التحديث (تكتب إلى Firestore وتُسجل حدثاً) ----------

  Future<void> updateGlobalAppName(String newName) async {
    await _db
        .collection('system')
        .doc('main_info')
        .update({'appName': newName});
    _appName = newName;
    notifyListeners();
    _logAction('تغيير هوية النظام', 'تم تغيير اسم النظام إلى: $newName', 'critical');
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
    _logAction('تحديث بوابة الدخول', 'تحديث المظهر واسم التطبيق', 'critical');
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
    _logAction('تحديث بوابة الوكلاء', 'تم تعديل سياسات لوحة الوكلاء', 'medium');
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
    _logAction('تحديث بوابة المستخدمين', 'تم تعديل سياسات لوحة المستخدمين', 'medium');
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
        batch.update(
            ref, {'hiddenSections': FieldValue.arrayUnion([sectionId])});
      } else {
        batch.update(
            ref, {'hiddenSections': FieldValue.arrayRemove([sectionId])});
      }
    }
    await batch.commit();
    _logAction(
        'استهداف الأقسام',
        'تم ${hide ? "إخفاء" : "إظهار"} قسم $sectionId لعدد ${targetPhones.length} مستخدم',
        'critical');
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
    _logAction('إعلان موجه', 'تم نشر بانر إعلاني بنظام الاستهداف: $targetType', 'normal');
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
    _logAction(
        'تنبيه طوارئ',
        'حالة الطوارئ: $isActive | الاستهداف: $targetType',
        'critical');
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
    await _db
        .collection('system')
        .doc('main_info')
        .update({'newsScrollSpeed': newSpeed});
  }

  // ---------- دوال اللغة ----------
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

  // ---------- دوال الطابعة ----------
  Future<void> setPrinterConnected(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('agent_printer_connected', value);
  }

  Future<bool> isPrinterConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('agent_printer_connected') ?? false;
  }

  // ---------- دالة تسجيل الأحداث ----------
  void _logAction(String action, String details, String severity) {
    try {
      _db.collection('audit_logs').add({
        'action': action,
        'details': details,
        'severity': severity,
        'timestamp': FieldValue.serverTimestamp(),
        'role': 'system',
        'phone': 'settings',
        'name': 'إعدادات النظام',
      });
    } catch (e) {
      debugPrint('فشل تسجيل حدث: $e');
    }
  }
}
