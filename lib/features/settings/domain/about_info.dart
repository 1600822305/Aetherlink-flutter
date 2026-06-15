/// Pure-Dart display model for the About page (ported from the original
/// `src/pages/Settings/AboutPage.tsx`: app name, description, version and the
/// external links). Pure data — no Flutter import — so it passes
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

/// A labelled external link shown as a row on the About page.
class AboutLink {
  const AboutLink({required this.label, required this.url});

  final String label;
  final String url;
}
