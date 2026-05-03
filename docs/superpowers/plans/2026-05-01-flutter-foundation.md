# Flutter Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the existing 39-screen Flutter prototype to Supabase — real auth, session management, network resilience, app lifecycle, and a bootstrap router gate that decides the landing screen.

**Architecture:** Supabase client initialised in GetIt via a typed `SupabaseModule` facade. Auth is phone OTP (no password). A `BootstrapController` reads auth + profile + subscription state to compute the initial route. A `MutationQueue` with idempotency keys makes all writes survive flaky networks. A `LifecycleController` manages foreground/background transitions. A `SessionGuard` kicks to welcome on token failure.

**Tech Stack:** Flutter, Riverpod (StateNotifier), Supabase Flutter 2.x, SharedPreferences, uuid.

**Existing conventions (MUST follow):**
- All widgets are `ConsumerWidget` / `ConsumerStatefulWidget`
- Colors via `context.bg`, `context.accent`, etc. — never raw `AppColors.*`
- Navigation via `AppNavigation.push/replace/replaceAll/pop` with `AppRoutes.*` constants
- State: `StateNotifier<XxxState>` with manual `copyWith`, top-level providers
- No `freezed`, no `auto_route`, no doc comments unless non-obvious business rule
- No tests (per user instruction)

---

## File Map

### New files
| File | Responsibility |
|------|---------------|
| `commons/config/env.dart` | Compile-time env vars via `String.fromEnvironment` |
| `commons/supabase/supabase_module.dart` | Typed facade over `SupabaseClient` |
| `commons/auth/session_guard.dart` | Listens to auth state, kicks to welcome on failure |
| `commons/bootstrap/bootstrap_destination.dart` | Enum for where the user should land |
| `commons/bootstrap/bootstrap_controller.dart` | Reads auth+profile+subscription, computes destination |
| `commons/lifecycle/lifecycle_controller.dart` | `WidgetsBindingObserver` for foreground/background |
| `commons/network/mutation.dart` | `Mutation` model with status, idempotency key |
| `commons/network/mutation_storage.dart` | SharedPreferences persistence for pending mutations |
| `commons/network/mutation_queue.dart` | `StateNotifier` that queues, retries, drains writes |
| `commons/network/network_client.dart` | Thin wrapper routing edge function calls through queue |

### Modified files
| File | Change |
|------|--------|
| `pubspec.yaml` | Add `uuid` package |
| `commons/config/config.dart` | Add `supabaseUrl`, `supabaseAnonKey` sourced from `Env` |
| `commons/di/di.dart` | Async `Supabase.initialize`, register `SupabaseModule` |
| `main.dart`, `main_prod.dart`, `main_stage.dart` | No changes needed (already `async` + `await setupServiceLocator`) |
| `app.dart` | Mount `LifecycleController`, `SessionGuard`, use `BootstrapController` for initial route |
| `commons/all.dart` | Export new modules |
| `commons/navigation/app_routes.dart` | Add `completeProfile` route |
| `commons/navigation/app_router.dart` | Add `completeProfile` case |
| `authentication/sign_in/.../sign_in_controller.dart` | Wire to `auth.signInWithOtp`, add loading/error state |
| `authentication/sign_in/.../sign_in_page.dart` | Remove password, add loading/error UI |
| `authentication/otp/.../otp_controller.dart` | Wire `verify()` to `auth.verifyOTP`, add phone param |
| `authentication/otp/.../otp_page.dart` | Add loading/error UI, route through bootstrap |
| `authentication/sign_up/.../sign_up_controller.dart` | Wire to Supabase insert for profiles+drivers |
| `authentication/sign_up/.../sign_up_page.dart` | Remove phone/password fields, add loading/error UI |
| `profile/sign_out/.../sign_out_page.dart` | Wire to `auth.signOut()` + cleanup |

---

## Task 1: Environment Config + Supabase Client Bootstrap (DRV-001, DRV-002)

**Files:**
- Create: `lib/modules/commons/config/env.dart`
- Create: `lib/modules/commons/supabase/supabase_module.dart`
- Modify: `lib/modules/commons/config/config.dart`
- Modify: `lib/modules/commons/di/di.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add uuid package to pubspec.yaml**

Add `uuid` under dependencies in `pubspec.yaml`:

```yaml
dependencies:
  # ... existing deps ...
  uuid: ^4.5.1
```

Run: `flutter pub get`

- [ ] **Step 2: Create `env.dart` — compile-time environment variables**

Create `lib/modules/commons/config/env.dart`:

```dart
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'YOUR_SUPABASE_URL',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );

  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  static const String posthogKey = String.fromEnvironment(
    'POSTHOG_KEY',
    defaultValue: '',
  );

  static const String paystackPublicKey = String.fromEnvironment(
    'PAYSTACK_PUBLIC_KEY',
    defaultValue: '',
  );
}
```

- [ ] **Step 3: Update `config.dart` to source Supabase values from Env**

Replace the entire `config.dart` with:

```dart
import 'package:drivio_driver/modules/commons/config/env.dart';
import 'package:drivio_driver/modules/commons/config/flavor.dart';

class Config {
  Config(this.flavor);

  final Flavor flavor;

  String get title {
    switch (flavor) {
      case Flavor.prod:
        return 'Drivio Driver';
      case Flavor.stage:
        return 'Drivio Driver · Stage';
    }
  }

  String get supabaseUrl => Env.supabaseUrl;
  String get supabaseAnonKey => Env.supabaseAnonKey;

  bool get isStage => flavor == Flavor.stage;
}
```

- [ ] **Step 4: Create `supabase_module.dart` — typed facade**

Create `lib/modules/commons/supabase/supabase_module.dart`:

```dart
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
```

- [ ] **Step 5: Update `di.dart` — initialise Supabase, register SupabaseModule**

Replace the entire `di.dart` with:

```dart
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/config/config.dart';
import 'package:drivio_driver/modules/commons/config/flavor.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

final GetIt locator = GetIt.instance;

Future<void> setupServiceLocator(Flavor flavor) async {
  final Config config = Config(flavor);
  locator.registerSingleton<Config>(config);

  assert(
    config.supabaseUrl != 'YOUR_SUPABASE_URL',
    'SUPABASE_URL is not set. Pass it via --dart-define=SUPABASE_URL=<url>',
  );
  assert(
    config.supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY',
    'SUPABASE_ANON_KEY is not set. Pass it via --dart-define=SUPABASE_ANON_KEY=<key>',
  );

  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
    ),
  );

  locator.registerSingleton<SupabaseModule>(SupabaseModule.fromInstance());
}
```

- [ ] **Step 6: Verify**

Run: `flutter analyze`
Expected: 0 errors, 0 warnings (info-level lints OK).

---

## Task 2: Session Guard (DRV-012)

**Files:**
- Create: `lib/modules/commons/auth/session_guard.dart`

- [ ] **Step 1: Create `session_guard.dart`**

Create `lib/modules/commons/auth/session_guard.dart`:

```dart
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/navigation/app_navigation.dart';
import 'package:drivio_driver/modules/commons/navigation/app_routes.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

class SessionGuard {
  SessionGuard() {
    _subscription = locator<SupabaseModule>().auth.onAuthStateChange.listen(
      _onAuthStateChange,
    );
  }

  StreamSubscription<AuthState>? _subscription;

  void _onAuthStateChange(AuthState data) {
    switch (data.event) {
      case AuthChangeEvent.signedOut:
      case AuthChangeEvent.tokenRefreshed when data.session == null:
        AppNavigation.replaceAll<void>(AppRoutes.welcome);
        break;
      default:
        break;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: clean.

---

## Task 3: Bootstrap Controller (DRV-009)

**Files:**
- Create: `lib/modules/commons/bootstrap/bootstrap_destination.dart`
- Create: `lib/modules/commons/bootstrap/bootstrap_controller.dart`

- [ ] **Step 1: Create `bootstrap_destination.dart`**

Create `lib/modules/commons/bootstrap/bootstrap_destination.dart`:

```dart
enum BootstrapDestination {
  welcome,
  completeProfile,
  home,
}
```

- [ ] **Step 2: Create `bootstrap_controller.dart`**

Create `lib/modules/commons/bootstrap/bootstrap_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/bootstrap/bootstrap_destination.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/navigation/app_routes.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

class BootstrapState {
  const BootstrapState({
    this.destination = BootstrapDestination.welcome,
    this.isLoading = true,
  });

  final BootstrapDestination destination;
  final bool isLoading;

  BootstrapState copyWith({
    BootstrapDestination? destination,
    bool? isLoading,
  }) {
    return BootstrapState(
      destination: destination ?? this.destination,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class BootstrapController extends StateNotifier<BootstrapState> {
  BootstrapController() : super(const BootstrapState()) {
    resolve();
  }

  final SupabaseModule _supabase = locator<SupabaseModule>();

  Future<void> resolve() async {
    state = state.copyWith(isLoading: true);

    try {
      final Session? session = _supabase.auth.currentSession;
      if (session == null) {
        state = state.copyWith(
          destination: BootstrapDestination.welcome,
          isLoading: false,
        );
        return;
      }

      final String userId = session.user.id;

      // Check if profile exists
      final List<dynamic> profileRows = await _supabase
          .db('profiles')
          .select('user_id')
          .eq('user_id', userId)
          .limit(1);

      if (profileRows.isEmpty) {
        state = state.copyWith(
          destination: BootstrapDestination.completeProfile,
          isLoading: false,
        );
        return;
      }

      // Profile exists — route to home
      // Future epics will add KYC, vehicle, and subscription checks here
      state = state.copyWith(
        destination: BootstrapDestination.home,
        isLoading: false,
      );
    } catch (_) {
      // On any error, default to welcome
      state = state.copyWith(
        destination: BootstrapDestination.welcome,
        isLoading: false,
      );
    }
  }

  String get initialRoute {
    switch (state.destination) {
      case BootstrapDestination.welcome:
        return AppRoutes.welcome;
      case BootstrapDestination.completeProfile:
        return AppRoutes.signUp;
      case BootstrapDestination.home:
        return AppRoutes.home;
    }
  }
}

final StateNotifierProvider<BootstrapController, BootstrapState>
    bootstrapControllerProvider =
    StateNotifierProvider<BootstrapController, BootstrapState>(
  (Ref _) => BootstrapController(),
);
```

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: clean.

---

## Task 4: Lifecycle Controller (DRV-008)

**Files:**
- Create: `lib/modules/commons/lifecycle/lifecycle_controller.dart`

- [ ] **Step 1: Create `lifecycle_controller.dart`**

Create `lib/modules/commons/lifecycle/lifecycle_controller.dart`:

```dart
import 'package:flutter/widgets.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

class LifecycleController with WidgetsBindingObserver {
  LifecycleController() {
    WidgetsBinding.instance.addObserver(this);
  }

  final SupabaseModule _supabase = locator<SupabaseModule>();
  DateTime? _lastPausedAt;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _onPaused();
        break;
      case AppLifecycleState.resumed:
        _onResumed();
        break;
      default:
        break;
    }
  }

  void _onPaused() {
    _lastPausedAt = DateTime.now();
  }

  void _onResumed() {
    final DateTime? pausedAt = _lastPausedAt;
    _lastPausedAt = null;

    if (pausedAt == null) return;

    final Duration elapsed = DateTime.now().difference(pausedAt);

    // If backgrounded for more than 30 seconds, refresh session
    if (elapsed.inSeconds > 30) {
      _refreshSession();
    }
  }

  Future<void> _refreshSession() async {
    try {
      await _supabase.auth.refreshSession();
    } catch (_) {
      // SessionGuard handles signedOut/tokenRefreshFailed events
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: clean.

---

## Task 5: Network Resilience Layer (DRV-003)

**Files:**
- Create: `lib/modules/commons/network/mutation.dart`
- Create: `lib/modules/commons/network/mutation_storage.dart`
- Create: `lib/modules/commons/network/mutation_queue.dart`
- Create: `lib/modules/commons/network/network_client.dart`

- [ ] **Step 1: Create `mutation.dart` — the mutation model**

Create `lib/modules/commons/network/mutation.dart`:

```dart
import 'dart:convert';

enum MutationStatus { pending, sending, failed, completed }

class Mutation {
  Mutation({
    required this.id,
    required this.idempotencyKey,
    required this.functionName,
    required this.payload,
    this.status = MutationStatus.pending,
    this.retryCount = 0,
    this.error,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String idempotencyKey;
  final String functionName;
  final Map<String, dynamic> payload;
  final MutationStatus status;
  final int retryCount;
  final String? error;
  final DateTime createdAt;

  Mutation copyWith({
    MutationStatus? status,
    int? retryCount,
    String? error,
  }) {
    return Mutation(
      id: id,
      idempotencyKey: idempotencyKey,
      functionName: functionName,
      payload: payload,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      error: error,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'idempotencyKey': idempotencyKey,
      'functionName': functionName,
      'payload': payload,
      'status': status.name,
      'retryCount': retryCount,
      'error': error,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Mutation.fromJson(Map<String, dynamic> json) {
    return Mutation(
      id: json['id'] as String,
      idempotencyKey: json['idempotencyKey'] as String,
      functionName: json['functionName'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map<dynamic, dynamic>),
      status: MutationStatus.values.byName(json['status'] as String),
      retryCount: json['retryCount'] as int,
      error: json['error'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  String encode() => jsonEncode(toJson());

  factory Mutation.decode(String source) =>
      Mutation.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
```

- [ ] **Step 2: Create `mutation_storage.dart` — SharedPreferences persistence**

Create `lib/modules/commons/network/mutation_storage.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drivio_driver/modules/commons/network/mutation.dart';

class MutationStorage {
  static const String _key = 'drivio_mutation_queue';

  Future<List<Mutation>> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_key) ?? <String>[];
    return raw.map((String s) => Mutation.decode(s)).toList();
  }

  Future<void> save(List<Mutation> mutations) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw =
        mutations.where((Mutation m) => m.status != MutationStatus.completed).map((Mutation m) => m.encode()).toList();
    await prefs.setStringList(_key, raw);
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
```

- [ ] **Step 3: Create `mutation_queue.dart` — the queue controller**

Create `lib/modules/commons/network/mutation_queue.dart`:

```dart
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

  List<Mutation> get pending =>
      mutations.where((Mutation m) => m.status == MutationStatus.pending || m.status == MutationStatus.sending).toList();

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
    // Mark as sending
    _updateAt(index, state.mutations[index].copyWith(status: MutationStatus.sending));

    final Mutation mutation = state.mutations[index];
    try {
      await _supabase.functions.invoke(
        mutation.functionName,
        body: mutation.payload,
        headers: <String, String>{
          'Idempotency-Key': mutation.idempotencyKey,
        },
      );

      // Success
      _updateAt(index, mutation.copyWith(status: MutationStatus.completed));
      await _storage.save(state.mutations);
    } catch (e) {
      final bool isClientError = e is FunctionException && e.status != null && e.status! >= 400 && e.status! < 500;

      if (isClientError || mutation.retryCount >= _maxRetries) {
        // Terminal failure
        _updateAt(
          index,
          mutation.copyWith(
            status: MutationStatus.failed,
            error: e.toString(),
            retryCount: mutation.retryCount + 1,
          ),
        );
      } else {
        // Retry with backoff
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
        // Reset to pending for re-processing
        _updateAt(index, state.mutations[index].copyWith(status: MutationStatus.pending));
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
```

- [ ] **Step 4: Create `network_client.dart` — thin wrapper for edge function calls**

Create `lib/modules/commons/network/network_client.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

class NetworkClient {
  NetworkClient();

  static const Uuid _uuid = Uuid();
  final SupabaseModule _supabase = locator<SupabaseModule>();

  /// Call an edge function directly (not queued).
  /// Use this for reads or non-critical writes.
  Future<FunctionResponse> invoke(
    String functionName, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) {
    return _supabase.functions.invoke(
      functionName,
      body: body,
      headers: <String, String>{
        'Idempotency-Key': _uuid.v4(),
        ...?headers,
      },
    );
  }
}
```

- [ ] **Step 5: Verify**

Run: `flutter analyze`
Expected: clean.

---

## Task 6: Wire App — Mount Bootstrap, Lifecycle, SessionGuard (DRV-008, DRV-009, DRV-012)

**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/modules/commons/all.dart`

- [ ] **Step 1: Update `app.dart` — convert to `ConsumerStatefulWidget`, mount infrastructure**

Replace the entire `app.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:drivio_driver/modules/commons/auth/session_guard.dart';
import 'package:drivio_driver/modules/commons/bootstrap/bootstrap_controller.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/lifecycle/lifecycle_controller.dart';
import 'package:drivio_driver/modules/commons/navigation/app_navigation.dart';
import 'package:drivio_driver/modules/commons/navigation/app_router.dart';
import 'package:drivio_driver/modules/commons/theme/app_dimensions.dart';
import 'package:drivio_driver/modules/commons/theme/app_theme.dart';
import 'package:drivio_driver/modules/commons/theme/logic/theme_mode_controller.dart';
import 'package:drivio_driver/modules/commons/config/config.dart' as cfg;

class App extends ConsumerStatefulWidget {
  const App({super.key});

  static void run() => runApp(const ProviderScope(child: App()));

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final LifecycleController _lifecycle;
  late final SessionGuard _sessionGuard;

  @override
  void initState() {
    super.initState();
    _lifecycle = LifecycleController();
    _sessionGuard = SessionGuard();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _sessionGuard.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeMode mode = ref.watch(themeModeProvider);
    final BootstrapState bootstrap = ref.watch(bootstrapControllerProvider);

    if (bootstrap.isLoading) {
      return MaterialApp(
        theme: _withInter(AppTheme.dark),
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return ScreenUtilInit(
      designSize: const Size(
        AppDimensions.designWidth,
        AppDimensions.designHeight,
      ),
      minTextAdapt: true,
      ensureScreenSize: true,
      builder: (BuildContext _, Widget? __) {
        return MaterialApp(
          title: locator.get<cfg.Config>().title,
          theme: _withInter(AppTheme.light),
          darkTheme: _withInter(AppTheme.dark),
          themeMode: mode,
          debugShowCheckedModeBanner: false,
          navigatorKey: AppNavigation.navigatorKey,
          initialRoute: ref.read(bootstrapControllerProvider.notifier).initialRoute,
          onGenerateRoute: AppRouter.onGenerateRoute,
        );
      },
    );
  }

  ThemeData _withInter(ThemeData base) {
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
    );
  }
}
```

- [ ] **Step 2: Update `all.dart` — add new exports**

Add these lines to the end of `lib/modules/commons/all.dart`:

```dart
export 'auth/session_guard.dart';
export 'bootstrap/bootstrap_controller.dart';
export 'bootstrap/bootstrap_destination.dart';
export 'config/env.dart';
export 'lifecycle/lifecycle_controller.dart';
export 'network/mutation.dart';
export 'network/mutation_queue.dart';
export 'network/network_client.dart';
export 'supabase/supabase_module.dart';
```

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: clean.

---

## Task 7: Phone OTP Sign-In (DRV-010)

**Files:**
- Modify: `lib/modules/authentication/features/sign_in/presentation/logic/controller/sign_in_controller.dart`
- Modify: `lib/modules/authentication/features/sign_in/presentation/ui/sign_in_page.dart`
- Modify: `lib/modules/authentication/features/otp/presentation/logic/controller/otp_controller.dart`
- Modify: `lib/modules/authentication/features/otp/presentation/ui/otp_page.dart`

- [ ] **Step 1: Rewrite `sign_in_controller.dart` — wire to Supabase OTP**

Replace the entire file with:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

class SignInState {
  const SignInState({
    this.phone = '',
    this.isLoading = false,
    this.error,
  });

  final String phone;
  final bool isLoading;
  final String? error;

  bool get canSubmit => phone.replaceAll(RegExp(r'\s'), '').length >= 10;

  String get normalizedPhone {
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '+234$digits';
  }

  SignInState copyWith({
    String? phone,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SignInState(
      phone: phone ?? this.phone,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SignInController extends StateNotifier<SignInState> {
  SignInController() : super(const SignInState());

  final SupabaseModule _supabase = locator<SupabaseModule>();

  void onPhoneChanged(String value) =>
      state = state.copyWith(phone: value, clearError: true);

  Future<bool> requestOtp() async {
    if (!state.canSubmit) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _supabase.auth.signInWithOtp(
        phone: state.normalizedPhone,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Couldn\'t send code. Check your connection and try again.',
      );
      return false;
    }
  }
}

final StateNotifierProvider<SignInController, SignInState>
    signInControllerProvider =
    StateNotifierProvider<SignInController, SignInState>(
  (Ref _) => SignInController(),
);
```

- [ ] **Step 2: Rewrite `sign_in_page.dart` — phone-only OTP flow**

Replace the entire file with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/authentication/features/sign_in/presentation/logic/controller/sign_in_controller.dart';
import 'package:drivio_driver/modules/commons/all.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController();
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final SignInController c = ref.read(signInControllerProvider.notifier);
    final bool success = await c.requestOtp();
    if (success && mounted) {
      final String phone = ref.read(signInControllerProvider).normalizedPhone;
      AppNavigation.push(AppRoutes.otp, arguments: phone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SignInState state = ref.watch(signInControllerProvider);
    final SignInController c = ref.read(signInControllerProvider.notifier);
    return ScreenScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 60, 26, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const BrandMark(size: 40),
            const SizedBox(height: 22),
            Text(
              'Welcome back,\ndriver.',
              style: AppTextStyles.screenTitle.copyWith(color: context.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your phone number to sign in.',
              style: AppTextStyles.bodySm.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 26),
            const SectionLabel(text: 'Phone number'),
            const SizedBox(height: 8),
            PhoneNumberInput(
              controller: _phone,
              onChanged: c.onPhoneChanged,
            ),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                state.error!,
                style: TextStyle(color: context.red, fontSize: 13),
              ),
            ],
            const SizedBox(height: 22),
            DrivioButton(
              label: state.isLoading ? 'Sending code…' : 'Continue',
              onPressed: state.canSubmit && !state.isLoading ? _onSubmit : null,
              disabled: !state.canSubmit || state.isLoading,
            ),
            const SizedBox(height: 36),
            Center(
              child: Text(
                'New here? Enter your phone number to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textDim, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Rewrite `otp_controller.dart` — wire verify to Supabase**

Replace the entire file with:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

class OtpState {
  const OtpState({
    this.value = '',
    this.length = 6,
    this.resendSeconds = 30,
    this.phone = '',
    this.isVerifying = false,
    this.error,
  });

  final String value;
  final int length;
  final int resendSeconds;
  final String phone;
  final bool isVerifying;
  final String? error;

  bool get isComplete => value.length == length;
  bool get canResend => resendSeconds == 0;

  OtpState copyWith({
    String? value,
    int? resendSeconds,
    String? phone,
    bool? isVerifying,
    String? error,
    bool clearError = false,
  }) {
    return OtpState(
      value: value ?? this.value,
      length: length,
      resendSeconds: resendSeconds ?? this.resendSeconds,
      phone: phone ?? this.phone,
      isVerifying: isVerifying ?? this.isVerifying,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class OtpController extends StateNotifier<OtpState> {
  OtpController({String phone = ''})
      : super(OtpState(phone: phone)) {
    _startTimer();
  }

  Timer? _timer;
  final SupabaseModule _supabase = locator<SupabaseModule>();

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (state.resendSeconds == 0) {
        t.cancel();
        return;
      }
      state = state.copyWith(resendSeconds: state.resendSeconds - 1);
    });
  }

  Future<void> resend() async {
    if (!state.canResend) return;
    state = state.copyWith(resendSeconds: 30, clearError: true);
    _startTimer();
    try {
      await _supabase.auth.signInWithOtp(phone: state.phone);
    } catch (_) {
      state = state.copyWith(error: 'Failed to resend code. Try again.');
    }
  }

  void setValue(String value) {
    if (value.length > state.length) {
      state = state.copyWith(
        value: value.substring(0, state.length),
        clearError: true,
      );
      return;
    }
    state = state.copyWith(value: value, clearError: true);
  }

  Future<bool> verify() async {
    if (!state.isComplete) return false;

    state = state.copyWith(isVerifying: true, clearError: true);

    try {
      await _supabase.auth.verifyOTP(
        token: state.value,
        phone: state.phone,
        type: OtpType.sms,
      );
      state = state.copyWith(isVerifying: false);
      return true;
    } on AuthException catch (e) {
      String message = e.message;
      if (message.toLowerCase().contains('expired')) {
        message = 'Code expired. Tap resend to get a new one.';
      } else if (message.toLowerCase().contains('invalid')) {
        message = 'Wrong code. Please try again.';
      }
      state = state.copyWith(
        isVerifying: false,
        error: message,
        value: '',
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isVerifying: false,
        error: 'Verification failed. Check your connection.',
        value: '',
      );
      return false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<OtpController, OtpState> otpControllerProvider =
    StateNotifierProvider<OtpController, OtpState>(
  (Ref _) => OtpController(),
);

/// Creates a provider scoped to a specific phone number.
/// Use this when navigating to the OTP page with a phone argument.
StateNotifierProvider<OtpController, OtpState> otpControllerForPhone(
    String phone) {
  return StateNotifierProvider<OtpController, OtpState>(
    (Ref _) => OtpController(phone: phone),
  );
}
```

- [ ] **Step 4: Rewrite `otp_page.dart` — loading/error states, route through bootstrap**

Replace the entire file with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/authentication/features/otp/presentation/logic/controller/otp_controller.dart';
import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/bootstrap/bootstrap_controller.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  StateNotifierProvider<OtpController, OtpState> _provider =
      otpControllerProvider;
  String _phone = '';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final String? phoneArg =
        ModalRoute.of(context)?.settings.arguments as String?;
    if (phoneArg != null && phoneArg.isNotEmpty) {
      _phone = phoneArg;
      _provider = otpControllerForPhone(_phone);
    }
    _initialized = true;
  }

  String get _displayPhone {
    if (_phone.startsWith('+234') && _phone.length >= 14) {
      final String national = _phone.substring(4);
      return '+234 ${national.substring(0, 3)} ${national.substring(3, 6)} ${national.substring(6)}';
    }
    return _phone;
  }

  Future<void> _onVerify() async {
    final OtpController c = ref.read(_provider.notifier);
    final bool success = await c.verify();
    if (success && mounted) {
      final BootstrapController bootstrap =
          ref.read(bootstrapControllerProvider.notifier);
      await bootstrap.resolve();
      if (mounted) {
        AppNavigation.replaceAll<void>(bootstrap.initialRoute);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final OtpState state = ref.watch(_provider);
    final OtpController c = ref.read(_provider.notifier);
    return ScreenScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BackButtonBox(onTap: () => AppNavigation.pop()),
            const SizedBox(height: 22),
            Text(
              'Verify your number.',
              style: AppTextStyles.screenTitleSm.copyWith(color: context.text),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: AppTextStyles.bodySm.copyWith(
                  color: context.textDim,
                  height: 1.5,
                ),
                children: <InlineSpan>[
                  const TextSpan(text: 'We texted a 6-digit code to '),
                  TextSpan(
                    text: _displayPhone,
                    style: TextStyle(
                      color: context.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
            const SizedBox(height: 28),
            PinInput(
              length: state.length,
              initial: state.value,
              onChanged: c.setValue,
            ),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  state.error!,
                  style: TextStyle(color: context.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Center(
              child: GestureDetector(
                onTap: state.canResend ? () => c.resend() : null,
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.caption.copyWith(
                        color: context.textDim),
                    children: <InlineSpan>[
                      const TextSpan(text: "Didn't get it? "),
                      TextSpan(
                        text: state.canResend
                            ? 'Resend now'
                            : 'Resend in 0:${state.resendSeconds.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: state.canResend
                              ? context.accent
                              : context.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            DrivioButton(
              label: state.isVerifying ? 'Verifying…' : 'Verify & continue',
              onPressed: state.isComplete && !state.isVerifying
                  ? _onVerify
                  : null,
              disabled: !state.isComplete || state.isVerifying,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Verify**

Run: `flutter analyze`
Expected: clean.

---

## Task 8: Sign-Up — Complete Profile (DRV-011)

**Files:**
- Modify: `lib/modules/authentication/features/sign_up/presentation/logic/controller/sign_up_controller.dart`
- Modify: `lib/modules/authentication/features/sign_up/presentation/ui/sign_up_page.dart`

- [ ] **Step 1: Rewrite `sign_up_controller.dart` — insert profiles + drivers**

Replace the entire file with:

```dart
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

class SignUpState {
  const SignUpState({
    this.fullName = '',
    this.email = '',
    this.referralCode = '',
    this.isLoading = false,
    this.error,
  });

  final String fullName;
  final String email;
  final String referralCode;
  final bool isLoading;
  final String? error;

  bool get canSubmit => fullName.trim().length >= 2;

  SignUpState copyWith({
    String? fullName,
    String? email,
    String? referralCode,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SignUpState(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      referralCode: referralCode ?? this.referralCode,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SignUpController extends StateNotifier<SignUpState> {
  SignUpController() : super(const SignUpState());

  final SupabaseModule _supabase = locator<SupabaseModule>();

  void onFullNameChanged(String v) =>
      state = state.copyWith(fullName: v, clearError: true);
  void onEmailChanged(String v) =>
      state = state.copyWith(email: v, clearError: true);
  void onReferralChanged(String v) =>
      state = state.copyWith(referralCode: v, clearError: true);

  Future<bool> submit() async {
    if (!state.canSubmit) return false;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      state = state.copyWith(error: 'Session expired. Please sign in again.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final String userId = user.id;
      final String phone = user.phone ?? '';
      final String referralCode = _generateReferralCode();

      // Insert profile
      await _supabase.db('profiles').insert(<String, dynamic>{
        'user_id': userId,
        'full_name': state.fullName.trim(),
        'phone_e164': phone,
        'email': state.email.trim().isEmpty ? null : state.email.trim(),
        'referral_code': referralCode,
        'referred_by': state.referralCode.trim().isEmpty
            ? null
            : state.referralCode.trim(),
      });

      // Insert driver record
      await _supabase.db('drivers').insert(<String, dynamic>{
        'user_id': userId,
        'kyc_status': 'not_started',
      });

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      String message = 'Something went wrong. Please try again.';
      if (e.toString().contains('duplicate') ||
          e.toString().contains('unique')) {
        message = 'Account already exists. Try signing in instead.';
      }
      state = state.copyWith(isLoading: false, error: message);
      return false;
    }
  }

  static String _generateReferralCode() {
    const String chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final Random rng = Random.secure();
    return List<String>.generate(
      6,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
  }
}

final StateNotifierProvider<SignUpController, SignUpState>
    signUpControllerProvider =
    StateNotifierProvider<SignUpController, SignUpState>(
  (Ref _) => SignUpController(),
);
```

- [ ] **Step 2: Rewrite `sign_up_page.dart` — profile completion form (name, email, referral)**

Replace the entire file with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/authentication/features/sign_up/presentation/logic/controller/sign_up_controller.dart';
import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/bootstrap/bootstrap_controller.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  late final TextEditingController _fullName;
  late final TextEditingController _email;
  late final TextEditingController _referral;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController();
    _email = TextEditingController();
    _referral = TextEditingController();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _referral.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final SignUpController c = ref.read(signUpControllerProvider.notifier);
    final bool success = await c.submit();
    if (success && mounted) {
      final BootstrapController bootstrap =
          ref.read(bootstrapControllerProvider.notifier);
      await bootstrap.resolve();
      if (mounted) {
        AppNavigation.replaceAll<void>(bootstrap.initialRoute);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final SignUpState state = ref.watch(signUpControllerProvider);
    final SignUpController c = ref.read(signUpControllerProvider.notifier);
    return ScreenScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                BackButtonBox(onTap: () => AppNavigation.pop()),
                const SizedBox(width: 8),
                Text(
                  'COMPLETE PROFILE',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textMuted,
                    fontFamily: 'monospace',
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              "Let's set up your\ndriver account.",
              style: AppTextStyles.screenTitleSm.copyWith(color: context.text),
            ),
            const SizedBox(height: 6),
            Text(
              'Just a few details to get you started.',
              style: AppTextStyles.caption.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 22),
            DrivioInput(
              label: 'Full name',
              hint: 'Tunde Ogunleye',
              controller: _fullName,
              onChanged: c.onFullNameChanged,
              compact: true,
            ),
            const SizedBox(height: 12),
            DrivioInput(
              label: 'Email (optional)',
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              controller: _email,
              onChanged: c.onEmailChanged,
              compact: true,
            ),
            const SizedBox(height: 12),
            _ReferralCard(
              controller: _referral,
              onChanged: c.onReferralChanged,
            ),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                state.error!,
                style: TextStyle(color: context.red, fontSize: 13),
              ),
            ],
            const SizedBox(height: 22),
            DrivioButton(
              label: state.isLoading ? 'Setting up…' : 'Continue',
              onPressed: state.canSubmit && !state.isLoading ? _onSubmit : null,
              disabled: !state.canSubmit || state.isLoading,
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                "By continuing you agree to Drivio's Driver Agreement & Privacy Policy.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11, color: context.textMuted, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferralCard extends ConsumerWidget {
  const _ReferralCard({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(
          color: context.borderStrong,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('🎁', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Have a referral code?',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Get 1 extra free month on us.',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DrivioInput(
            hint: 'Enter code',
            controller: controller,
            onChanged: onChanged,
            compact: true,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: clean.

---

## Task 9: Logout (DRV-014)

**Files:**
- Modify: `lib/modules/profile/features/sign_out/presentation/ui/sign_out_page.dart`

- [ ] **Step 1: Update `sign_out_page.dart` — wire to auth.signOut + cleanup**

Replace the entire file with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/network/mutation_queue.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/home_controller.dart';

class SignOutPage extends ConsumerStatefulWidget {
  const SignOutPage({super.key});

  @override
  ConsumerState<SignOutPage> createState() => _SignOutPageState();
}

class _SignOutPageState extends ConsumerState<SignOutPage> {
  bool _isLoading = false;

  Future<void> _onSignOut() async {
    final HomeState homeState = ref.read(homeControllerProvider);

    if (homeState.isOnline || homeState.isOnTrip) {
      _showCannotLogoutSheet();
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Clear the mutation queue
      await ref.read(mutationQueueProvider.notifier).clearAll();

      // Sign out from Supabase
      final SupabaseModule supabase = locator<SupabaseModule>();
      await supabase.auth.signOut();

      // SessionGuard will handle navigation to welcome
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCannotLogoutSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Can\'t sign out right now',
                style: AppTextStyles.h2.copyWith(color: context.text),
              ),
              const SizedBox(height: 8),
              Text(
                'You need to go offline and finish any active trips before signing out.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(
                  color: context.textDim,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              DrivioButton(
                label: 'Got it',
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Sign out',
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 30, 10, 20),
          child: Column(
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: context.amber.withValues(alpha: 0.14),
                  border:
                      Border.all(color: context.amber.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: const Text('👋', style: TextStyle(fontSize: 32)),
              ),
              const SizedBox(height: 18),
              Text(
                'Sign out of Drivio?',
                textAlign: TextAlign.center,
                style: AppTextStyles.h1.copyWith(color: context.text),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 280,
                child: Text(
                  "You'll go offline immediately and won't receive any new ride requests until you sign in again.",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: context.textDim,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        DrivioButton(
          label: _isLoading ? 'Signing out…' : 'Yes, sign me out',
          variant: DrivioButtonVariant.danger,
          onPressed: _isLoading ? null : _onSignOut,
          disabled: _isLoading,
        ),
        const SizedBox(height: 8),
        DrivioButton(
          label: 'Stay signed in',
          variant: DrivioButtonVariant.ghost,
          onPressed: _isLoading ? null : () => AppNavigation.pop(),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: clean.

---

## Task 10: Final Verification

- [ ] **Step 1: Run full analysis**

Run: `flutter analyze`
Expected: 0 errors, 0 warnings.

- [ ] **Step 2: Verify the app builds**

Run: `flutter build apk --debug --dart-define=SUPABASE_URL=https://placeholder.supabase.co --dart-define=SUPABASE_ANON_KEY=placeholder-key 2>&1 | tail -5`
Expected: BUILD SUCCESSFUL (the app won't connect but it should compile).

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: wire Flutter foundation to Supabase (DRV-001..003, 008..012, 014)

- Supabase client bootstrap with typed SupabaseModule facade
- Environment config via String.fromEnvironment (dart-define)
- MutationQueue with idempotency keys, exponential backoff, durable persistence
- BootstrapController for auth-state-driven initial routing
- LifecycleController for foreground/background transitions
- SessionGuard for token expiry detection
- Phone OTP sign-in wired to Supabase Auth
- OTP verification with error handling and resend
- Sign-up profile completion (profiles + drivers insert)
- Logout with mutation queue cleanup and online-state guard"
```
