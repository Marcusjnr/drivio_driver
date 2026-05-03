import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x59000000),
      blurRadius: 30,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> sheet = <BoxShadow>[
    BoxShadow(
      color: Color(0x4D000000),
      blurRadius: 40,
      offset: Offset(0, -20),
    ),
  ];

  static const List<BoxShadow> brandMark = <BoxShadow>[
    BoxShadow(
      color: Color(0x4D5EE4A8),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> phoneFrame = <BoxShadow>[
    BoxShadow(
      color: Color(0x80000000),
      blurRadius: 80,
      offset: Offset(0, 30),
    ),
  ];
}
