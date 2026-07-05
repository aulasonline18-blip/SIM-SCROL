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

class SimResponsiveDensity {
  const SimResponsiveDensity._();

  static const double touchMin = 48;
  static const double touchGap = 8;
  static const double gapCompact = 12;
  static const double gapMedium = 16;
  static const double gapExpanded = 20;
  static const double gapLarge = 24;
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

  static EdgeInsets paddingFor(double width) => pagePaddingFor(width);

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

  static EdgeInsets cardPaddingFor(double width) {
    return switch (widthClassFor(width)) {
      SimWindowClass.compact => const EdgeInsets.all(16),
      SimWindowClass.medium => const EdgeInsets.all(20),
      SimWindowClass.expanded => const EdgeInsets.all(24),
      SimWindowClass.large ||
      SimWindowClass.extraLarge => const EdgeInsets.all(28),
    };
  }

  static double cardMaxWidthFor(double width) {
    return contentMaxWidthFor(
      width,
      medium: SimResponsiveMaxWidth.text,
      expanded: SimResponsiveMaxWidth.page,
      large: SimResponsiveMaxWidth.page,
    );
  }

  static double gapFor(double width) {
    return switch (widthClassFor(width)) {
      SimWindowClass.compact => SimResponsiveDensity.gapCompact,
      SimWindowClass.medium => SimResponsiveDensity.gapMedium,
      SimWindowClass.expanded => SimResponsiveDensity.gapExpanded,
      SimWindowClass.large ||
      SimWindowClass.extraLarge => SimResponsiveDensity.gapLarge,
    };
  }

  static EdgeInsets buttonPaddingFor(double width) {
    return switch (widthClassFor(width)) {
      SimWindowClass.compact => const EdgeInsets.symmetric(horizontal: 16),
      SimWindowClass.medium => const EdgeInsets.symmetric(horizontal: 20),
      SimWindowClass.expanded ||
      SimWindowClass.large ||
      SimWindowClass.extraLarge => const EdgeInsets.symmetric(horizontal: 24),
    };
  }

  static Size buttonMinimumSizeFor(double width) {
    final horizontal = widthClassFor(width) == SimWindowClass.compact
        ? SimResponsiveDensity.touchMin
        : SimResponsiveDensity.touchMin + SimResponsiveDensity.gapMedium;
    return Size(horizontal, SimResponsiveDensity.touchMin);
  }

  static EdgeInsets safePaddingFor(MediaQueryData mediaQuery) {
    return mediaQuery.padding;
  }

  static EdgeInsets keyboardInsetsFor(MediaQueryData mediaQuery) {
    return mediaQuery.viewInsets;
  }

  static EdgeInsets safeKeyboardPaddingFor(MediaQueryData mediaQuery) {
    final safe = safePaddingFor(mediaQuery);
    final keyboard = keyboardInsetsFor(mediaQuery);
    return safe.copyWith(
      bottom: safe.bottom > keyboard.bottom ? safe.bottom : keyboard.bottom,
    );
  }

  static Size visibleSizeFor(MediaQueryData mediaQuery) {
    final safe = safePaddingFor(mediaQuery);
    final keyboard = keyboardInsetsFor(mediaQuery);
    final width = mediaQuery.size.width - safe.left - safe.right;
    final bottomInset = safe.bottom > keyboard.bottom
        ? safe.bottom
        : keyboard.bottom;
    final height = mediaQuery.size.height - safe.top - bottomInset;
    return Size(
      width.clamp(0, double.infinity),
      height.clamp(0, double.infinity),
    );
  }

  static SimResponsiveData fromContext(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final media = MediaQuery.of(context);
    return SimResponsiveData(
      size: size,
      widthClass: widthClassFor(size.width),
      heightClass: heightClassFor(size.height),
      padding: media.padding,
      safeKeyboardPadding: safeKeyboardPaddingFor(media),
      viewInsets: media.viewInsets,
      visibleSize: visibleSizeFor(media),
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
    required this.safeKeyboardPadding,
    required this.viewInsets,
    required this.visibleSize,
    required this.textScaler,
    required this.disableAnimations,
  });

  final Size size;
  final SimWindowClass widthClass;
  final SimWindowClass heightClass;
  final EdgeInsets padding;
  final EdgeInsets safeKeyboardPadding;
  final EdgeInsets viewInsets;
  final Size visibleSize;
  final TextScaler textScaler;
  final bool disableAnimations;

  bool get isCompact => widthClass == SimWindowClass.compact;
  bool get isMediumOrLarger => size.width >= SimResponsiveBreakpoints.medium;
  bool get isExpandedOrLarger =>
      size.width >= SimResponsiveBreakpoints.expanded;
  bool get hasCompactHeight => heightClass == SimWindowClass.compact;
}
