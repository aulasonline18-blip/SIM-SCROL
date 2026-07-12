enum PedagogicalVisualHierarchyRole {
  primary,
  secondary,
  example,
  attention,
  critical,
  connector,
  conclusion,
  definition,
  neutral,
}

class PedagogicalVisualHierarchy {
  const PedagogicalVisualHierarchy();

  static const standard = PedagogicalVisualHierarchy();

  int fontSize(PedagogicalVisualHierarchyRole role) {
    switch (role) {
      case PedagogicalVisualHierarchyRole.primary:
        return 24;
      case PedagogicalVisualHierarchyRole.secondary:
        return 20;
      case PedagogicalVisualHierarchyRole.example:
        return 18;
      case PedagogicalVisualHierarchyRole.attention:
        return 21;
      case PedagogicalVisualHierarchyRole.critical:
        return 21;
      case PedagogicalVisualHierarchyRole.connector:
        return 16;
      case PedagogicalVisualHierarchyRole.conclusion:
        return 19;
      case PedagogicalVisualHierarchyRole.definition:
        return 22;
      case PedagogicalVisualHierarchyRole.neutral:
        return 17;
    }
  }

  String fontWeight(PedagogicalVisualHierarchyRole role) {
    switch (role) {
      case PedagogicalVisualHierarchyRole.primary:
      case PedagogicalVisualHierarchyRole.critical:
        return '800';
      case PedagogicalVisualHierarchyRole.attention:
      case PedagogicalVisualHierarchyRole.conclusion:
      case PedagogicalVisualHierarchyRole.definition:
        return '700';
      case PedagogicalVisualHierarchyRole.secondary:
        return '650';
      case PedagogicalVisualHierarchyRole.example:
      case PedagogicalVisualHierarchyRole.connector:
      case PedagogicalVisualHierarchyRole.neutral:
        return '600';
    }
  }

  double strokeWidth(PedagogicalVisualHierarchyRole role) {
    switch (role) {
      case PedagogicalVisualHierarchyRole.primary:
        return 4.8;
      case PedagogicalVisualHierarchyRole.critical:
        return 4.4;
      case PedagogicalVisualHierarchyRole.attention:
        return 4.0;
      case PedagogicalVisualHierarchyRole.definition:
        return 3.8;
      case PedagogicalVisualHierarchyRole.secondary:
        return 3.2;
      case PedagogicalVisualHierarchyRole.connector:
        return 3.4;
      case PedagogicalVisualHierarchyRole.conclusion:
        return 3.0;
      case PedagogicalVisualHierarchyRole.example:
      case PedagogicalVisualHierarchyRole.neutral:
        return 2.4;
    }
  }

  double opacity(PedagogicalVisualHierarchyRole role) {
    switch (role) {
      case PedagogicalVisualHierarchyRole.primary:
      case PedagogicalVisualHierarchyRole.critical:
      case PedagogicalVisualHierarchyRole.attention:
        return 1.0;
      case PedagogicalVisualHierarchyRole.secondary:
      case PedagogicalVisualHierarchyRole.definition:
      case PedagogicalVisualHierarchyRole.conclusion:
        return 0.92;
      case PedagogicalVisualHierarchyRole.connector:
        return 0.78;
      case PedagogicalVisualHierarchyRole.example:
      case PedagogicalVisualHierarchyRole.neutral:
        return 0.72;
    }
  }

  int radius(PedagogicalVisualHierarchyRole role) {
    switch (role) {
      case PedagogicalVisualHierarchyRole.primary:
        return 24;
      case PedagogicalVisualHierarchyRole.attention:
      case PedagogicalVisualHierarchyRole.critical:
      case PedagogicalVisualHierarchyRole.definition:
        return 20;
      case PedagogicalVisualHierarchyRole.secondary:
      case PedagogicalVisualHierarchyRole.conclusion:
        return 18;
      case PedagogicalVisualHierarchyRole.example:
      case PedagogicalVisualHierarchyRole.connector:
      case PedagogicalVisualHierarchyRole.neutral:
        return 14;
    }
  }

  String textAttrs(PedagogicalVisualHierarchyRole role) {
    return 'font-size="${fontSize(role)}" font-weight="${fontWeight(role)}" opacity="${opacity(role).toStringAsFixed(2)}"';
  }

  String strokeAttrs(PedagogicalVisualHierarchyRole role) {
    return 'stroke-width="${strokeWidth(role).toStringAsFixed(1)}" opacity="${opacity(role).toStringAsFixed(2)}"';
  }
}
