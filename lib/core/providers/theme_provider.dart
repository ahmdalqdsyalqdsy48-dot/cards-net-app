import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 استدعاء مكتبة الحفظ المحلي

class ThemeProvider extends ChangeNotifier {
  // ==========================================
  // 1. تحديد من هو المستخدم الحالي
  // ==========================================
  String _currentRole = 'super_admin'; 
  late SharedPreferences _prefs; // 👈 متغير الذاكرة المحلية
  bool _isInitialized = false;

  // 👈 (جديد) اللون الافتراضي الموحد لجميع المستخدمين عند الدخول لأول مرة
  static const Color _defaultAppColor = Color(0xFF1565C0); // أزرق أنيق

  // ==========================================
  // 2. الخزانة المخصصة الافتراضية (Role Themes)
  // ==========================================
  // 👈 (تحديث) تم توحيد اللون الافتراضي للجميع
  final Map<String, Map<String, dynamic>> _roleThemes = {
    'super_admin': {'isDark': false, 'color': _defaultAppColor},
    'agent':       {'isDark': false, 'color': _defaultAppColor},
    'user':        {'isDark': false, 'color': _defaultAppColor},
  };

  // 👈 عند تشغيل التطبيق، قم بقراءة الذاكرة فوراً
  ThemeProvider() {
    _loadPreferences();
  }

  // ==========================================
  // ⚙️ هندسة الذاكرة المحلية (جلب وحفظ)
  // ==========================================
  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    
    for (String role in _roleThemes.keys) {
      // البحث في الهاتف عن إعدادات سابقة لهذا الدور
      bool? savedIsDark = _prefs.getBool('${role}_isDark');
      int? savedColorValue = _prefs.getInt('${role}_color');

      if (savedIsDark != null) _roleThemes[role]!['isDark'] = savedIsDark;
      if (savedColorValue != null) _roleThemes[role]!['color'] = Color(savedColorValue);
    }
    _isInitialized = true;
    notifyListeners();
  }

  // ==========================================
  // 3. دوال القراءة (Getters) 
  // ==========================================
  bool get isDarkMode => _roleThemes[_currentRole]!['isDark'];
  Color get primaryColor => _roleThemes[_currentRole]!['color'];
  String get currentRole => _currentRole;
  bool get isInitialized => _isInitialized;

  // 💡 🆕 دالة الذكاء اللوني (Contrast AI) - (محدثة لزيادة الوضوح):
  // إذا كان اللون المختار فاتحاً (مثل الأبيض)، سيكون النص أسوداً داكناً جداً.
  Color get adaptiveTextColor {
    return primaryColor.computeLuminance() > 0.45 ? Colors.black87 : Colors.white;
  }

  // ==========================================
  // 4. دوال التعديل والكتابة (Setters)
  // ==========================================
  void setRole(String role) {
    if (_roleThemes.containsKey(role)) {
      _currentRole = role;
      notifyListeners(); 
    }
  }

  void toggleTheme(bool isDark) {
    _roleThemes[_currentRole]!['isDark'] = isDark;
    // 👈 حفظ التعديل في هاتف المستخدم فوراً
    _prefs.setBool('${_currentRole}_isDark', isDark);
    notifyListeners(); 
  }

  void changeColor(Color color) {
    _roleThemes[_currentRole]!['color'] = color;
    // 👈 حفظ رقم اللون في هاتف المستخدم فوراً
    _prefs.setInt('${_currentRole}_color', color.value);
    notifyListeners(); 
  }

  // 👈 (جديد) دالة استعادة اللون الافتراضي
  void resetToDefault() {
    changeColor(_defaultAppColor);
  }
}
