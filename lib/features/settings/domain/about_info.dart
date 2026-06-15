/// Pure-Dart display model for the About page (ported from the original
/// `src/pages/Settings/AboutPage.tsx`: app name, description, version and the
/// link rows). Pure data — no Flutter import — so it passes
/// `import_boundaries_test`.
class AboutInfo {
  const AboutInfo({
    required this.appName,
    required this.description,
    required this.version,
    required this.links,
  });

  final String appName;
  final String description;
  final String version;
  final List<AboutLink> links;
}

/// Identifies an About-page link row so the presentation layer can attach the
/// matching (lucide) icon without leaking `IconData` into the domain.
enum AboutLinkKind { github, qqGroup, feedback, devTools }

/// A row in the About page's links card.
class AboutLink {
  const AboutLink({required this.kind, required this.title, this.url});

  final AboutLinkKind kind;
  final String title;

  /// External URL to open, or `null` when the target is an in-app destination
  /// that does not exist in the Flutter app yet (rendered disabled, matching
  /// the settings hub's treatment of unimplemented entries).
  final String? url;
}
