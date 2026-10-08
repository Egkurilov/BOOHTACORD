import 'package:flutter/foundation.dart';

import '../../../../core/session/scope.dart';
import '../../../../models.dart';
import '../../../../services/api_client.dart';
import 'effects.dart';
import 'entry.dart';
import 'entries.dart';
export 'load.dart';
export 'open.dart';

class QuickJumpController extends ChangeNotifier {
  QuickJumpController(
    this.api,
    this.scope, {
    required this.readAccount,
    required this.readTopology,
    required this.readDirects,
    required this.effects,
  }) : ticket = scope.capture(),
       account = readAccount();
  final ApiClient api;
  final SessionScope scope;
  final SessionTicket ticket;
  final String? account;
  final String? Function() readAccount;
  final ChannelTopology? Function() readTopology;
  final List<DirectConversation> Function() readDirects;
  final QuickJumpEffects effects;
  final people = <DirectCandidate>[];
  final visited = <String>{};
  String query = '';
  String? nextAfter, error;
  bool loading = false, opening = false, loaded = false, disposed = false;
  int generation = 0;
  bool get admitted =>
      !disposed &&
      ticket.isActive &&
      account != null &&
      readAccount() == account;
  List<QuickJumpEntry> get entries => !admitted
      ? <QuickJumpEntry>[]
      : jumpEntries(
          topology: readTopology(),
          directs: readDirects(),
          people: people,
          self: account,
          query: query,
        );
  bool get canLoad => admitted && !loading && (!loaded || nextAfter != null);
  void setQuery(String value) {
    query = value;
    changed();
  }

  void changed() {
    if (!disposed) notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    generation++;
    people.clear();
    super.dispose();
  }
}
