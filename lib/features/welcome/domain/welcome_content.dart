/// Pure-Dart display model for the welcome page (ported from the original
/// `src/pages/WelcomePage.tsx` and its `welcome.*` i18n strings: a title, a
/// subtitle and the start-button label). Pure data — no Flutter import — so it
/// passes `import_boundaries_test`.
class WelcomeContent {
  const WelcomeContent({
    required this.title,
    required this.subtitle,
    required this.startButtonLabel,
  });

  final String title;
  final String subtitle;
  final String startButtonLabel;
}
