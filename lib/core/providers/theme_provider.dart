import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 

class ThemeProvider extends ChangeNotifier {
  // ==========================================
  // 1. تحديد من هو المستخدم الحالي
  // ==========================================
  String _currentRole = 'super_admin'; 
  late SharedPreferences _prefs; 
  bool _isInitialized = false;

  // اللون الافتراضي الموحد لجميع المستخدمين عند الدخول لأول مرة
  static const Color _defaultAppColor = Color(0xFF1565C0); 
  
  // 👈 (جديد) إعدادات الخط الافتراضية
  static const String _defaultFontFamily = 'System'; // الخط الافتراضي للنظام
  static const double _defaultFontSizeScale = 1.0; // الحجم الطبيعي 100%

  // ==========================================
  // 2. الخزانة المخصصة الافتراضية (Role Themes)
  // ==========================================
  final Map<String, Map<String, dynamic>> _roleThemes = {
    'super_admin': {
      'isDark': false, 
      'color': _defaultAppColor, 
      'fontFamily': _defaultFontFamily, 
      'fontSizeScale': _defaultFontSizeScale
    },
    'agent': {
      'isDark': false, 
      'color': _defaultAppColor, 
      'fontFamily': _defaultFontFamily, 
      'fontSizeScale': _defaultFontSizeScale
    },
    'user': {
      'isDark': false, 
      'color': _defaultAppColor, 
      'fontFamily': _defaultFontFamily, 
      'fontSizeScale': _defaultFontSizeScale
    },
  };

  ThemeProvider() {
    _loadPreferences();
  }

  // ==========================================
  // ⚙️ هندسة الذاكرة المحلية (جلب وحفظ)
  // ==========================================
  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    
    for (String role in _roleThemes.keys) {
      bool? savedIsDark = _prefs.getBool('${role}_isDark');
      int? savedColorValue = _prefs.getInt('${role}_color');
      // 👈 جلب إعدادات الخطوط من الذاكرة
      String? savedFontFamily = _prefs.getString('${role}_fontFamily');
      double? savedFontSizeScale = _prefs.getDouble('${role}_fontSizeScale');

      if (savedIsDark != null) _roleThemes[role]!['isDark'] = savedIsDark;
      if (savedColorValue != null) _roleThemes[role]!['color'] = Color(savedColorValue);
      if (savedFontFamily != null) _roleThemes[role]!['fontFamily'] = savedFontFamily;
      if (savedFontSizeScale != null) _roleThemes[role]!['fontSizeScale'] = savedFontSizeScale;
    }
    _isInitialized = true;
    notifyListeners();
  }

  // ==========================================
  // 3. دوال القراءة (Getters) 
  // ==========================================
  bool get isDarkMode => _roleThemes[_currentRole]!['isDark'];
  Color get primaryColor => _roleThemes[_currentRole]!['color'];
  
  // 👈 (جديد) قراءة الخطوط
  String get fontFamily => _roleThemes[_currentRole]!['fontFamily'];
  double get fontSizeScale => _roleThemes[_currentRole]!['fontSizeScale'];
  
  String get currentRole => _currentRole;
  bool get isInitialized => _isInitialized;

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
    _prefs.setBool('${_currentRole}_isDark', isDark);
    notifyListeners(); 
  }

  void changeColor(Color color) {
    _roleThemes[_currentRole]!['color'] = color;
    _prefs.setInt('${_currentRole}_color', color.value);
    notifyListeners(); 
  }

  // 👈 (جديد) تغيير نوع الخط
  void changeFontFamily(String font) {
    _roleThemes[_currentRole]!['fontFamily'] = font;
    _prefs.setString('${_currentRole}_fontFamily', font);
    notifyListeners();
  }

  // 👈 (جديد) تغيير حجم الخط
  void changeFontSizeScale(double scale) {
    _roleThemes[_currentRole]!['fontSizeScale'] = scale;
    _prefs.setDouble('${_currentRole}_fontSizeScale', scale);
    notifyListeners();
  }

  // 👈 استعادة المظهر الافتراضي بالكامل (لون + خطوط)
  void resetToDefault() {
    changeColor(_defaultAppColor);
    changeFontFamily(_defaultFontFamily);
    changeFontSizeScale(_defaultFontSizeScale);
  }
}
