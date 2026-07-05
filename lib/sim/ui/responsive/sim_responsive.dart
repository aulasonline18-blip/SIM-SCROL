import 'package:flutter/widgets.dart';

enum SimWindowClass { compact, medium, expanded, large, extraLarge }

class SimResponsiveBreakpoints {
  const SimResponsiveBreakpoints._();

  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;
  static const double extraLarge = 1600;

  static const double mediumHeight = 480;
  static const double expandedHeight = 900;
}

class SimResponsiveMaxWidth {
  const SimResponsiveMaxWidth._();

  static const double compact = double.infinity;
  static const double text = 680;
  static const double conversation = 720;
  static const double page = 840;
  static const double tabletFrame = 840;
  static const double expandedFrame = 1120;
  static const double largeFrame = 1200;
}

class SimResponsive {
  const SimResponsive._();

  static SimWindowClass widthClassFor(double width) {
    if (width >= SimResponsiveBreakpoints.extraLarge) {
      return SimWindowClass.extraLarge;
    }
    if (width >= SimResponsiveBreakpoints.large) {
      return SimWindowClass.large;
    }
    if (width >= SimResponsiveBreakpoints.expanded) {
      return SimWindowClass.expanded;
    }
    if (width >= SimResponsiveBreakpoints.medium) {
      return SimWindowClass.medium;
    }
    return SimWindowClass.compact;
  }

  static SimWindowClass heightClassFor(double height) {
    if (height >= SimResponsiveBreakpoints.expandedHeight) {
      return SimWindowClass.expanded;
    }
    if (height >= SimResponsiveBreakpoints.mediumHeight) {
      return SimWindowClass.medium;
    }
    return SimWindowClass.compact;
  }

  static bool isCompact(double width) =>
      widthClassFor(width) == SimWindowClass.compact;

  static bool isMediumOrLarger(double width) =>
      width >= SimResponsiveBreakpoints.medium;

  static bool isExpandedOrLarger(double width) =>
      width >= SimResponsiveBreakpoints.expanded;

  static bool hasCompactHeight(double height) =>
      heightClassFor(height) == SimWindowClass.compact;

  static double frameMaxWidthFor(double width) {
    return switch (widthClassFor(width)) {
      SimWindowClass.compact => SimResponsiveMaxWidth.compact,
      SimWindowClass.medium => SimResponsiveMaxWidth.tabletFrame,
      SimWindowClass.expanded => SimResponsiveMaxWidth.expandedFrame,
      SimWindowClass.large ||
      SimWindowClass.extraLarge => SimResponsiveMaxWidth.largeFrame,
    };
  }

  static double contentMaxWidthFor(
    double width, {
    double compact = SimResponsiveMaxWidth.compact,
    double medium = SimResponsiveMaxWidth.text,
    double expanded = SimResponsiveMaxWidth.conversation,
    double large = SimResponsiveMaxWidth.page,
  }) {
    return switch (widthClassFor(width)) {
      SimWindowClass.compact => compact,
      SimWindowClass.medium => medium,
      SimWindowClass.expanded => expanded,
      SimWindowClass.large || SimWindowClass.extraLarge => large,
    };
  }

  static BoxConstraints maxWidthConstraintsFor(
    double width, {
    double compact = SimResponsiveMaxWidth.compact,
    double medium = SimResponsiveMaxWidth.text,
    double expanded = SimResponsiveMaxWidth.conversation,
    double large = SimResponsiveMaxWidth.page,
  }) {
    return BoxConstraints(
      maxWidth: contentMaxWidthFor(
        width,
        compact: compact,
        medium: medium,
        expanded: expanded,
        large: large,
      ),
    );
  }

  static EdgeInsets pagePaddingFor(double width) {
    return switch (widthClassFor(width)) {
      SimWindowClass.compact => const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      SimWindowClass.medium => const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 24,
      ),
      SimWindowClass.expanded => const EdgeInsets.symmetric(
        horizontal: 32,
        vertical: 28,
      ),
      SimWindowClass.large || SimWindowClass.extraLarge =>
        const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
    };
  }

  static SimResponsiveData fromContext(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final media = MediaQuery.of(context);
    return SimResponsiveData(
      size: size,
      widthClass: widthClassFor(size.width),
      heightClass: heightClassFor(size.height),
      padding: media.padding,
      viewInsets: media.viewInsets,
      textScaler: media.textScaler,
      disableAnimations: media.disableAnimations,
    );
  }
}

class SimResponsiveData {
  const SimResponsiveData({
    required this.size,
    required this.widthClass,
    required this.heightClass,
    required this.padding,
    required this.viewInsets,
    required this.textScaler,
    required this.disableAnimations,
  });

  final Size size;
  final SimWindowClass widthClass;
  final SimWindowClass heightClass;
  final EdgeInsets padding;
  final EdgeInsets viewInsets;
  final TextScaler textScaler;
  final bool disableAnimations;

  bool get isCompact => widthClass == SimWindowClass.compact;
  bool get isMediumOrLarger => size.width >= SimResponsiveBreakpoints.medium;
  bool get isExpandedOrLarger =>
      size.width >= SimResponsiveBreakpoints.expanded;
  bool get hasCompactHeight => heightClass == SimWindowClass.compact;
}
