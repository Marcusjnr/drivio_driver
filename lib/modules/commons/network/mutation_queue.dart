import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/network/mutation.dart';
import 'package:drivio_driver/modules/commons/network/mutation_storage.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

class MutationQueueState {
  const MutationQueueState({this.mutations = const <Mutation>[]});

  final List<Mutation> mutations;

  List<Mutation> get pending => mutations
      .where((Mutation m) =>
          m.status == MutationStatus.pending ||
          m.status == MutationStatus.sending)
      .toList();

  List<Mutation> get failed =>
      mutations.where((Mutation m) => m.status == MutationStatus.failed).toList();

  bool get hasPending => pending.isNotEmpty;

  MutationQueueState copyWith({List<Mutation>? mutations}) {
    return MutationQueueState(mutations: mutations ?? this.mutations);
  }
}

class MutationQueueController extends StateNotifier<MutationQueueState> {
  MutationQueueController() : super(const MutationQueueState()) {
    _init();
  }

  static const int _maxRetries = 5;
  static const Uuid _uuid = Uuid();

  final MutationStorage _storage = MutationStorage();
  final SupabaseModule _supabase = locator<SupabaseModule>();
  bool _processing = false;

  Future<void> _init() async {
    final List<Mutation> saved = await _storage.load();
    if (saved.isNotEmpty) {
      state = state.copyWith(mutations: saved);
      _processQueue();
    }
  }

  Future<String> enqueue({
    required String functionName,
    required Map<String, dynamic> payload,
  }) async {
    final String id = _uuid.v4();
    final Mutation mutation = Mutation(
      id: id,
      idempotencyKey: _uuid.v4(),
      functionName: functionName,
      payload: payload,
    );

    state = state.copyWith(
      mutations: <Mutation>[...state.mutations, mutation],
    );
    await _storage.save(state.mutations);
    _processQueue();
    return id;
  }

  Future<void> retry(String mutationId) async {
    final List<Mutation> updated = state.mutations.map((Mutation m) {
      if (m.id == mutationId) {
        return m.copyWith(status: MutationStatus.pending, retryCount: 0);
      }
      return m;
    }).toList();
    state = state.copyWith(mutations: updated);
    await _storage.save(state.mutations);
    _processQueue();
  }

  Future<void> remove(String mutationId) async {
    final List<Mutation> updated =
        state.mutations.where((Mutation m) => m.id != mutationId).toList();
    state = state.copyWith(mutations: updated);
    await _storage.save(state.mutations);
  }

  Future<void> drain() async => _processQueue();

  Future<void> clearAll() async {
    state = state.copyWith(mutations: <Mutation>[]);
    await _storage.clear();
  }

  Future<void> _processQueue() async {
    if (_processing) return;
    _processing = true;

    try {
      while (true) {
        final int idx = state.mutations.indexWhere(
          (Mutation m) => m.status == MutationStatus.pending,
        );
        if (idx == -1) break;

        await _processMutation(idx);
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> _processMutation(int index) async {
    _updateAt(
      index,
      state.mutations[index].copyWith(status: MutationStatus.sending),
    );

    final Mutation mutation = state.mutations[index];
    try {
      await _supabase.functions.invoke(
        mutation.functionName,
        body: mutation.payload,
        headers: <String, String>{
          'Idempotency-Key': mutation.idempotencyKey,
        },
      );

      _updateAt(index, mutation.copyWith(status: MutationStatus.completed));
      await _storage.save(state.mutations);
    } catch (e) {
      final bool isClientError =
          e is FunctionException && e.status >= 400 && e.status < 500;

      if (isClientError || mutation.retryCount >= _maxRetries) {
        _updateAt(
          index,
          mutation.copyWith(
            status: MutationStatus.failed,
            error: e.toString(),
            retryCount: mutation.retryCount + 1,
          ),
        );
      } else {
        final int backoffMs = min(
          60000,
          (pow(2, mutation.retryCount) * 1000).toInt(),
        );
        _updateAt(
          index,
          mutation.copyWith(retryCount: mutation.retryCount + 1),
        );
        await _storage.save(state.mutations);
        await Future<void>.delayed(Duration(milliseconds: backoffMs));
        _updateAt(
          index,
          state.mutations[index].copyWith(status: MutationStatus.pending),
        );
      }
    }
  }

  void _updateAt(int index, Mutation updated) {
    final List<Mutation> list = List<Mutation>.of(state.mutations);
    if (index < list.length) {
      list[index] = updated;
      state = state.copyWith(mutations: list);
    }
  }
}

final StateNotifierProvider<MutationQueueController, MutationQueueState>
    mutationQueueProvider =
    StateNotifierProvider<MutationQueueController, MutationQueueState>(
  (Ref _) => MutationQueueController(),
);
