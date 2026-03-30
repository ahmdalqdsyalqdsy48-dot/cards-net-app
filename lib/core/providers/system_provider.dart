import 'package:flutter/material.dart';

// هذا الكلاس يمثل "الخادم المحلي" الذي يربط جميع لوحات التحكم (المدير، الوكيل، المستخدم)
class SystemProvider extends ChangeNotifier {
  // ==========================================
  // 1. بيانات مالك النظام (الإدارة العليا)
  // ==========================================
  double _adminMainBalance = 100000.0; // رصيد النظام الكلي
  int _totalSystemCards = 500; // إجمالي الكروت المتوفرة في المخزن

  // ==========================================
  // 2. بيانات الوكلاء
  // ==========================================
  // قائمة مبسطة تمثل الوكلاء المسجلين في النظام
  final List<Map<String, dynamic>> _agentsList = [
    {'id': 'A1', 'name': 'وكالة الرائد', 'balance': 5000.0, 'status': 'نشط'},
    {'id': 'A2', 'name': 'مؤسسة التقنية', 'balance': 1500.0, 'status': 'نشط'},
  ];

  // ==========================================
  // 3. بيانات المستخدمين (الزبائن)
  // ==========================================
  double _currentUserBalance = 2500.0; // رصيد الزبون الحالي
  final List<String> _userPurchasedCards = []; // سجل مشتريات الزبون

  // ==========================================
  // 4. دوال القراءة (Getters) لعرض البيانات في الشاشات
  // ==========================================
  double get adminMainBalance => _adminMainBalance;
  int get totalSystemCards => _totalSystemCards;
  List<Map<String, dynamic>> get agentsList => _agentsList;
  double get currentUserBalance => _currentUserBalance;
  List<String> get userPurchasedCards => _userPurchasedCards;

  // ==========================================
  // 5. الوظائف التشغيلية والتفاعل بين اللوحات
  // ==========================================

  // وظيفة للإدارة: تحويل رصيد من مالك النظام إلى أحد الوكلاء
  bool transferFromAdminToAgent(String agentId, double amount) {
    if (_adminMainBalance >= amount) {
      _adminMainBalance -= amount; // خصم من الإدارة
      
      // البحث عن الوكيل وإضافة الرصيد له
      for (var agent in _agentsList) {
        if (agent['id'] == agentId) {
          agent['balance'] += amount;
          break;
        }
      }
      notifyListeners(); // تحديث جميع الشاشات
      return true;
    }
    return false;
  }

  // وظيفة للمستخدم: شراء كرت (تخصم من رصيد المستخدم، وتقلل من مخزون النظام)
  bool userBuyCard(double price, String cardName) {
    if (_currentUserBalance >= price && _totalSystemCards > 0) {
      _currentUserBalance -= price; // خصم من المستخدم
      _totalSystemCards -= 1; // سحب كرت من مخزن النظام
      _userPurchasedCards.add(cardName); // إضافة الكرت لملف المستخدم
      
      notifyListeners(); // تحديث جميع الشاشات في نفس اللحظة
      return true;
    }
    return false;
  }
}
