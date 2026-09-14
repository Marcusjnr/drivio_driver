import 'package:flutter/material.dart';

class AppNavigation {
  AppNavigation._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static NavigatorState get _nav => navigatorKey.currentState!;

  static Future<T?> push<T extends Object?>(String routeName, {Object? arguments}) async {
    // `AppRouter.onGenerateRoute` always builds a `MaterialPageRoute<dynamic>`
    // (its signature can't know a specific caller's expected result type
    // ahead of time), so requesting anything other than a top type here
    // makes the Navigator's internal `route as Route<T>?` cast throw at
    // runtime for any T like `bool` or `String`. Request `Object?` from the
    // Navigator itself — that cast always succeeds — and let the popped
    // value convert to `T?` on return instead.
    final Object? result = await _nav.pushNamed<Object?>(
      routeName,
      arguments: arguments,
    );
    return result as dynamic;
  }

  static Future<T?> replace<T extends Object?, R extends Object?>(
    String routeName, {
    Object? arguments,
    R? result,
  }) {
    return _nav.pushReplacementNamed<T, R>(routeName, arguments: arguments, result: result);
  }

  static Future<T?> replaceAll<T extends Object?>(String routeName, {Object? arguments}) {
    return _nav.pushNamedAndRemoveUntil<T>(
      routeName,
      (Route<dynamic> _) => false,
      arguments: arguments,
    );
  }

  static void pop<T extends Object?>([T? result]) => _nav.pop<T>(result);

  static bool canPop() => _nav.canPop();
}
