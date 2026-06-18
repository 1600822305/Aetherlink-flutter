/// App-level composition seam re-exposing the settings-owned 快捷短语 providers to
/// the chat feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`;
/// only its `domain` is allowed. The 快捷短语管理 page (settings) owns
/// [GlobalQuickPhrases] (the full CRUD list) and [ShowQuickPhraseButton] (the
/// display toggle), but the chat composer must read the list (to insert a
/// phrase / show the selector's add row) and the toggle (to gate the 添加内容
/// menu's quick-phrase row). It reaches them through this `app/` re-export — the
/// composition root, which may depend on any feature — instead of importing
/// `settings/application` directly. Mirrors `input_box_access` (settings →
/// chat) for the input-box config.
library;

export 'package:aetherlink_flutter/features/settings/application/quick_phrases_controller.dart'
    show
        GlobalQuickPhrases,
        globalQuickPhrasesProvider,
        showQuickPhraseButtonProvider;
