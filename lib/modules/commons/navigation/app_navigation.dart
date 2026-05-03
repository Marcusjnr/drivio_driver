import 'package:flutter/material.dart';

class AppNavigation {
  AppNavigation._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static NavigatorState get _nav => navigatorKey.currentState!;

  static Future<T?> push<T extends Object?>(String routeName, {Object? arguments}) {
    return _nav.pushNamed<T>(routeName, arguments: arguments);
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
