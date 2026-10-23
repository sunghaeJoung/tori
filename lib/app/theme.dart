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
  static const mutedBadge = Color(0xFFEFEBE5);
  static const keypad = Color(0xFFF6F1EA);

  static const accent = Color(0xFF7A4B22);
  static const accentSoft = Color(0xFFF2E7D9);

  /// 받을 돈.
  static const receive = Color(0xFF1E5BD8);

  /// 줄 돈.
  static const pay = Color(0xFFC42F2F);

  /// 경고 띠(정산을 다시 해주세요 등)의 배경과 글자.
  static const payBackground = Color(0xFFFBE9E9);
  static const payText = Color(0xFF8F1F1F);
  static const danger = Color(0xFFB42626);

  static const acornCap = Color(0xFF5E3B1C);
  static const acornBody = Color(0xFFB57A45);
  static const acornFace = Color(0xFF3A2412);
}

final ThemeData toriTheme = _buildToriTheme();

ThemeData _buildToriTheme() {
  const radius16 = BorderRadius.all(Radius.circular(16));
  const shape16 = RoundedRectangleBorder(borderRadius: radius16);
  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: radius16,
        borderSide: BorderSide(color: color, width: width),
      );

  // M3에서는 Scaffold·AppBar 배경이 surface, 구분선이 outlineVariant를 따른다.
  final base = ThemeData(
    fontFamily: 'Pretendard',
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
      // 카드·다이얼로그·바텀시트 배경. 시드에서 만든 분홍빛 대신 흰색으로.
      surfaceContainerLowest: ToriColors.surface,
      surfaceContainerLow: ToriColors.surface,
      surfaceContainer: ToriColors.surface,
      surfaceContainerHigh: ToriColors.surface,
      surfaceContainerHighest: ToriColors.surface,
    ),
  );

  final t = base.textTheme;
  final text = t.copyWith(
    headlineMedium: t.headlineMedium!.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      height: 1.35,
    ),
    titleLarge: t.titleLarge!.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w800,
    ),
    titleMedium: t.titleMedium!.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w700,
    ),
    bodyLarge: t.bodyLarge!.copyWith(fontSize: 16),
    bodyMedium: t.bodyMedium!.copyWith(fontSize: 15),
    bodySmall: t.bodySmall!.copyWith(fontSize: 13, color: ToriColors.textSub),
    labelLarge: t.labelLarge!.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );

  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    // 주 버튼은 FilledButton, 연한 버튼은 FilledButton.tonal, 보조 버튼은 TextButton.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        // 폭은 부모가 정한다 (BottomActions는 꽉 채움). 무한 폭을 쓰면 Row 안에서 깨진다.
        minimumSize: const Size(64, 56),
        shape: shape16,
        textStyle: text.titleMedium,
        disabledBackgroundColor: ToriColors.disabled,
        disabledForegroundColor: ToriColors.textSub,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ToriColors.accent,
      foregroundColor: ToriColors.surface,
      extendedTextStyle: text.bodyLarge!.copyWith(fontWeight: FontWeight.w700),
      extendedSizeConstraints: const BoxConstraints.tightFor(height: 60),
      shape: const StadiumBorder(),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 52),
        shape: shape16,
        foregroundColor: ToriColors.textMuted,
        textStyle: text.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
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
  );
}
