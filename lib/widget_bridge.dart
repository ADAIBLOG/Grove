import 'package:flutter/services.dart';

/// Sends a signal to Android to update all Grove home-screen widgets.
/// The widgets read SharedPreferences directly (same file Flutter writes),
/// so no data needs to pass over the channel; just a "please redraw" ping.
class GroveWidgetBridge {
  GroveWidgetBridge._();
  static final GroveWidgetBridge instance = GroveWidgetBridge._();

  static const _channel = MethodChannel('com.grove.app/widgets');

  /// Call this after any data change (habit added, relapse, reset, etc.)
  Future<void> requestUpdate() async {
    try {
      await _channel.invokeMethod<void>('updateWidgets');
    } on MissingPluginException {
      // Running on iOS or widget plugin not linked; silently ignore.
    } catch (e) {
      // Non-fatal: widgets will update on their 30-min poll anyway.
    }
  }
}
