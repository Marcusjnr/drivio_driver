import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/wallet_repository.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/wallet.dart';

class SupabaseWalletRepository implements WalletRepository {
  SupabaseWalletRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<Wallet?> getMyWallet() async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) return null;
    final List<Map<String, dynamic>> rows = await _supabase
        .db('wallets')
        .select()
        .eq('driver_id', user.id)
        .limit(1);
    if (rows.isEmpty) return null;
    return Wallet.fromJson(rows.first);
  }

  @override
  Future<List<LedgerEntry>> listMyLedger({int limit = 50}) async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) return const <LedgerEntry>[];
    final List<Map<String, dynamic>> rows = await _supabase
        .db('wallet_ledger')
        .select()
        .eq('driver_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(LedgerEntry.fromJson).toList(growable: false);
  }

  @override
  Future<EarningsSummary> getEarningsSummary({int days = 7}) async {
    final List<dynamic> rows = await _supabase.client.rpc<dynamic>(
      'get_my_earnings_summary',
      params: <String, dynamic>{'p_window_days': days},
    ) as List<dynamic>;
    if (rows.isEmpty) {
      return EarningsSummary(
        tripCreditsMinor: 0,
        payoutsMinor: 0,
        netMinor: 0,
        tripCount: 0,
        windowStart:
            DateTime.now().subtract(Duration(days: days)),
      );
    }
    return EarningsSummary.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<List<DailyEarning>> getDailyEarnings({int days = 7}) async {
    final List<dynamic> rows = await _supabase.client.rpc<dynamic>(
      'get_my_daily_earnings',
      params: <String, dynamic>{'p_days': days},
    ) as List<dynamic>;
    return rows
        .map((dynamic r) =>
            DailyEarning.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<MonthlyEarning>> getMonthlyEarnings({int months = 12}) async {
    final List<dynamic> rows = await _supabase.client.rpc<dynamic>(
      'get_my_monthly_earnings',
      params: <String, dynamic>{'p_months': months},
    ) as List<dynamic>;
    return rows
        .map((dynamic r) =>
            MonthlyEarning.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<AcceptanceMetrics> getAcceptanceMetrics({int days = 7}) async {
    final List<dynamic> rows = await _supabase.client.rpc<dynamic>(
      'get_my_acceptance_metrics',
      params: <String, dynamic>{'p_days': days},
    ) as List<dynamic>;
    if (rows.isEmpty) {
      return const AcceptanceMetrics(
        bidsSubmitted: 0,
        bidsWon: 0,
        bidsLost: 0,
        tripsAssigned: 0,
        tripsCompleted: 0,
        tripsCancelledByDriver: 0,
      );
    }
    return AcceptanceMetrics.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Stream<Wallet> watchMyWallet() {
    final User? user = _supabase.auth.currentUser;
    if (user == null) return const Stream<Wallet>.empty();

    final StreamController<Wallet> ctrl = StreamController<Wallet>.broadcast();
    final RealtimeChannel channel = _supabase.client
        .channel('wallets:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'wallets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: user.id,
          ),
          callback: (PostgresChangePayload p) {
            if (p.newRecord.isNotEmpty) {
              ctrl.add(Wallet.fromJson(p.newRecord));
            }
          },
        );
    channel.subscribe();
    ctrl.onCancel = () async {
      await _supabase.client.removeChannel(channel);
      await ctrl.close();
    };
    return ctrl.stream;
  }

  @override
  Stream<LedgerEntry> watchMyLedger() {
    final User? user = _supabase.auth.currentUser;
    if (user == null) return const Stream<LedgerEntry>.empty();

    final StreamController<LedgerEntry> ctrl =
        StreamController<LedgerEntry>.broadcast();
    final RealtimeChannel channel = _supabase.client
        .channel('wallet_ledger:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'wallet_ledger',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: user.id,
          ),
          callback: (PostgresChangePayload p) =>
              ctrl.add(LedgerEntry.fromJson(p.newRecord)),
        );
    channel.subscribe();
    ctrl.onCancel = () async {
      await _supabase.client.removeChannel(channel);
      await ctrl.close();
    };
    return ctrl.stream;
  }
}
