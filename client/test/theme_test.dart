import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asistiq_client/shared/theme/colors.dart';
import 'package:asistiq_client/shared/theme/spacing.dart';
import 'package:asistiq_client/shared/theme/theme.dart';

void main() {
  group('Stitch Obsidian Design System Tokens', () {
    test('Dark theme contains correct Obsidian surface and primary colors', () {
      final dark = AppTheme.darkTheme;
      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, AppColors.backgroundDark);
      expect(dark.colorScheme.primary, AppColors.primary);
      expect(dark.colorScheme.surface, AppColors.surfaceDark);
    });

    test('Light theme contains clean surface and primary colors', () {
      final light = AppTheme.lightTheme;
      expect(light.brightness, Brightness.light);
      expect(light.scaffoldBackgroundColor, AppColors.backgroundLight);
      expect(light.colorScheme.primary, AppColors.primary);
    });

    test('AppSpacing contains 4px grid tokens and standard breakpoints', () {
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 12.0);
      expect(AppSpacing.base, 16.0);
      expect(AppSpacing.breakpointMobile, 600.0);
      expect(AppSpacing.breakpointTablet, 1024.0);
    });

    test('Priority SLA and Risk colors are properly defined', () {
      expect(AppColors.p1Critical, const Color(0xFFEF4444));
      expect(AppColors.p2High, const Color(0xFFF59E0B));
      expect(AppColors.p3Medium, const Color(0xFF3B82F6));
      expect(AppColors.p4Low, const Color(0xFF10B981));
      expect(AppColors.riskCritical, const Color(0xFFEF4444));
    });
  });
}
