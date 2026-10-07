import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';

Future<AppState> openChannels(WidgetTester tester, TopologyTestApi api) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 1400);
  final state = AppState(api)..topology = api.current;
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: AdminScreen(state: state))),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('admin-section-tab-channels')));
  await tester.pumpAndSettle();
  expect(
    tester
        .widget<OutlinedButton>(
          find.byKey(const ValueKey('admin-topology-category-up')),
        )
        .onPressed,
    isNull,
  );
  await tester.tap(
    find.byKey(const ValueKey('admin-topology-category:second')),
  );
  await tester.pumpAndSettle();
  return state;
}

class DescriptionTopologyApi extends TopologyTestApi {
  DescriptionTopologyApi() {
    current = const ChannelTopology(
      revision: 1,
      categories: [
        ChannelCategory(
          id: 'first',
          name: 'Основная',
          channels: [
            GuildChannel(
              id: 'text-1',
              name: 'Общее',
              description: 'Старое описание',
              kind: ChannelKind.text,
              admissionClosed: false,
            ),
          ],
        ),
      ],
    );
  }

  String? savedDescription;

  @override
  Future<void> updateChannelDescription({
    required String channelId,
    required String description,
    required int expectedRevision,
  }) async {
    savedDescription = description;
    revisions.add(expectedRevision);
    current = ChannelTopology(
      revision: expectedRevision + 1,
      categories: current.categories
          .map(
            (category) => ChannelCategory(
              id: category.id,
              name: category.name,
              channels: category.channels
                  .map(
                    (channel) => channel.id == channelId
                        ? GuildChannel(
                            id: channel.id,
                            name: channel.name,
                            description: description,
                            kind: channel.kind,
                            admissionClosed: channel.admissionClosed,
                            unreadCount: channel.unreadCount,
                            mentionCount: channel.mentionCount,
                          )
                        : channel,
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }
}
