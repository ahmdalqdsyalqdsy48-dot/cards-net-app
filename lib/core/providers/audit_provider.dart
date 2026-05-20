import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuditProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _auditLogs = [];
  StreamSubscription? _auditSub;

  AuditProvider() {
    _startListening();
  }

  void _startListening() {
    _auditSub = _db
        .collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      _auditLogs = snapshot.docs
          .map((doc) => {'docId': doc.id, ...doc.data()})
          .toList();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _auditSub?.cancel();
    super.dispose();
  }

  // ---------- Getters ----------
  List<Map<String, dynamic>> get auditLogs => _auditLogs;

  /// تسجيل حدث جديد في سجل التدقيق (تستخدمه المزودات الأخرى)
  Future<void> logAction({
    required String action,
    required String details,
    required String severity,
    String? targetPhone,
    String? userName,
    String? userPhone,
    String? userRole,
  }) async {
    final now = DateTime.now();
    final formattedDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    try {
      await _db.collection('audit_logs').add({
        'name': userName ?? 'غير معروف',
        'phone': userPhone ?? 'غير معروف',
        'role': userRole ?? 'Unknown',
        'action': action,
        'details': details,
        'datetime': formattedDate,
        'timestamp': FieldValue.serverTimestamp(),
        'ip': 'Cloud System',
        'severity': severity,
        'targetPhone': targetPhone,
      });
    } catch (e) {
      debugPrint('فشل تسجيل حدث تدقيق: $e');
    }
  }
}
