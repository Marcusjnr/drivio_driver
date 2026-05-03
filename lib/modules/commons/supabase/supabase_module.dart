import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseModule {
  SupabaseModule._(this._client);

  factory SupabaseModule.fromInstance() {
    return SupabaseModule._(Supabase.instance.client);
  }

  final SupabaseClient _client;

  SupabaseClient get client => _client;

  SupabaseQueryBuilder Function(String table) get db => _client.from;

  GoTrueClient get auth => _client.auth;

  SupabaseStorageClient get storage => _client.storage;

  RealtimeClient get realtime => _client.realtime;

  FunctionsClient get functions => _client.functions;
}
