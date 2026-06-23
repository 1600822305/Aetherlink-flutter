// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sidebar_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SidebarSettings _$SidebarSettingsFromJson(
  Map<String, dynamic> json,
) => _SidebarSettings(
  showMessageDivider: json['showMessageDivider'] as bool? ?? true,
  copyableCodeBlocks: json['copyableCodeBlocks'] as bool? ?? true,
  renderUserInputAsMarkdown: json['renderUserInputAsMarkdown'] as bool? ?? true,
  autoScrollToBottom: json['autoScrollToBottom'] as bool? ?? true,
  messageStyle:
      $enumDecodeNullable(_$MessageStyleEnumMap, json['messageStyle']) ??
      MessageStyle.bubble,
  messageNavigation:
      $enumDecodeNullable(
        _$MessageNavigationEnumMap,
        json['messageNavigation'],
      ) ??
      MessageNavigation.none,
  showContextTokenIndicator: json['showContextTokenIndicator'] as bool? ?? true,
  sidebarWidth: (json['sidebarWidth'] as num?)?.toDouble() ?? 350.0,
  sidebarDisplayMode:
      $enumDecodeNullable(
        _$SidebarDisplayModeEnumMap,
        json['sidebarDisplayMode'],
      ) ??
      SidebarDisplayMode.overlay,
  settingsLayoutMode:
      $enumDecodeNullable(
        _$SettingsLayoutModeEnumMap,
        json['settingsLayoutMode'],
      ) ??
      SettingsLayoutMode.compact,
  contextWindowSize: (json['contextWindowSize'] as num?)?.toInt() ?? 100000,
  contextCount: (json['contextCount'] as num?)?.toInt() ?? 20,
  maxOutputTokens: (json['maxOutputTokens'] as num?)?.toInt() ?? 8192,
  enableMaxOutputTokens: json['enableMaxOutputTokens'] as bool? ?? true,
  pasteLongTextAsFile: json['pasteLongTextAsFile'] as bool? ?? false,
  pasteLongTextThreshold:
      (json['pasteLongTextThreshold'] as num?)?.toInt() ?? 1500,
  codeShowLineNumbers: json['codeShowLineNumbers'] as bool? ?? true,
  codeCollapsible: json['codeCollapsible'] as bool? ?? true,
  codeWrappable: json['codeWrappable'] as bool? ?? true,
  codeDefaultCollapsed: json['codeDefaultCollapsed'] as bool? ?? false,
  codeHighlightTheme: json['codeHighlightTheme'] as String? ?? 'auto',
  codeFontSize: (json['codeFontSize'] as num?)?.toInt() ?? 13,
  codeFixedHeight: json['codeFixedHeight'] as bool? ?? false,
  codeMaxHeight: (json['codeMaxHeight'] as num?)?.toInt() ?? 300,
  mermaidEnabled: json['mermaidEnabled'] as bool? ?? true,
  mathEnableSingleDollar: json['mathEnableSingleDollar'] as bool? ?? true,
);

Map<String, dynamic> _$SidebarSettingsToJson(
  _SidebarSettings instance,
) => <String, dynamic>{
  'showMessageDivider': instance.showMessageDivider,
  'copyableCodeBlocks': instance.copyableCodeBlocks,
  'renderUserInputAsMarkdown': instance.renderUserInputAsMarkdown,
  'autoScrollToBottom': instance.autoScrollToBottom,
  'messageStyle': _$MessageStyleEnumMap[instance.messageStyle]!,
  'messageNavigation': _$MessageNavigationEnumMap[instance.messageNavigation]!,
  'showContextTokenIndicator': instance.showContextTokenIndicator,
  'sidebarWidth': instance.sidebarWidth,
  'sidebarDisplayMode':
      _$SidebarDisplayModeEnumMap[instance.sidebarDisplayMode]!,
  'settingsLayoutMode':
      _$SettingsLayoutModeEnumMap[instance.settingsLayoutMode]!,
  'contextWindowSize': instance.contextWindowSize,
  'contextCount': instance.contextCount,
  'maxOutputTokens': instance.maxOutputTokens,
  'enableMaxOutputTokens': instance.enableMaxOutputTokens,
  'pasteLongTextAsFile': instance.pasteLongTextAsFile,
  'pasteLongTextThreshold': instance.pasteLongTextThreshold,
  'codeShowLineNumbers': instance.codeShowLineNumbers,
  'codeCollapsible': instance.codeCollapsible,
  'codeWrappable': instance.codeWrappable,
  'codeDefaultCollapsed': instance.codeDefaultCollapsed,
  'codeHighlightTheme': instance.codeHighlightTheme,
  'codeFontSize': instance.codeFontSize,
  'codeFixedHeight': instance.codeFixedHeight,
  'codeMaxHeight': instance.codeMaxHeight,
  'mermaidEnabled': instance.mermaidEnabled,
  'mathEnableSingleDollar': instance.mathEnableSingleDollar,
};

const _$MessageStyleEnumMap = {
  MessageStyle.plain: 'plain',
  MessageStyle.bubble: 'bubble',
};

const _$MessageNavigationEnumMap = {
  MessageNavigation.none: 'none',
  MessageNavigation.buttons: 'buttons',
};

const _$SidebarDisplayModeEnumMap = {
  SidebarDisplayMode.overlay: 'overlay',
  SidebarDisplayMode.push: 'push',
};

const _$SettingsLayoutModeEnumMap = {
  SettingsLayoutMode.compact: 'compact',
  SettingsLayoutMode.grouped: 'grouped',
};
