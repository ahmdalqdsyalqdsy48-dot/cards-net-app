import 'package:flutter/material.dart';

// الكلاس ThemeProvider يمثل الآن "الخزانة الذكية" التي تحفظ شكل التطبيق لكل دور بشكل منفصل
// نستخدم ChangeNotifier لكي نتمكن من إشعار الشاشات بأي تغيير يحدث
class ThemeProvider extends ChangeNotifier {
  // ==========================================
  // 1. تحديد من هو المستخدم الحالي
  // ==========================================
  // افتراضياً نجعله المالك، ولكن سنقوم بتغييره برمجياً عند تسجيل الدخول
  String _currentRole = 'super_admin'; 

  // ==========================================
  // 2. الخزانة المخصصة (Role Themes)
  // ==========================================
  // نحفظ هنا إعدادات كل لوحة بشكل منفصل تماماً (كل دور له درج خاص به)
  final Map<String, Map<String, dynamic>> _roleThemes = {
    'super_admin': {'isDark': false, 'color': Colors.blue},        // مظهر المالك
    'agent':       {'isDark': false, 'color': Colors.teal},        // مظهر الوكيل
    'user':        {'isDark': false, 'color': Colors.deepOrange},  // مظهر المستخدم النهائي
  };

  // ==========================================
  // 3. دوال القراءة (Getters) 
  // ==========================================
  // هذه الدوال تسمح للشاشات بمعرفة الحالة الحالية للمستخدم النشط فقط
  
  // هل الوضع الليلي مفعل للمستخدم الحالي؟
  bool get isDarkMode => _roleThemes[_currentRole]!['isDark'];
  
  // ما هو اللون الأساسي للمستخدم الحالي؟
  Color get primaryColor => _roleThemes[_currentRole]!['color'];

  // معرفة الدور الحالي (تفيدنا في البرمجة لاحقاً لمعرفة من يتصفح التطبيق)
  String get currentRole => _currentRole;

  // ==========================================
  // 4. دوال التعديل والكتابة (Setters)
  // ==========================================

  /// هذه الدالة سحرية: نستدعيها عند (تسجيل الدخول) لنخبر النظام من هو المستخدم
  /// لكي يقوم بفتح الدرج الصحيح وجلب ألوانه الخاصة
  void setRole(String role) {
    if (_roleThemes.containsKey(role)) {
      _currentRole = role;
      notifyListeners(); // إشعار الشاشات لتطبيق مظهر هذا الدور فوراً
    }
  }

  /// دالة لتفعيل أو تعطيل الوضع الليلي (تؤثر على درج المستخدم الحالي فقط)
  void toggleTheme(bool isDark) {
    _roleThemes[_currentRole]!['isDark'] = isDark;
    notifyListeners(); // "لقد تغير الوضع، يرجى تحديث الشاشات فوراً!"
  }

  /// دالة لتغيير اللون الأساسي (تؤثر على درج المستخدم الحالي فقط)
  void changeColor(Color color) {
    _roleThemes[_currentRole]!['color'] = color;
    notifyListeners(); // إشعار التطبيق لتحديث كل الأزرار باللون الجديد
  }
}
