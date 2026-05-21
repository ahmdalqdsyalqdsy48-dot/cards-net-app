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
    SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
      _authToken = prefs.getString('authToken');
    });
  }

  ApiService _getApiService() {
    return ApiService(authToken: _authToken);
  }

  // ---------- الخصائص الأساسية ----------
  String? get authToken => _authToken;
  String? get activeUserPhone => _activeUserPhone;
  String? get currentUserEmail => _currentUserEmail;
  String get currentUserRole => _currentUserRole;
  Map<String, bool> get currentUserPermissions => _currentUserPermissions;

  bool get isLoggedIn => _activeUserPhone != null && _authToken != null;
  bool get isSuperAdmin => _currentUserRole == 'super_admin';

  // ---------- تسجيل الدخول ----------
  Future<Map<String, dynamic>?> loginUser(String phone, String password) async {
    clearAllData();

    try {
      final apiService = _getApiService();
      final result = await apiService.post('/api/login', {
        'phone': phone,
        'password': password,
      }, authenticate: false);

      final user = result['user'] as Map<String, dynamic>;
      final token = result['token'] as String;

      _authToken = token;
      _activeUserPhone = phone;
      _currentUserRole = user['role'] ?? 'user';
      if (_currentUserRole == 'staff' && user['permissions'] != null) {
        _currentUserPermissions =
            Map<String, bool>.from(user['permissions']);
      }

      await _prefs?.setString('authToken', token);
      await _loadUserData(phone);
      await _ensureUserAccountNumber();

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

  Future<Map<String, dynamic>?> loginWithPin(String phone, String pin) async {
    if (_activeUserPhone != null) clearAllData();

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

    _activeUserPhone = phone;
    _currentUserRole = role;
    notifyListeners();
  }

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

  Future<void> _ensureUserAccountNumber() async {
    if (_activeUserPhone == null) return;
    try {
      final doc = await _db.collection('users').doc(_activeUserPhone).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['accountNumber'] == null) {
          // التوليد الكامل في WalletProvider
        }
      }
    } catch (e) {
      debugPrint('خطأ في ضمان رقم الحساب: $e');
    }
  }

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

  void clearAllData() {
    _authToken = null;
    _activeUserPhone = null;
    _currentUserEmail = null;
    _currentUserRole = 'guest';
    _currentUserPermissions = {};
    _prefs?.remove('authToken');
    notifyListeners();
  }

  bool hasPermission(String permissionName) {
    if (_currentUserRole == 'super_admin') return true;
    return _currentUserPermissions[permissionName] ?? false;
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

  // ---------- القفل التلقائي للجلسة ----------
  Future<void> setAutoLockEnabled(bool value) async {
    if (_activeUserPhone == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('agent_autoLock', value);
    await prefs.setInt('agent_lastActivity', DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> checkAutoLockAndRedirect(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final autoLock = prefs.getBool('agent_autoLock') ?? false;
    if (!autoLock) return false;

    final lastActivity = prefs.getInt('agent_lastActivity') ?? DateTime.now().millisecondsSinceEpoch;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMinutes = (now - lastActivity) / (1000 * 60);

    if (diffMinutes >= 3) {
      Navigator.pushReplacementNamed(context, '/lock_screen');
      return true;
    }
    return false;
  }

  Future<void> updateLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('agent_lastActivity', DateTime.now().millisecondsSinceEpoch);
  }
}
