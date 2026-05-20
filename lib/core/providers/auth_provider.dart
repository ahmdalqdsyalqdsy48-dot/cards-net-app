import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _authToken;
  String? _activeUserPhone;
  String? _currentUserEmail;

  String _currentUserRole = 'guest';
  Map<String, bool> _currentUserPermissions = {};

  SharedPreferences? _prefs;

  AuthProvider() {
    // تحميل التوكن المحفوظ من ذاكرة الجهاز عند بدء التشغيل
    SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
      _authToken = prefs.getString('authToken');
      // إذا كان لدينا توكن قديم، يمكننا محاولة استعادة الجلسة
      // (هذا يعتمد على وجود دالة للتحقق من صحة التوكن، سنضيفها لاحقاً)
    });
  }

  // ------------------- دوال الاتصال بالخادم -------------------
  /// دالة مساعدة لإنشاء كائن ApiService بالتوكن الحالي
  ApiService _getApiService() {
    return ApiService(authToken: _authToken);
  }

  // ------------------- الخصائص العامة (Getters) -------------------
  String? get authToken => _authToken;
  String? get activeUserPhone => _activeUserPhone;
  String? get currentUserEmail => _currentUserEmail;
  String get currentUserRole => _currentUserRole;
  Map<String, bool> get currentUserPermissions => _currentUserPermissions;

  /// هل يوجد مستخدم مسجل دخوله حالياً؟
  bool get isLoggedIn => _activeUserPhone != null && _authToken != null;

  /// هل الدور الحالي هو المدير العام؟
  bool get isSuperAdmin => _currentUserRole == 'super_admin';

  // ------------------- دوال تسجيل الدخول -------------------
  Future<Map<String, dynamic>?> loginUser(String phone, String password) async {
    // أولاً نمسح أي بيانات قديمة
    clearAllData();

    try {
      final apiService = _getApiService(); // بدون توكن لأننا نسجل الدخول
      final result = await apiService.post('/api/login', {
        'phone': phone,
        'password': password,
      }, authenticate: false); // تسجيل الدخول لا يحتاج توكن

      final user = result['user'] as Map<String, dynamic>;
      final token = result['token'] as String;

      // تخزين معلومات الجلسة
      _authToken = token;
      _activeUserPhone = phone;
      _currentUserRole = user['role'] ?? 'user';
      if (_currentUserRole == 'staff' && user['permissions'] != null) {
        _currentUserPermissions =
            Map<String, bool>.from(user['permissions']);
      }

      // حفظ التوكن محلياً
      await _prefs?.setString('authToken', token);

      // مزامنة بيانات المستخدم من Firestore
      await _loadUserData(phone);

      // التأكد من وجود رقم حساب للمستخدم (في حال لم يكن موجوداً)
      await _ensureUserAccountNumber();

      // تسجيل الحدث في سجل التدقيق
      await _logAction(
        action: 'تسجيل دخول',
        details: 'تم تسجيل الدخول',
        severity: 'normal',
      );

      notifyListeners();
      return user;
    } catch (e) {
      debugPrint('فشل تسجيل الدخول: $e');
      return null;
    }
  }

  /// تسجيل دخول سريع باستخدام PIN
  Future<Map<String, dynamic>?> loginWithPin(String phone, String pin) async {
    if (_activeUserPhone != null) clearAllData();

    // حساب خاص للاختبار (يفضل نقله لملف .env لاحقاً)
    if (phone == '774578241' && pin == '123456') {
      return loginUser('774578241', '75486958aaa');
    }

    try {
      final doc = await _db.collection('users').doc(phone).get();
      if (!doc.exists) return null;

      final userData = doc.data() as Map<String, dynamic>;
      final storedPin = userData['pin'] ?? '123456';
      if (storedPin == pin) {
        return loginUser(phone, userData['password'] ?? '');
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// تسجيل مستخدم جديد (يرسل البيانات للخادم)
  Future<void> registerNewUser({
    required String name,
    required String phone,
    required String password,
    required String role,
  }) async {
    final apiService = _getApiService();
    await apiService.post('/api/register', {
      'name': name,
      'phone': phone,
      'password': password,
      'role': role,
    }, authenticate: false);

    // بعد التسجيل، يمكننا تفعيل الجلسة
    _activeUserPhone = phone;
    _currentUserRole = role;
    notifyListeners();
  }

  // ------------------- تحميل بيانات المستخدم -------------------
  Future<void> _loadUserData(String phone) async {
    try {
      final doc = await _db.collection('users').doc(phone).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        _currentUserEmail = data['email'];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('خطأ في تحميل بيانات المستخدم: $e');
    }
  }

  // ------------------- التأكد من رقم الحساب (مبسطة) -------------------
  Future<void> _ensureUserAccountNumber() async {
    if (_activeUserPhone == null) return;
    try {
      final doc = await _db.collection('users').doc(_activeUserPhone).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['accountNumber'] == null) {
          // نترك التوليد لـ WalletProvider لاحقاً، هنا نكتفي بالتأكد
          // يمكن استدعاء دالة التوليد من هناك أو تركها كما هي
        }
      }
    } catch (e) {
      debugPrint('خطأ في ضمان رقم الحساب: $e');
    }
  }

  // ------------------- تسجيل أحداث المراقبة -------------------
  Future<void> _logAction({
    required String action,
    required String details,
    required String severity,
    String? targetPhone,
  }) async {
    if (_activeUserPhone == null) return;
    try {
      final userDoc = await _db.collection('users').doc(_activeUserPhone).get();
      final userData = userDoc.data() ?? {};
      final now = DateTime.now();
      final formattedDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      await _db.collection('audit_logs').add({
        'name': userData['name'] ?? 'غير معروف',
        'phone': _activeUserPhone,
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

  // ------------------- تسجيل الخروج -------------------
  void clearAllData() {
    _authToken = null;
    _activeUserPhone = null;
    _currentUserEmail = null;
    _currentUserRole = 'guest';
    _currentUserPermissions = {};
    _prefs?.remove('authToken');
    notifyListeners();
  }

  // ------------------- دوال مساعدة للصلاحيات -------------------
  bool hasPermission(String permissionName) {
    if (_currentUserRole == 'super_admin') return true;
    return _currentUserPermissions[permissionName] ?? false;
  }
}
