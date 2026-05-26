import 'package:audioplayers/audioplayers.dart';
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
    _clickPool = AudioPool(
      AssetSource('sounds/click.mp3'),
      maxPlayers: 3,
    );
    _successPool = AudioPool(
      AssetSource('sounds/success.mp3'),
      maxPlayers: 2,
    );
    _errorPool = AudioPool(
      AssetSource('sounds/error.mp3'),
      maxPlayers: 2,
    );
    _warningPool = AudioPool(
      AssetSource('sounds/warning.mp3'),
      maxPlayers: 2,
    );
    _tapPool = AudioPool(
      AssetSource('sounds/tap.mp3'),
      maxPlayers: 2,
    );
    _notifPool = AudioPool(
      AssetSource('sounds/notification.mp3'),
      maxPlayers: 2,
    );
  }

  Future<void> play(String type) async {
    if (!_settings.isSoundEnabled) return;

    try {
      switch (type) {
        case 'click':
          await _clickPool.play(volume: 0.5);
          break;
        case 'success':
          await _successPool.play(volume: 1.0);
          break;
        case 'error':
          await _errorPool.play(volume: 0.8);
          break;
        case 'warning':
          await _warningPool.play(volume: 0.9);
          break;
        case 'tap':
          await _tapPool.play(volume: 0.3);
          break;
        case 'notification':
          await _notifPool.play(volume: 1.0);
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
