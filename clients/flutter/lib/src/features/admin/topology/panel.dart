import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models.dart';
import 'actions.dart';
import 'category_inspector.dart';
import 'channel_inspector.dart';
import 'tree.dart';

export 'tree.dart';

class AdminTopologyPanel extends StatefulWidget {
  const AdminTopologyPanel({super.key, required this.categories, required this.revision, required this.busy, required this.status, required this.error, required this.actions});
  final List<ChannelCategory> categories;
  final int revision;
  final bool busy;
  final String? status, error;
  final TopologyActions actions;
  @override
  State<AdminTopologyPanel> createState() => _AdminTopologyPanelState();
}

class _AdminTopologyPanelState extends State<AdminTopologyPanel> {
  final _inspectorKey = GlobalKey();
  String? _categoryId, _channelId;
  bool _compactDrillIn = false;
  double _panelWidth = 0;
  ChannelCategory? get _category => widget.categories.where((item) => item.id == _categoryId).firstOrNull;
  GuildChannel? get _channel => widget.categories.expand((item) => item.channels).where((item) => item.id == _channelId).firstOrNull;

  @override
  void initState() { super.initState(); _categoryId = widget.categories.firstOrNull?.id; }
  @override
  void didUpdateWidget(covariant AdminTopologyPanel old) {
    super.didUpdateWidget(old);
    final channelParent = widget.categories.where((item) => item.channels.any((channel) => channel.id == _channelId)).firstOrNull;
    if (_channelId != null && channelParent != null) _categoryId = channelParent.id;
    if (_channelId != null && channelParent == null) _channelId = null;
    if (!widget.categories.any((item) => item.id == _categoryId)) _categoryId = widget.categories.firstOrNull?.id;
    if (widget.categories.isEmpty) { _channelId = null; _compactDrillIn = false; }
  }

  void _selectCategory(ChannelCategory category) {
    setState(() { _categoryId = category.id; _channelId = null; _compactDrillIn = _panelWidth <= 720; });
    _scrollToInspector();
  }
  void _selectChannel(GuildChannel channel) {
    final parent = widget.categories.where((item) => item.channels.any((row) => row.id == channel.id)).firstOrNull;
    if (parent == null) return;
    setState(() { _categoryId = parent.id; _channelId = channel.id; _compactDrillIn = _panelWidth <= 720; });
    _scrollToInspector();
  }
  void _createdCategory(String id) {
    final category = widget.categories.where((item) => item.id == id).firstOrNull;
    if (category != null) _selectCategory(category);
  }
  void _scrollToInspector() {
    if (_panelWidth <= 720 || _panelWidth >= 840) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _inspectorKey.currentContext;
      if (mounted && context != null) Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 220), alignment: 0.04);
    });
  }
  void _back() { if (_compactDrillIn) setState(() => _compactDrillIn = false); }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): _back},
    child: Focus(child: LayoutBuilder(builder: (context, constraints) {
      _panelWidth = constraints.maxWidth;
      final workspace = _panelWidth >= 840 ? _desktop() : _panelWidth > 720 ? _stacked() : _compact();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Управление каналами', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        if (widget.status != null) Semantics(liveRegion: true, child: Text(widget.status!, style: const TextStyle(color: Colors.green))),
        if (widget.error != null) Semantics(liveRegion: true, child: Text(widget.error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 12),
        Expanded(child: workspace),
      ]);
    })),
  );

  Widget _desktop() => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Expanded(flex: 3, child: TopologyTree(categories: widget.categories, selectedCategoryId: _categoryId, selectedChannelId: _channelId, busy: widget.busy, onCreateCategory: widget.actions.createCategory, onCategoryCreated: _createdCategory, onCategorySelected: _selectCategory, onChannelSelected: _selectChannel)),
    const SizedBox(width: 16),
    Expanded(flex: 7, child: _inspector(scrollable: true)),
  ]);

  Widget _stacked() => SingleChildScrollView(child: Column(children: [
    SizedBox(height: 340, child: TopologyTree(categories: widget.categories, selectedCategoryId: _categoryId, selectedChannelId: _channelId, busy: widget.busy, onCreateCategory: widget.actions.createCategory, onCategoryCreated: _createdCategory, onCategorySelected: _selectCategory, onChannelSelected: _selectChannel)),
    const SizedBox(height: 16), _inspector(scrollable: false),
  ]));

  Widget _compact() => _compactDrillIn && (_category != null || widget.categories.isEmpty)
      ? Column(children: [Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const ValueKey('admin-topology-back'), onPressed: _back, icon: const Icon(Icons.arrow_back), label: const Text('Назад к структуре'))), Expanded(child: _inspector(scrollable: true))])
      : TopologyTree(categories: widget.categories, selectedCategoryId: _categoryId, selectedChannelId: _channelId, busy: widget.busy, onCreateCategory: widget.actions.createCategory, onCategoryCreated: _createdCategory, onCategorySelected: _selectCategory, onChannelSelected: _selectChannel);

  Widget _inspector({required bool scrollable}) {
    final channel = _channel;
    final category = _category;
    final child = channel != null && category != null
        ? TopologyChannelInspector(key: ValueKey('channel:${channel.id}'), category: category, channel: channel, categories: widget.categories, revision: widget.revision, busy: widget.busy, actions: widget.actions)
        : category != null
        ? TopologyCategoryInspector(key: ValueKey('category:${category.id}'), category: category, categories: widget.categories, revision: widget.revision, busy: widget.busy, actions: widget.actions)
        : const Text('Создайте категорию, чтобы начать работу со структурой каналов.');
    final body = KeyedSubtree(key: _inspectorKey, child: Padding(padding: const EdgeInsets.all(16), child: child));
    return Container(key: const ValueKey('admin-topology-inspector'), width: double.infinity, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(12)), child: scrollable ? SingleChildScrollView(child: body) : body);
  }
}
