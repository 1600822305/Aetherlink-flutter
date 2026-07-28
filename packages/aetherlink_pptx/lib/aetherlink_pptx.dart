/// Pure Dart deck.json → editable PPTX generation.
library;

export 'src/deck_document.dart';
export 'src/deck_draft.dart' show buildDeckDraft, kOutlineJsonSchema;
export 'src/deck_html_renderer.dart' show renderDeckHtml;
export 'src/deck_schema.dart' show kDeckJsonSchema;
export 'src/deck_style.dart'
    show DeckStyle, builtinDeckStyleCatalog, kBuiltinDeckStyles;
export 'src/deck_qa.dart';
export 'src/pptx_editor.dart';
export 'src/pptx_package_validator.dart';
export 'src/pptx_reader.dart';
export 'src/pptx_writer.dart' show buildPptxBytes;
