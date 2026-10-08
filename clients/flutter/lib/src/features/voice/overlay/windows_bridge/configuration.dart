import 'package:flutter/services.dart';

import '../settings/model.dart';

class OverlayConfigurationBridge {
  OverlayConfigurationBridge(this.channel) {
    channel.setMethodCallHandler(receive);
  }
  final MethodChannel channel;
  OverlayConfiguration current = const OverlayConfiguration();
  int revision = 0;
  bool editing = false, disposed = false;
  void Function(OverlayConfiguration)? onPlacement;
  void Function()? onHotkeyConflict;

  Future<bool> configure(
    OverlayConfiguration value, {
    bool edit = false,
  }) async {
    if (disposed) return false;
    final expected = ++revision;
    current = value;
    editing = edit;
    try {
      final accepted = await channel.invokeMethod<bool>('setConfiguration', {
        ...value.toJson(),
        'editing': edit,
        'revision': expected,
      });
      return !disposed && expected == revision && accepted == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> receive(MethodCall call) async {
    if (disposed || call.arguments is! Map) return;
    final values = Map<String, dynamic>.from(call.arguments as Map);
    if (values['revision'] != revision) return;
    if (call.method == 'hotkeyConflict') {
      onHotkeyConflict?.call();
      return;
    }
    if (call.method != 'placementChanged') return;
    if (values['editing'] is bool) editing = values['editing'] as bool;
    current = OverlayConfiguration.fromJson({
      ...current.toJson(),
      'x': values['x'],
      'y': values['y'],
      'monitor': values['monitor'],
    });
    onPlacement?.call(current);
  }

  void dispose() {
    disposed = true;
    revision++;
    onPlacement = null;
    onHotkeyConflict = null;
    channel.setMethodCallHandler(null);
  }
}
