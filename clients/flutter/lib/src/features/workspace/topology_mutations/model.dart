class TopologyCommandResult {
  const TopologyCommandResult({required this.requestId, required this.revision, required this.resourceId, required this.state});
  final String requestId;
  final int revision;
  final String resourceId;
  final String state;
  factory TopologyCommandResult.fromJson(Map<String, dynamic> json) {
    final result = json['result'];
    if (json['client_request_id'] is! String || json['topology_revision'] is! int || (json['topology_revision'] as int) < 1 || result is! Map<String, dynamic> || result['resource_id'] is! String || result['state'] is! String) throw const FormatException('Некорректный результат команды.');
    return TopologyCommandResult(requestId: json['client_request_id'] as String, revision: json['topology_revision'] as int, resourceId: result['resource_id'] as String, state: result['state'] as String);
  }
}
