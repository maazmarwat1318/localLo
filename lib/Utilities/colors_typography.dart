import 'package:flutter/material.dart';

class ColorsTypography {
  static const primaryColor = Color(0xFF4E68FB);
  static const secondaryColor = Color(0xFF7290FB);
  static const primarySelectionColor = Color(0xFF97B2FF);
  static const formInputBackgroundColor = Color(0xFFD7DEF2);
  static const infoBlockColor = Color(0xFFCCD9FF);
  static const warningColor = Color(0xFFDD0101);
  static const messageBubbleColor = Color(0xFFB4C8FF);
  static const hintColor = Color(0xFF565656);

  static const double defaultBodyFont = 18;
  static const double defaultSmallButtonFont = 16;
  static const double defaultLargeButtonFont = 25;
  static const double hintFont = 18;
  static const primaryMainContentBold = FontWeight.bold;
  static const secondaryMainContentBold = FontWeight.w600;

  static const formButtonSize = Size(
    155,
    45,
  );

  static const largeElevatedButtonText = TextStyle(
    fontSize: ColorsTypography.defaultLargeButtonFont,
    fontWeight: FontWeight.bold,
  );
}
