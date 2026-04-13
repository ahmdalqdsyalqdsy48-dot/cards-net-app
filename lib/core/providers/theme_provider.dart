import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 

class ThemeProvider extends ChangeNotifier {
  // ==========================================
  // 1. المتغيرات الأساسية وتحديد الهوية
  // ==========================================
  String _currentRole = 'guest'; 
  String _currentUserPhone = 'default'; // مفتاح الحفظ الخاص بكل مستخدم
  late SharedPreferences _prefs; 
  bool _isInitialized = false;

  // اللون الافتراضي الرسمي للنظام (الأبيض) كما طلبت
  static const Color _defaultAppColor = Color(0xFFFFFFFF); 
  
  static const String _defaultFontFamily = 'Cairo'; 
  static const double _defaultFontSizeScale = 1.0; 

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

  // المتغيرات الحية المستخدمة حالياً في الواجهة
  bool _isDark = false;
  Color _color = _defaultAppColor;
  String _fontFamily = _defaultFontFamily;
  double _fontSizeScale = _defaultFontSizeScale;

  ThemeProvider() {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    _loadPreferences();
  }

  // ==========================================
  // ⚙️ هندسة الذاكرة المحلية (جلب وحفظ مخصص)
  // ==========================================
  void _loadPreferences() {
    if (!_isInitialized) return;
    
    // أولاً: قراءة إعدادات الرتب القديمة لضمان عدم تعطل النظام
    for (String role in _roleThemes.keys) {
      _roleThemes[role]!['isDark'] = _prefs.getBool('${role}_isDark') ?? false;
      int? savedCol = _prefs.getInt('${role}_color');
      if (savedCol != null) _roleThemes[role]!['color'] = Color(savedCol);
    }

    // ثانياً: تحميل إعدادات "المستخدم الحالي" بناءً على رقم هاتفه (التخصيص الفردي)
    _isDark = _prefs.getBool('${_currentUserPhone}_isDark') ?? (_roleThemes[_currentRole]?['isDark'] ?? false);
    int? savedUserColor = _prefs.getInt('${_currentUserPhone}_color');
    _color = savedUserColor != null ? Color(savedUserColor) : (_roleThemes[_currentRole]?['color'] ?? _defaultAppColor);
    
    // 👈 جلب الخطوط والأحجام المخصصة للمستخدم
    _fontFamily = _prefs.getString('${_currentUserPhone}_fontFamily') ?? (_roleThemes[_currentRole]?['fontFamily'] ?? _defaultFontFamily);
    _fontSizeScale = _prefs.getDouble('${_currentUserPhone}_fontSizeScale') ?? (_roleThemes[_currentRole]?['fontSizeScale'] ?? _defaultFontSizeScale);
    
    notifyListeners();
  }

  // ==========================================
  // 3. دوال القراءة (Getters) 
  // ==========================================
  bool get isDarkMode => _isDark;
  Color get primaryColor => _color;
  String get fontFamily => _fontFamily;
  double get fontSizeScale => _fontSizeScale;
  String get currentRole => _currentRole;
  bool get isInitialized => _isInitialized;

  // الذكاء اللوني المطور: يقرأ شدة الإضاءة ويقرر لون النص (أبيض أو أسود) ليكون متجاوباً 100%
  Color get adaptiveTextColor {
    return primaryColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }

  // ==========================================
  // 4. دوال التعديل والكتابة (Setters)
  // ==========================================
  
  void setRole(String role) {
    if (_roleThemes.containsKey(role)) {
      _currentRole = role;
      _loadPreferences(); 
    }
  }

  void setUser(String role, String phone) {
    _currentRole = role;
    _currentUserPhone = phone;
    _loadPreferences(); 
  }

  void toggleTheme(bool isDark) {
    _isDark = isDark;
    _prefs.setBool('${_currentUserPhone}_isDark', isDark);
    notifyListeners(); 
  }

  void changeColor(Color color) {
    _color = color;
    _prefs.setInt('${_currentUserPhone}_color', color.value);
    notifyListeners(); 
  }

  // 👈 التأكد من تطبيق الخطوط فوراً
  void changeFontFamily(String font) {
    _fontFamily = font;
    _prefs.setString('${_currentUserPhone}_fontFamily', font);
    notifyListeners();
  }

  // 👈 التأكد من تطبيق الحجم فوراً
  void changeFontSizeScale(double scale) {
    _fontSizeScale = scale;
    _prefs.setDouble('${_currentUserPhone}_fontSizeScale', scale);
    notifyListeners();
  }

  void resetToDefault() {
    changeColor(_defaultAppColor);
    changeFontFamily(_defaultFontFamily);
    changeFontSizeScale(_defaultFontSizeScale);
    toggleTheme(false);
  }
}
