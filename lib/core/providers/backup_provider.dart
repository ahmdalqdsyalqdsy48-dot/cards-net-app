import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BackupProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------- إعدادات النسخ الاحتياطي ----------
  bool _isAutoBackupEnabled = true;
  String _backupFrequency = 'يومياً';
  String _backupTime = '04:00';
  String _emergencyEmail = '';
  bool _isDriveLinked = false;
  bool _isDropboxLinked = false;

  // ---------- قائمة النسخ الاحتياطية ----------
  List<Map<String, dynamic>> _backupsList = [];

  BackupProvider() {
    _initListeners();
  }

  void _initListeners() {
    // مستمع إعدادات النسخ
    _db
        .collection('system')
        .doc('backup_settings')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        _isAutoBackupEnabled = data['isAutoBackupEnabled'] ?? true;
        _backupFrequency = data['backupFrequency'] ?? 'يومياً';
        String rawTime = data['backupTime'] ?? '04:00';
        _backupTime = rawTime.contains(' ') ? '04:00' : rawTime;
        _emergencyEmail = data['emergencyEmail'] ?? '';
        _isDriveLinked = data['isDriveLinked'] ?? false;
        _isDropboxLinked = data['isDropboxLinked'] ?? false;
        notifyListeners();
      }
    });

    // مستمع قائمة النسخ الاحتياطية
    _db
        .collection('backups')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _backupsList = snapshot.docs
          .map((doc) => {'docId': doc.id, ...doc.data()})
          .toList();
      notifyListeners();
    });
  }

  // ---------- Getters ----------
  bool get isAutoBackupEnabled => _isAutoBackupEnabled;
  String get backupFrequency => _backupFrequency;
  String get backupTime => _backupTime;
  String get emergencyEmail => _emergencyEmail;
  bool get isDriveLinked => _isDriveLinked;
  bool get isDropboxLinked => _isDropboxLinked;
  List<Map<String, dynamic>> get backupsList => _backupsList;

  // ---------- دوال التحكم ----------

  /// تحديث إعدادات النسخ التلقائي
  Future<void> updateAutoBackupSettings(
      bool isEnabled, String freq, String time, String email) async {
    await _db.collection('system').doc('backup_settings').update({
      'isAutoBackupEnabled': isEnabled,
      'backupFrequency': freq,
      'backupTime': time,
      'emergencyEmail': email
    });
  }

  /// ربط/إلغاء ربط Google Drive أو Dropbox
  Future<void> toggleCloudLink(String service, bool isLinked) async {
    if (service == 'drive') {
      await _db
          .collection('system')
          .doc('backup_settings')
          .update({'isDriveLinked': isLinked});
    } else if (service == 'dropbox') {
      await _db
          .collection('system')
          .doc('backup_settings')
          .update({'isDropboxLinked': isLinked});
    }
  }

  /// أخذ نسخة احتياطية يدوية
  Future<void> takeManualBackup() async {
    final now = DateTime.now();
    final formattedDate =
        '${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}';

    await _db.collection('backups').add({
      'date': formattedDate,
      'size': '45 MB',
      'type': 'يدوي (محلي)',
      'timestamp': FieldValue.serverTimestamp()
    });

    await _db.collection('system').doc('backup_settings').update({
      'manualTrigger': FieldValue.serverTimestamp(),
    });
  }

  /// حذف نسخة احتياطية
  Future<void> deleteBackup(String docId) async {
    await _db.collection('backups').doc(docId).delete();
  }

  /// تسجيل محاولة استعادة (تستخدمها شاشة الاستعادة)
  Future<void> logRestoreAttempt(bool isSuccess, String backupDate) async {
    try {
      await _db.collection('audit_logs').add({
        'action': isSuccess ? 'استعادة (ناجحة)' : 'استعادة (فاشلة)',
        'details': 'استعادة للنقطة $backupDate',
        'severity': 'critical',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('فشل تسجيل حدث استعادة: $e');
    }
  }
}
