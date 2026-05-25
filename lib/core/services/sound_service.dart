import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../providers/settings_provider.dart';

class SoundService {
  final SettingsProvider _settings;
  final AudioPlayer _player = AudioPlayer(); // مشغّل واحد فعّال
  bool _isPlaying = false;

  // التحميل المسبق لجميع الأصوات لتجنب التأخير
  SoundService(this._settings) {
    _preload();
  }

  Future<void> _preload() async {
    final sources = [
      'sounds/click.mp3',
      'sounds/success.mp3',
      'sounds/error.mp3',
      'sounds/warning.mp3',
      'sounds/tap.mp3',
      'sounds/notification.mp3',
    ];
    for (final src in sources) {
      await _player.setSource(AssetSource(src));
    }
  }

  Future<void> play(String type) async {
    if (!_settings.isSoundEnabled) return;

    final assetPath = _getAssetPath(type);
    if (assetPath == null) return;
    final volume = _getVolume(type);

    // إيقاف الصوت الحالي فقط إذا كان قيد التشغيل، ثم تشغيل الجديد
    try {
      await _player.stop();
      await _player.play(AssetSource(assetPath), volume: volume);
    } catch (e) {
      debugPrint('SoundService error ($type): $e');
    }
  }

  String? _getAssetPath(String type) {
    switch (type) {
      case 'click': return 'sounds/click.mp3';
      case 'success': return 'sounds/success.mp3';
      case 'error': return 'sounds/error.mp3';
      case 'warning': return 'sounds/warning.mp3';
      case 'tap': return 'sounds/tap.mp3';
      case 'notification': return 'sounds/notification.mp3';
      default: return null;
    }
  }

  double _getVolume(String type) {
    switch (type) {
      case 'click': return 0.5;
      case 'success': return 1.0;
      case 'error': return 0.8;
      case 'warning': return 0.9;
      case 'tap': return 0.3;
      case 'notification': return 1.0;
      default: return 1.0;
    }
  }

  void dispose() {
    _player.dispose();
  }
}
