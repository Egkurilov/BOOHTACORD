import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/http/transport.dart';
import '../../../models.dart';
import 'model.dart';

class TopologyMutationsApi {
  TopologyMutationsApi(this.transport);
  final ApiTransport transport;
  Future<TopologyCommandResult> _send(String path, String method, Map<String, dynamic> body) async {
    final headers = await transport.headers(jsonBody: true); final encoded = jsonEncode(body); late http.Response response;
    if (method == 'POST') response = await transport.client.post(transport.uri(path), headers: headers, body: encoded);
    else response = await transport.client.delete(transport.uri(path), headers: headers, body: encoded);
    return TopologyCommandResult.fromJson(await transport.checked(response) as Map<String, dynamic>);
  }
  Future<TopologyCommandResult> createCategory(String name, String requestId) => _send('/categories', 'POST', {'name': name, 'client_request_id': requestId});
  Future<TopologyCommandResult> createChannel(String categoryId, String name, ChannelKind kind, String requestId) => _send('/categories/${Uri.encodeComponent(categoryId)}/channels', 'POST', {'name': name, 'kind': kind == ChannelKind.text ? 'TEXT' : 'VOICE', 'client_request_id': requestId});
  Future<TopologyCommandResult> deleteCategory(String id, int revision, String requestId) => _send('/categories/${Uri.encodeComponent(id)}', 'DELETE', {'expected_revision': revision, 'confirm_delete': true, 'client_request_id': requestId});
  Future<TopologyCommandResult> archiveText(String id, int revision, String requestId) => _send('/channels/${Uri.encodeComponent(id)}', 'DELETE', {'expected_revision': revision, 'confirm_archive': true, 'client_request_id': requestId});
  Future<TopologyCommandResult> closeVoice(String id, int revision, String requestId) => _send('/voice-channels/${Uri.encodeComponent(id)}/close-admission', 'POST', {'expected_revision': revision, 'confirm_close': true, 'client_request_id': requestId});
}
