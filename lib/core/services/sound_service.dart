import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../providers/settings_provider.dart';

class SoundService {
  final SettingsProvider _settings;

  late final AudioPool _clickPool;
  late final AudioPool _successPool;
  late final AudioPool _errorPool;
  late final AudioPool _warningPool;
  late final AudioPool _tapPool;
  late final AudioPool _notifPool;

  SoundService(this._settings) {
    // يتم إنشاء المجموعات الصوتية بشكل غير متزامن، ولكننا نستطيع استدعاء play فوراً
    _clickPool = AudioPool(
      source: AssetSource('sounds/click.mp3'),
      maxPlayers: 4,
      minPlayers: 2,
    );
    _successPool = AudioPool(
      source: AssetSource('sounds/success.mp3'),
      maxPlayers: 3,
      minPlayers: 1,
    );
    _errorPool = AudioPool(
      source: AssetSource('sounds/error.mp3'),
      maxPlayers: 3,
      minPlayers: 1,
    );
    _warningPool = AudioPool(
      source: AssetSource('sounds/warning.mp3'),
      maxPlayers: 3,
      minPlayers: 1,
    );
    _tapPool = AudioPool(
      source: AssetSource('sounds/tap.mp3'),
      maxPlayers: 3,
      minPlayers: 1,
    );
    _notifPool = AudioPool(
      source: AssetSource('sounds/notification.mp3'),
      maxPlayers: 3,
      minPlayers: 1,
    );
  }

  Future<void> play(String type) async {
    if (!_settings.isSoundEnabled) return;

    try {
      switch (type) {
        case 'click':
          await _clickPool.start(volume: 0.5);
          break;
        case 'success':
          await _successPool.start(volume: 1.0);
          break;
        case 'error':
          await _errorPool.start(volume: 0.8);
          break;
        case 'warning':
          await _warningPool.start(volume: 0.9);
          break;
        case 'tap':
          await _tapPool.start(volume: 0.3);
          break;
        case 'notification':
          await _notifPool.start(volume: 1.0);
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('SoundService error ($type): $e');
    }
  }

  void dispose() {
    _clickPool.dispose();
    _successPool.dispose();
    _errorPool.dispose();
    _warningPool.dispose();
    _tapPool.dispose();
    _notifPool.dispose();
  }
}
