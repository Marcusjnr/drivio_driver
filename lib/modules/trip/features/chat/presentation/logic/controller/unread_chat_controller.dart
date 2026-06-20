import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drivio_driver/modules/commons/data/message_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/message.dart';

/// Per-trip unread-message counter behind the chat badges. Counts rider
/// messages newer than a locally persisted last-read mark; opening the
/// chat page resets it via [markAllRead].
class UnreadChatController extends StateNotifier<int> {
  UnreadChatController({
    required String tripId,
    required MessageRepository repo,
    required SupabaseModule supabase,
  }) : _tripId = tripId,
       _repo = repo,
       _supabase = supabase,
       super(0) {
    _start();
  }

  final String _tripId;
  final MessageRepository _repo;
  final SupabaseModule _supabase;

  StreamSubscription<Message>? _sub;
  DateTime _lastRead = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  DateTime? _latestSeen;
  final Set<String> _counted = <String>{};

  String get _prefsKey => 'chat_last_read_$_tripId';

  Future<void> _start() async {
    final String? myId = _supabase.auth.currentUser?.id;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? stored = prefs.getString(_prefsKey);
      if (stored != null) {
        _lastRead = DateTime.tryParse(stored) ?? _lastRead;
      }
      final List<Message> rows = await _repo.listForTrip(_tripId);
      if (!mounted) return;
      for (final Message m in rows) {
        _track(m, myId);
      }
      _sub = _repo.watchForTrip(_tripId, channelKey: 'unread').listen(
        (Message m) {
          if (!mounted) return;
          _track(m, myId);
        },
        // Soft fail — the badge re-hydrates next time the provider
        // is constructed; it must never surface chat-infra errors.
        onError: (Object _, StackTrace _) {},
      );
    } catch (_) {
      // Badge is decorative; a failed hydrate just shows no count.
    }
  }

  void _track(Message m, String? myId) {
    if (_latestSeen == null || m.createdAt.isAfter(_latestSeen!)) {
      _latestSeen = m.createdAt;
    }
    if (m.senderUserId == myId) return;
    if (!m.createdAt.isAfter(_lastRead)) return;
    if (!_counted.add(m.id)) return;
    state = _counted.length;
  }

  /// Everything currently on the trip is read. Anchored to the newest
  /// message's server timestamp (not the device clock) so clock skew
  /// can't resurrect read messages; only ever moves forward.
  Future<void> markAllRead() async {
    final DateTime candidate = _latestSeen ?? DateTime.now().toUtc();
    if (candidate.isAfter(_lastRead)) {
      _lastRead = candidate;
    }
    _counted.clear();
    if (mounted) {
      state = 0;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _lastRead.toIso8601String());
    } catch (_) {
      // Non-fatal: worst case the badge over-counts on next cold start.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Deliberately not autoDispose: the count must survive page hops within
/// a trip (shell → chat → back). Only one trip is live at a time, so the
/// family stays tiny.
final StateNotifierProviderFamily<UnreadChatController, int, String>
unreadChatControllerProvider =
    StateNotifierProvider.family<UnreadChatController, int, String>(
      (Ref ref, String tripId) => UnreadChatController(
        tripId: tripId,
        repo: locator<MessageRepository>(),
        supabase: locator<SupabaseModule>(),
      ),
    );
