/// User intent for background execution (port of kelivo's
/// `MobileBackgroundSettings`), separate from the permissions and resources
/// reported by the OS. Android only: the native side lives in
/// `android/.../background/BackgroundRuntime.kt`.
class MobileBackgroundSettings {
  const MobileBackgroundSettings({
    this.androidEnabled = true,
    this.notificationsEnabled = true,
    this.privacyMode = false,
    this.overlayEnabled = false,
    this.liveUpdatesEnabled = false,
    this.completionVisibility = BackgroundCompletionVisibility.oneMinute,
    this.overlayIconKind = 'app',
    this.overlayIconValue = '',
    this.overlayAppearance = const BackgroundOverlayAppearance(),
  });

  final bool androidEnabled;
  final bool notificationsEnabled;
  final bool privacyMode;
  final bool overlayEnabled;
  final bool liveUpdatesEnabled;
  final BackgroundCompletionVisibility completionVisibility;
  final String overlayIconKind;
  final String overlayIconValue;
  final BackgroundOverlayAppearance overlayAppearance;

  factory MobileBackgroundSettings.fromJson(Map<String, dynamic> json) {
    final visibility = BackgroundCompletionVisibility.values.firstWhere(
      (value) => value.name == json['completionVisibility'],
      orElse: () => BackgroundCompletionVisibility.oneMinute,
    );
    final kind = json['overlayIconKind'] as String?;
    return MobileBackgroundSettings(
      androidEnabled: json['androidEnabled'] != false,
      notificationsEnabled: json['notificationsEnabled'] != false,
      privacyMode: json['privacyMode'] == true,
      overlayEnabled: json['overlayEnabled'] == true,
      liveUpdatesEnabled: json['liveUpdatesEnabled'] == true,
      completionVisibility: visibility,
      overlayIconKind: kind == 'image' || kind == 'emoji' ? kind! : 'app',
      overlayIconValue: json['overlayIconValue'] as String? ?? '',
      overlayAppearance: BackgroundOverlayAppearance.fromJson(
        (json['overlayAppearance'] as Map?)?.cast<String, dynamic>() ??
            const {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'androidEnabled': androidEnabled,
    'notificationsEnabled': notificationsEnabled,
    'privacyMode': privacyMode,
    'overlayEnabled': overlayEnabled,
    'liveUpdatesEnabled': liveUpdatesEnabled,
    'completionVisibility': completionVisibility.name,
    'overlayIconKind': overlayIconKind,
    'overlayIconValue': overlayIconValue,
    'overlayAppearance': overlayAppearance.toJson(),
  };

  MobileBackgroundSettings copyWith({
    bool? androidEnabled,
    bool? notificationsEnabled,
    bool? privacyMode,
    bool? overlayEnabled,
    bool? liveUpdatesEnabled,
    BackgroundCompletionVisibility? completionVisibility,
    String? overlayIconKind,
    String? overlayIconValue,
    BackgroundOverlayAppearance? overlayAppearance,
  }) => MobileBackgroundSettings(
    androidEnabled: androidEnabled ?? this.androidEnabled,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    privacyMode: privacyMode ?? this.privacyMode,
    overlayEnabled: overlayEnabled ?? this.overlayEnabled,
    liveUpdatesEnabled: liveUpdatesEnabled ?? this.liveUpdatesEnabled,
    completionVisibility: completionVisibility ?? this.completionVisibility,
    overlayIconKind: overlayIconKind ?? this.overlayIconKind,
    overlayIconValue: overlayIconValue ?? this.overlayIconValue,
    overlayAppearance: overlayAppearance ?? this.overlayAppearance,
  );
}

/// Sizes are logical pixels (Android dp). Display options never enable the
/// overlay or request permissions. Native rendering enforces the same bounds.
class BackgroundOverlayAppearance {
  const BackgroundOverlayAppearance({
    this.width = 290,
    this.height = 84,
    this.cornerRadius = 24,
    this.iconSize = 34,
    this.progressSize = 42,
    this.progressStrokeWidth = 2,
    this.showProgress = true,
    this.showTitle = true,
    this.showSubtitle = true,
    this.showTime = true,
    this.showClose = true,
    this.showBackground = true,
    this.showBorder = false,
  });

  static const circle = BackgroundOverlayAppearance(
    width: 64,
    height: 64,
    cornerRadius: 32,
    iconSize: 48,
    progressSize: 60,
    showTitle: false,
    showSubtitle: false,
    showTime: false,
    showClose: false,
    showBackground: false,
  );

  final double width;
  final double height;
  final double cornerRadius;
  final double iconSize;
  final double progressSize;
  final double progressStrokeWidth;
  final bool showProgress;
  final bool showTitle;
  final bool showSubtitle;
  final bool showTime;
  final bool showClose;
  final bool showBackground;
  final bool showBorder;

  bool get hasText => showTitle || showSubtitle || showTime;
  bool get isIconOnly => !hasText && !showClose;
  double get badgeSize =>
      showProgress && progressSize > iconSize ? progressSize : iconSize;

  factory BackgroundOverlayAppearance.fromJson(Map<String, dynamic> json) {
    double size(String key, double fallback, double min, double max) {
      final value = json[key];
      return value is num && value.isFinite
          ? value.toDouble().clamp(min, max)
          : fallback;
    }

    return BackgroundOverlayAppearance(
      width: size('width', 290, 48, 400),
      height: size('height', 84, 48, 180),
      cornerRadius: size('cornerRadius', 24, 0, 90),
      iconSize: size('iconSize', 34, 16, 120),
      progressSize: size('progressSize', 42, 20, 140),
      progressStrokeWidth: size('progressStrokeWidth', 2, 1, 12),
      showProgress: json['showProgress'] != false,
      showTitle: json['showTitle'] != false,
      showSubtitle: json['showSubtitle'] != false,
      showTime: json['showTime'] != false,
      showClose: json['showClose'] != false,
      showBackground: json['showBackground'] != false,
      showBorder: json['showBorder'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'width': width,
    'height': height,
    'cornerRadius': cornerRadius,
    'iconSize': iconSize,
    'progressSize': progressSize,
    'progressStrokeWidth': progressStrokeWidth,
    'showProgress': showProgress,
    'showTitle': showTitle,
    'showSubtitle': showSubtitle,
    'showTime': showTime,
    'showClose': showClose,
    'showBackground': showBackground,
    'showBorder': showBorder,
  };

  BackgroundOverlayAppearance copyWith({
    double? width,
    double? height,
    double? cornerRadius,
    double? iconSize,
    double? progressSize,
    double? progressStrokeWidth,
    bool? showProgress,
    bool? showTitle,
    bool? showSubtitle,
    bool? showTime,
    bool? showClose,
    bool? showBackground,
    bool? showBorder,
  }) => BackgroundOverlayAppearance.fromJson({
    ...toJson(),
    'width': width ?? this.width,
    'height': height ?? this.height,
    'cornerRadius': cornerRadius ?? this.cornerRadius,
    'iconSize': iconSize ?? this.iconSize,
    'progressSize': progressSize ?? this.progressSize,
    'progressStrokeWidth': progressStrokeWidth ?? this.progressStrokeWidth,
    'showProgress': showProgress ?? this.showProgress,
    'showTitle': showTitle ?? this.showTitle,
    'showSubtitle': showSubtitle ?? this.showSubtitle,
    'showTime': showTime ?? this.showTime,
    'showClose': showClose ?? this.showClose,
    'showBackground': showBackground ?? this.showBackground,
    'showBorder': showBorder ?? this.showBorder,
  });
}

enum BackgroundCompletionVisibility {
  immediate,
  oneMinute,
  fiveMinutes,
  untilForeground;

  int get seconds => switch (this) {
    immediate => 0,
    oneMinute => 60,
    fiveMinutes => 300,
    untilForeground => 900,
  };
}
