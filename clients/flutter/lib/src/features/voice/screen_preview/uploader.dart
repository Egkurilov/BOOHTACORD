import 'dart:async';
import 'dart:typed_data';

import 'client.dart';

/// Keeps at most one upload in flight and one newest captured frame queued.
class LatestScreenPreviewUploader {
  LatestScreenPreviewUploader(this.client);
  final ScreenPreviewClient client;
  String? _lease, _generation;
  int _epoch = 0, _revision = 0;
  Uint8List? _pending;
  Future<void>? _running, _beginning, _stopping;

  void offer(String lease, Uint8List jpeg) {
    if (!validScreenPreviewJpeg(jpeg)) return;
    if (_lease != lease) _switchLease(lease);
    if (_generation == null && _beginning == null) {
      _beginning = _begin(lease, _epoch);
    }
    _pending = Uint8List.fromList(jpeg);
    _drain();
  }

  void _switchLease(String lease) {
    final oldLease = _lease, oldGeneration = _generation;
    final epoch = ++_epoch;
    _lease = lease;
    _generation = null;
    _revision = 0;
    _pending = null;
    if (oldLease != null && oldGeneration != null) {
      unawaited(client.invalidate(oldLease, oldGeneration).catchError((_) {}));
    }
    _beginning = _begin(lease, epoch);
  }

  Future<void> _begin(String lease, int epoch) async {
    try {
      final generation = await client.begin(lease);
      if (epoch != _epoch || lease != _lease) {
        await client.invalidate(lease, generation).catchError((_) {});
        return;
      }
      _generation = generation;
      _drain();
    } catch (_) {
      // A later four-second capture retries generation creation.
    } finally {
      if (epoch == _epoch) _beginning = null;
    }
  }

  Future<void> stop() {
    final existing = _stopping;
    if (existing != null) return existing;
    final operation = _stop();
    late final Future<void> shared;
    shared = operation.whenComplete(() {
      if (identical(_stopping, shared)) _stopping = null;
    });
    _stopping = shared;
    return shared;
  }

  Future<void> _stop() async {
    final lease = _lease, generation = _generation;
    final epoch = ++_epoch;
    _lease = _generation = null;
    _pending = null;
    final running = _running, beginning = _beginning;
    await running?.catchError((_) {});
    await beginning?.catchError((_) {});
    if (lease != null && generation != null) {
      await client.invalidate(lease, generation).catchError((_) {});
    }
    if (epoch == _epoch) _revision = 0;
  }

  void _drain() {
    if (_running != null || _generation == null || _pending == null) return;
    _running = _uploadLatest().whenComplete(() {
      _running = null;
      _drain();
    });
  }

  Future<void> _uploadLatest() async {
    while (_pending != null && _generation != null) {
      final epoch = _epoch, lease = _lease!, generation = _generation!;
      final jpeg = _pending!;
      _pending = null;
      try {
        await client.upload(lease, generation, ++_revision, jpeg);
      } catch (_) {
        // The next sampled frame is the bounded latest-state retry.
      }
      if (epoch != _epoch) return;
    }
  }
}
