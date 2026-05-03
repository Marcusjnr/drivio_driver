import 'package:flutter/material.dart';

class AppGradients {
  AppGradients._();

  static const LinearGradient avatarA = LinearGradient(
    colors: <Color>[Color(0xFFFF8A65), Color(0xFFF4511E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient avatarB = LinearGradient(
    colors: <Color>[Color(0xFF5C6BC0), Color(0xFF3949AB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient avatarC = LinearGradient(
    colors: <Color>[Color(0xFF26A69A), Color(0xFF00897B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient avatarD = LinearGradient(
    colors: <Color>[Color(0xFFEC407A), Color(0xFFC2185B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient avatarE = LinearGradient(
    colors: <Color>[Color(0xFF7E57C2), Color(0xFF512DA8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient avatarF = LinearGradient(
    colors: <Color>[Color(0xFF29B6F6), Color(0xFF0288D1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<LinearGradient> get avatars => <LinearGradient>[
        avatarA,
        avatarB,
        avatarC,
        avatarD,
        avatarE,
        avatarF,
      ];
}
