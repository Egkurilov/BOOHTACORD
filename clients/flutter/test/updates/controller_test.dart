import 'package:boohtacord_desktop/src/features/updates/api.dart';
import 'package:boohtacord_desktop/src/features/updates/controller.dart';
import 'package:boohtacord_desktop/src/features/updates/identity.dart';
import 'package:boohtacord_desktop/src/features/updates/model.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends UpdateApi {
  _Api(this.responses) : super(baseUrl:() => 'https://example.test/api/v1');
  final List<UpdatePolicy> responses;
  @override Future<UpdatePolicy> fetch(UpdateSelector selector) async => responses.removeAt(0);
}

void main() {
  testWidgets('an older catalog response cannot replace accepted policy', (tester) async {
    final api = _Api([
      const UpdatePolicy(revision:5, state:UpdatePolicyState.unconfigured),
      const UpdatePolicy(revision:4, state:UpdatePolicyState.unconfigured),
    ]);
    final identity = NativeUpdateIdentity(
      const LocalUpdateIdentity(releaseId:'android-4',releaseOrder:4,platform:'android'),
      const UpdateSelector.android('arm64'),
      const UpdateEnvironment(osVersion:'15',arch:'arm64'),
    );
    final controller = UpdateController(api:api, identity:identity);
    await controller.check();
    await controller.check();
    expect(controller.policy?.revision, 5);
    expect(controller.lastSuccessfulCheckAt, isNotNull);
    controller.dispose();
  });
}
