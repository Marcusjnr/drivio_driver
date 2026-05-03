import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/message_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/message.dart';

class ChatState {
  const ChatState({
    this.tripId,
    this.messages = const <Message>[],
    this.myUserId,
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  final String? tripId;
  final List<Message> messages;
  final String? myUserId;
  final bool isLoading;
  final bool isSending;
  final String? error;

  ChatState copyWith({
    String? tripId,
    List<Message>? messages,
    String? myUserId,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      tripId: tripId ?? this.tripId,
      messages: messages ?? this.messages,
      myUserId: myUserId ?? this.myUserId,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController({
    required String tripId,
    required MessageRepository repo,
    required SupabaseModule supabase,
  })  : _repo = repo,
        _supabase = supabase,
        super(ChatState(tripId: tripId, isLoading: true)) {
    _start();
  }

  final MessageRepository _repo;
  final SupabaseModule _supabase;
  StreamSubscription<Message>? _sub;

  Future<void> _start() async {
    final User? user = _supabase.auth.currentUser;
    state = state.copyWith(myUserId: user?.id);
    try {
      final List<Message> rows = await _repo.listForTrip(state.tripId!);
      if (!mounted) return;
      state = state.copyWith(messages: rows, isLoading: false);
      _sub = _repo.watchForTrip(state.tripId!).listen(
        (Message m) {
          if (!mounted) return;
          // Skip duplicates (an optimistic insert echoes back through realtime).
          if (state.messages.any((Message x) => x.id == m.id)) return;
          state = state.copyWith(
            messages: <Message>[...state.messages, m],
          );
        },
        onError: (Object _) {/* swallow; refresh covers gaps */},
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load chat: $e',
      );
    }
  }

  Future<void> send(String text, {MessageKind kind = MessageKind.text}) async {
    final String body = text.trim();
    if (body.isEmpty || state.tripId == null) return;
    state = state.copyWith(isSending: true, clearError: true);
    try {
      final Message m =
          await _repo.send(tripId: state.tripId!, body: body, kind: kind);
      if (!mounted) return;
      // Append immediately if the realtime echo hasn't arrived yet.
      final bool already = state.messages.any((Message x) => x.id == m.id);
      state = state.copyWith(
        isSending: false,
        messages: already
            ? state.messages
            : <Message>[...state.messages, m],
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isSending: false,
        error: 'Could not send message.',
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final chatControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatController, ChatState, String>(
  (Ref ref, String tripId) => ChatController(
    tripId: tripId,
    repo: locator<MessageRepository>(),
    supabase: locator<SupabaseModule>(),
  ),
);
