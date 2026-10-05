import 'package:flutter/foundation.dart';

class OwnSessionHints extends ChangeNotifier {
  void changed() => notifyListeners();
}
final ownSessionHints = OwnSessionHints();
void notifyOwnSessionsChanged() => ownSessionHints.changed();
