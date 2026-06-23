import 'package:flutter/material.dart';
import 'package:flutter_highlighting/theme_map.dart';
import 'package:flutter_highlighting/themes/atom-one-dark-reasonable.dart';
import 'package:flutter_highlighting/themes/github.dart';
import 'package:flutter_highlighting/themes/github-dark.dart';
import 'package:flutter_highlighting/themes/vs.dart';
import 'package:flutter_highlighting/themes/vs2015.dart';
import 'package:flutter_highlighting/themes/monokai-sublime.dart';
import 'package:flutter_highlighting/themes/dracula.dart';
import 'package:flutter_highlighting/themes/nord.dart';
import 'package:flutter_highlighting/themes/atom-one-light.dart';
import 'package:flutter_highlighting/themes/atom-one-dark.dart';
import 'package:flutter_highlighting/themes/solarized-dark.dart';
import 'package:flutter_highlighting/themes/solarized-light.dart';
import 'package:flutter_highlighting/themes/tokyo-night-dark.dart';
import 'package:flutter_highlighting/themes/tokyo-night-light.dart';
import 'package:flutter_highlighting/themes/androidstudio.dart';
import 'package:flutter_highlighting/themes/xcode.dart';
import 'package:flutter_highlighting/themes/idea.dart';
import 'package:flutter_highlighting/themes/night-owl.dart';
import 'package:flutter_highlighting/themes/stackoverflow-dark.dart';
import 'package:flutter_highlighting/themes/stackoverflow-light.dart';
import 'package:flutter_highlighting/themes/gruvbox-dark.dart';
import 'package:flutter_highlighting/themes/gruvbox-light.dart';
import 'package:flutter_highlighting/themes/github-dark-dimmed.dart';
import 'package:flutter_highlighting/themes/a11y-dark.dart';
import 'package:flutter_highlighting/themes/a11y-light.dart';
import 'package:flutter_highlighting/themes/shades-of-purple.dart';
import 'package:flutter_highlighting/themes/panda-syntax-dark.dart';
import 'package:flutter_highlighting/themes/panda-syntax-light.dart';

/// Default dark theme for code blocks.
const kCodeThemeDarkDefault = atomOneDarkReasonableTheme;

/// Default light theme for code blocks.
const kCodeThemeLightDefault = githubTheme;

/// Curated theme map with display names for the settings UI.
/// Keys are the theme IDs stored in [SidebarSettings.codeHighlightTheme].
const kCodeHighlightThemes = <String, Map<String, TextStyle>>{
  // Dark themes
  'atom-one-dark-reasonable': atomOneDarkReasonableTheme,
  'atom-one-dark': atomOneDarkTheme,
  'github-dark': githubDarkTheme,
  'github-dark-dimmed': githubDarkDimmedTheme,
  'vs2015': vs2015Theme,
  'monokai-sublime': monokaiSublimeTheme,
  'dracula': draculaTheme,
  'nord': nordTheme,
  'solarized-dark': solarizedDarkTheme,
  'tokyo-night-dark': tokyoNightDarkTheme,
  'androidstudio': androidstudioTheme,
  'night-owl': nightOwlTheme,
  'stackoverflow-dark': stackoverflowDarkTheme,
  'gruvbox-dark': gruvboxDarkTheme,
  'a11y-dark': a11yDarkTheme,
  'shades-of-purple': shadesOfPurpleTheme,
  'panda-syntax-dark': pandaSyntaxDarkTheme,
  // Light themes
  'github': githubTheme,
  'atom-one-light': atomOneLightTheme,
  'vs': vsTheme,
  'xcode': xcodeTheme,
  'idea': ideaTheme,
  'solarized-light': solarizedLightTheme,
  'tokyo-night-light': tokyoNightLightTheme,
  'stackoverflow-light': stackoverflowLightTheme,
  'gruvbox-light': gruvboxLightTheme,
  'a11y-light': a11yLightTheme,
  'panda-syntax-light': pandaSyntaxLightTheme,
};

/// Display names for the curated themes.
const kCodeThemeDisplayNames = <String, String>{
  'auto': '自动（跟随系统主题）',
  'atom-one-dark-reasonable': 'Atom One Dark Reasonable',
  'atom-one-dark': 'Atom One Dark',
  'github-dark': 'GitHub Dark',
  'github-dark-dimmed': 'GitHub Dark Dimmed',
  'vs2015': 'VS2015 Dark',
  'monokai-sublime': 'Monokai Sublime',
  'dracula': 'Dracula',
  'nord': 'Nord',
  'solarized-dark': 'Solarized Dark',
  'tokyo-night-dark': 'Tokyo Night Dark',
  'androidstudio': 'Android Studio',
  'night-owl': 'Night Owl',
  'stackoverflow-dark': 'StackOverflow Dark',
  'gruvbox-dark': 'Gruvbox Dark',
  'a11y-dark': 'A11y Dark',
  'shades-of-purple': 'Shades of Purple',
  'panda-syntax-dark': 'Panda Dark',
  'github': 'GitHub',
  'atom-one-light': 'Atom One Light',
  'vs': 'VS Light',
  'xcode': 'Xcode',
  'idea': 'IntelliJ IDEA',
  'solarized-light': 'Solarized Light',
  'tokyo-night-light': 'Tokyo Night Light',
  'stackoverflow-light': 'StackOverflow Light',
  'gruvbox-light': 'Gruvbox Light',
  'a11y-light': 'A11y Light',
  'panda-syntax-light': 'Panda Light',
};

/// Whether a theme is "dark" by examining its root background color.
bool isCodeThemeDark(String themeId) {
  const darkThemes = {
    'atom-one-dark-reasonable',
    'atom-one-dark',
    'github-dark',
    'github-dark-dimmed',
    'vs2015',
    'monokai-sublime',
    'dracula',
    'nord',
    'solarized-dark',
    'tokyo-night-dark',
    'androidstudio',
    'night-owl',
    'stackoverflow-dark',
    'gruvbox-dark',
    'a11y-dark',
    'shades-of-purple',
    'panda-syntax-dark',
  };
  return darkThemes.contains(themeId);
}

/// All 110 themes from flutter_highlighting for future expansion.
const kAllCodeHighlightThemes = themeMap;
