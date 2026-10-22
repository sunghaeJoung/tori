import 'package:flutter/material.dart';

/// 프로토타입 캔버스(brown 시안)의 색.
abstract final class ToriColors {
  static const background = Color(0xFFFBF8F3);
  static const surface = Color(0xFFFFFFFF);

  static const text = Color(0xFF1F1A15);
  static const textSub = Color(0xFF6B6259);
  static const textMuted = Color(0xFF4F473F);

  static const border = Color(0xFFE3DACD);
  static const cardBorder = Color(0xFFECE5DA);
  static const divider = Color(0xFFF0EAE1);
  static const tile = Color(0xFFF4EEE6);
  static const disabled = Color(0xFFE6DFD5);

  static const accent = Color(0xFF7A4B22);
  static const accentSoft = Color(0xFFF2E7D9);

  /// 받을 돈.
  static const receive = Color(0xFF1E5BD8);

  /// 줄 돈.
  static const pay = Color(0xFFC42F2F);
  static const danger = Color(0xFFB42626);

  static const acornCap = Color(0xFF5E3B1C);
  static const acornBody = Color(0xFFB57A45);
  static const acornFace = Color(0xFF3A2412);
}

final ThemeData toriTheme = _buildToriTheme();

ThemeData _buildToriTheme() {
  const radius16 = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );
  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: color, width: width),
      );

  final base = ThemeData(
    fontFamily: 'Pretendard',
    scaffoldBackgroundColor: ToriColors.background,
    colorScheme: ColorScheme.fromSeed(seedColor: ToriColors.accent).copyWith(
      primary: ToriColors.accent,
      onPrimary: ToriColors.surface,
      secondaryContainer: ToriColors.accentSoft,
      onSecondaryContainer: ToriColors.accent,
      surface: ToriColors.background,
      onSurface: ToriColors.text,
      error: ToriColors.danger,
      outline: ToriColors.border,
      outlineVariant: ToriColors.divider,
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme
        .copyWith(
          headlineMedium: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
          titleLarge: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
          titleMedium: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: const TextStyle(fontSize: 16),
          bodyMedium: const TextStyle(fontSize: 15),
          bodySmall: const TextStyle(fontSize: 13, color: ToriColors.textSub),
          labelLarge: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ToriColors.textSub,
          ),
        )
        .apply(fontFamily: 'Pretendard'),
    appBarTheme: const AppBarTheme(
      backgroundColor: ToriColors.background,
      foregroundColor: ToriColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: ToriColors.text,
      ),
    ),
    // 주 버튼은 FilledButton, 연한 버튼은 FilledButton.tonal, 보조 버튼은 TextButton.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: radius16,
        textStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        disabledBackgroundColor: ToriColors.disabled,
        disabledForegroundColor: ToriColors.textSub,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 52),
        shape: radius16,
        foregroundColor: ToriColors.textMuted,
        textStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ToriColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      hintStyle: const TextStyle(color: ToriColors.textSub),
      border: inputBorder(ToriColors.border),
      enabledBorder: inputBorder(ToriColors.border),
      focusedBorder: inputBorder(ToriColors.accent, 1.5),
      errorBorder: inputBorder(ToriColors.danger),
    ),
    dividerTheme: const DividerThemeData(
      color: ToriColors.divider,
      thickness: 1,
      space: 1,
    ),
  );
}
