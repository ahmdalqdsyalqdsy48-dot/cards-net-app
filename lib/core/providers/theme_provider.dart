import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 

class ThemeProvider extends ChangeNotifier {
  // ==========================================
  // 1. تحديد من هو المستخدم الحالي
  // ==========================================
  String _currentRole = 'guest'; 
  String _currentUserPhone = 'default'; // 👈 مفتاح الحفظ الخاص بكل مستخدم
  late SharedPreferences _prefs; 
  bool _isInitialized = false;

  // 👈 اللون الافتراضي الموحد لجميع المستخدمين عند الدخول لأول مرة (الأبيض)
  static const Color _defaultAppColor = Color(0xFFFFFFFF); 
  
  static const String _defaultFontFamily = 'System'; 
  static const double _defaultFontSizeScale = 1.0; 

  // ==========================================
  // 2. الخزانة المخصصة (User Themes)
  // ==========================================
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
  // ⚙️ هندسة الذاكرة المحلية (جلب وحفظ مخصص لكل مستخدم)
  // ==========================================
  void _loadPreferences() {
    if (!_isInitialized) return;
    
    // 👈 القراءة من الذاكرة بناءً على رقم هاتف المستخدم ليكون المظهر خاصاً به فقط
    _isDark = _prefs.getBool('${_currentUserPhone}_isDark') ?? false;
    int? savedColorValue = _prefs.getInt('${_currentUserPhone}_color');
    _color = savedColorValue != null ? Color(savedColorValue) : _defaultAppColor;
    _fontFamily = _prefs.getString('${_currentUserPhone}_fontFamily') ?? _defaultFontFamily;
    _fontSizeScale = _prefs.getDouble('${_currentUserPhone}_fontSizeScale') ?? _defaultFontSizeScale;
    
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

  // 👈 (الذكاء اللوني): تحديد لون النصوص بناءً على لون الخلفية المختار
  Color get adaptiveTextColor {
    // إذا كانت الخلفية بيضاء أو فاتحة، النص يكون أسود. إذا كانت داكنة، النص أبيض.
    return primaryColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }

  // ==========================================
  // 4. دوال التعديل والكتابة (Setters)
  // ==========================================
  
  // 👈 استدعاء هذه الدالة عند تسجيل الدخول لتفعيل مظهر المستخدم
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

  void changeFontFamily(String font) {
    _fontFamily = font;
    _prefs.setString('${_currentUserPhone}_fontFamily', font);
    notifyListeners();
  }

  void changeFontSizeScale(double scale) {
    _fontSizeScale = scale;
    _prefs.setDouble('${_currentUserPhone}_fontSizeScale', scale);
    notifyListeners();
  }

  void resetToDefault() {
    changeColor(_defaultAppColor);
    changeFontFamily(_defaultFontFamily);
    changeFontSizeScale(_defaultFontSizeScale);
  }
}
