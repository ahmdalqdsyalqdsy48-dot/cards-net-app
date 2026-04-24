import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeProvider extends ChangeNotifier {
  String _currentRole = 'guest';
  String _currentUserPhone = 'default';
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  static const Color _defaultAppColor = Color(0xFFFFFFFF);
  static const String _defaultFontFamily = 'Cairo';
  static const double _defaultFontSizeScale = 1.0;

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

  bool _isDark = false;
  Color _color = _defaultAppColor;
  Color? _userCustomColor;
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

  void _loadPreferences() {
    if (!_isInitialized) return;

    for (String role in _roleThemes.keys) {
      _roleThemes[role]!['isDark'] = _prefs.getBool('${role}_isDark') ?? false;
      int? savedCol = _prefs.getInt('${role}_color');
      if (savedCol != null) _roleThemes[role]!['color'] = Color(savedCol);
    }

    _isDark = _prefs.getBool('${_currentUserPhone}_isDark') ??
        (_roleThemes[_currentRole]?['isDark'] ?? false);

    int? savedBaseColor = _prefs.getInt('${_currentUserPhone}_baseColor');
    _color = savedBaseColor != null
        ? Color(savedBaseColor)
        : (_roleThemes[_currentRole]?['color'] ?? _defaultAppColor);

    int? savedCustomColor = _prefs.getInt('${_currentUserPhone}_customColor');
    _userCustomColor = savedCustomColor != null ? Color(savedCustomColor) : null;

    _fontFamily = _prefs.getString('${_currentUserPhone}_fontFamily') ??
        (_roleThemes[_currentRole]?['fontFamily'] ?? _defaultFontFamily);
    _fontSizeScale = _prefs.getDouble('${_currentUserPhone}_fontSizeScale') ??
        (_roleThemes[_currentRole]?['fontSizeScale'] ?? _defaultFontSizeScale);

    notifyListeners();
  }

  bool get isDarkMode => _isDark;

  Color get primaryColor => _userCustomColor ?? _color;
  Color get activePrimaryColor => primaryColor;

  String get fontFamily => _fontFamily;
  double get fontSizeScale => _fontSizeScale;
  String get currentRole => _currentRole;
  bool get isInitialized => _isInitialized;

  Color get adaptiveTextColor {
    return primaryColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }

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
    if (!isDark) {
      resetToDefaultColor();
    }
    notifyListeners();
  }

  void changeColor(Color color) {
    setUserCustomColor(color);
  }

  void setUserCustomColor(Color color) async {
    _userCustomColor = color;
    await _prefs.setInt('${_currentUserPhone}_customColor', color.value);
    notifyListeners();
  }

  void resetToDefaultColor() async {
    _userCustomColor = null;
    await _prefs.remove('${_currentUserPhone}_customColor');
    notifyListeners();
  }

  Future<void> loadUserCustomColor() async {
    if (!_isInitialized) await _initPrefs();
    _loadPreferences();
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
    resetToDefaultColor();
    changeFontFamily(_defaultFontFamily);
    changeFontSizeScale(_defaultFontSizeScale);
    toggleTheme(false);
  }

  TextTheme _applyFont(TextTheme base, Color textColor) {
    if (_fontFamily == 'System') {
      return base.apply(bodyColor: textColor, displayColor: textColor);
    }
    try {
      return GoogleFonts.getTextTheme(_fontFamily, base)
          .apply(bodyColor: textColor, displayColor: textColor);
    } catch (e) {
      return GoogleFonts.cairoTextTheme(base)
          .apply(bodyColor: textColor, displayColor: textColor);
    }
  }

  ThemeData get lightTheme {
    final base = ThemeData.light();
    final Color activeColor = primaryColor;
    final Color textColor = adaptiveTextColor;

    return base.copyWith(
      primaryColor: activeColor,
      scaffoldBackgroundColor: activeColor.withOpacity(0.05),
      cardColor: Colors.white,
      colorScheme: ColorScheme.light(
        primary: activeColor,
        secondary: activeColor,
        surface: Colors.white,
        background: activeColor.withOpacity(0.05),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: activeColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: Colors.white,
      ),
      textTheme: _applyFont(base.textTheme, textColor),
      iconTheme: IconThemeData(color: textColor),
      listTileTheme: ListTileThemeData(
        iconColor: activeColor,
        textColor: textColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: activeColor,
          foregroundColor: textColor,
        ),
      ),
    );
  }

  ThemeData get darkTheme {
    final base = ThemeData.dark();
    final Color activeColor = primaryColor;

    return base.copyWith(
      primaryColor: activeColor,
      scaffoldBackgroundColor: Color.alphaBlend(
        activeColor.withOpacity(0.4), // ✅ تمت زيادة الشفافية إلى 40% ليكون اللون أكثر وضوحاً
        const Color(0xFF121212),
      ),
      cardColor: Colors.grey.shade900,
      colorScheme: ColorScheme.dark(
        primary: activeColor,
        secondary: activeColor,
        surface: Colors.grey.shade900,
        background: Color.alphaBlend(
            activeColor.withOpacity(0.4), const Color(0xFF121212)), // ✅ تمت زيادة الشفافية إلى 40%
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Color.alphaBlend(
          activeColor.withOpacity(0.4), // ✅ تمت زيادة الشفافية إلى 40%
          const Color(0xFF121212),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: Colors.grey.shade900,
      ),
      textTheme: _applyFont(base.textTheme, Colors.white),
      iconTheme: const IconThemeData(color: Colors.white),
      listTileTheme: ListTileThemeData(
        iconColor: activeColor,
        textColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: activeColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
