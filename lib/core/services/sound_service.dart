import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../providers/settings_provider.dart';

class SoundService {
  final SettingsProvider _settings;

  // مشغلات متعددة كما في النظام القديم
  final List<AudioPlayer> _clickPlayers = [];
  final List<AudioPlayer> _successPlayers = [];
  final List<AudioPlayer> _errorPlayers = [];
  final List<AudioPlayer> _warningPlayers = [];
  final List<AudioPlayer> _tapPlayers = [];
  final List<AudioPlayer> _notifPlayers = [];

  int _clickIdx = 0, _succIdx = 0, _errIdx = 0, _warnIdx = 0, _tapIdx = 0, _notifIdx = 0;

  SoundService(this._settings) {
    _initPlayers();
  }

  void _initPlayers() {
    // 3 مشغلات للنقر، 2 للبقية
    for (int i = 0; i < 3; i++) {
      _clickPlayers.add(AudioPlayer());
    }
    for (int i = 0; i < 2; i++) {
      _successPlayers.add(AudioPlayer());
      _errorPlayers.add(AudioPlayer());
      _warningPlayers.add(AudioPlayer());
      _tapPlayers.add(AudioPlayer());
      _notifPlayers.add(AudioPlayer());
    }
  }

  Future<void> play(String type) async {
    // ✅ قراءة إعداد الصوت في كل مرة (ليس مرة واحدة)
    bool soundEnabled = true;
    try {
      soundEnabled = _settings.isSoundEnabled;
    } catch (_) {
      // إذا لم تكن الإعدادات جاهزة، نفترض أن الصوت مفعّل
      soundEnabled = true;
    }
    if (!soundEnabled) return;

    AudioPlayer? player;
    String assetPath;
    double volume;

    switch (type) {
      case 'click':
        player = _clickPlayers[_clickIdx % _clickPlayers.length];
        _clickIdx++;
        assetPath = 'sounds/click.mp3';
        volume = 0.5;
        break;
      case 'success':
        player = _successPlayers[_succIdx % _successPlayers.length];
        _succIdx++;
        assetPath = 'sounds/success.mp3';
        volume = 1.0;
        break;
      case 'error':
        player = _errorPlayers[_errIdx % _errorPlayers.length];
        _errIdx++;
        assetPath = 'sounds/error.mp3';
        volume = 0.8;
        break;
      case 'warning':
        player = _warningPlayers[_warnIdx % _warningPlayers.length];
        _warnIdx++;
        assetPath = 'sounds/warning.mp3';
        volume = 0.9;
        break;
      case 'tap':
        player = _tapPlayers[_tapIdx % _tapPlayers.length];
        _tapIdx++;
        assetPath = 'sounds/tap.mp3';
        volume = 0.3;
        break;
      case 'notification':
        player = _notifPlayers[_notifIdx % _notifPlayers.length];
        _notifIdx++;
        assetPath = 'sounds/notification.mp3';
        volume = 1.0;
        break;
      default:
        return;
    }

    try {
      await player.stop(); // إيقاف السابق
      await player.play(AssetSource(assetPath), volume: volume);
    } catch (e) {
      debugPrint('SoundService error ($type): $e');
    }
  }

  void dispose() {
    for (final list in [_clickPlayers, _successPlayers, _errorPlayers, _warningPlayers, _tapPlayers, _notifPlayers]) {
      for (final p in list) p.dispose();
    }
  }
}
