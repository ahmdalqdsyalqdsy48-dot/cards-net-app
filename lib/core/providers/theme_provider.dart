import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeProvider extends ChangeNotifier {
  String _currentRole = 'guest';
  String _currentUserPhone = 'default';
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  static const String _defaultFontFamily = 'Cairo';
  static const double _defaultFontSizeScale = 1.0;

  static const Color _defaultAppColor = Color(0xFF2196F3);

  bool _isDark = false;
  Color _primaryColor = _defaultAppColor;
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

    _isDark = _prefs.getBool('${_currentUserPhone}_isDark') ?? false;

    int? savedBaseColor = _prefs.getInt('${_currentUserPhone}_baseColor');
    _primaryColor = savedBaseColor != null ? Color(savedBaseColor) : _defaultAppColor;

    int? savedCustomColor = _prefs.getInt('${_currentUserPhone}_customColor');
    _userCustomColor = savedCustomColor != null ? Color(savedCustomColor) : null;

    _fontFamily = _prefs.getString('${_currentUserPhone}_fontFamily') ?? _defaultFontFamily;
    _fontSizeScale = _prefs.getDouble('${_currentUserPhone}_fontSizeScale') ?? _defaultFontSizeScale;

    notifyListeners();
  }

  // ---------- Getters ----------
  bool get isDarkMode => _isDark;
  Color get primaryColor => _userCustomColor ?? _primaryColor;
  String get fontFamily => _fontFamily;
  double get fontSizeScale => _fontSizeScale;
  bool get isInitialized => _isInitialized;

  // ---------- Setters ----------
  void setRole(String role) {
    _currentRole = role;
    _loadPreferences();
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
    _userCustomColor = color;
    _prefs.setInt('${_currentUserPhone}_customColor', color.value);
    notifyListeners();
  }

  void resetToDefaultColor() async {
    _userCustomColor = null;
    await _prefs.remove('${_currentUserPhone}_customColor');
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

  // ---------- دوال التوافق ----------
  Color get adaptiveTextColor {
    final colors = _buildTheme(_isDark ? Brightness.dark : Brightness.light).colorScheme;
    return colors.onSurface;
  }

  void setUserCustomColor(Color color) {
    changeColor(color);
  }

  void resetToDefault() {
    resetToDefaultColor();
    changeFontFamily(_defaultFontFamily);
    changeFontSizeScale(_defaultFontSizeScale);
    toggleTheme(false);
  }

  // ---------- بناء الثيمات ----------
  ThemeData get lightTheme => _buildTheme(Brightness.light);
  ThemeData get darkTheme => _buildTheme(Brightness.dark);

  ThemeData _buildTheme(Brightness brightness) {
    final Color activeColor = primaryColor;
    final bool isDark = brightness == Brightness.dark;

    // --- بناء ColorScheme مخصص بقوة ---
    // خلفية التطبيق: ندمج اللون الأساسي بقوة مع الأبيض/الأسود
    final Color scaffoldBg = Color.alphaBlend(
      activeColor.withOpacity(isDark ? 0.35 : 0.25),
      isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
    );
    // سطح البطاقات والقوائم: أفتح قليلاً
    final Color surface = Color.alphaBlend(
      activeColor.withOpacity(isDark ? 0.25 : 0.15),
      isDark ? const Color(0xFF1E1E1E) : Colors.white,
    );
    // الحاوية الأساسية
    final Color primaryContainer = isDark
        ? Color.alphaBlend(activeColor.withOpacity(0.5), const Color(0xFF2C2C2C))
        : Color.alphaBlend(activeColor.withOpacity(0.3), Colors.white);

    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: activeColor,
      brightness: brightness,
    ).copyWith(
      surface: surface,
      surfaceContainerLowest: scaffoldBg,
      surfaceContainer: surface,
      primaryContainer: primaryContainer,
      onPrimaryContainer: isDark ? Colors.white : (activeColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white),
      onSurface: isDark ? Colors.white : Colors.black87,
      onSurfaceVariant: isDark ? Colors.white70 : Colors.black54,
      outlineVariant: isDark ? Colors.white24 : Colors.black12,
    );

    final base = ThemeData(useMaterial3: true, brightness: brightness);
    TextTheme textTheme = _applyFont(base.textTheme, colorScheme.onSurface);

    return base.copyWith(
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 0,
      ),
      drawerTheme: DrawerThemeData(backgroundColor: surface),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        textColor: colorScheme.onSurface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.onPrimaryContainer,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceVariant,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(color: colorScheme.onSurface),
        secondaryLabelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colorScheme.outline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colorScheme.outline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colorScheme.primary, width: 2)),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.6)),
      ),
      dividerColor: colorScheme.outlineVariant,
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: colorScheme.primary,
        collapsedIconColor: colorScheme.onSurfaceVariant,
      ),
    );
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
}
