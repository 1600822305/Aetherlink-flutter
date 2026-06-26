// Public model barrel for the Aetherlink local SAF workspace plugin.
//
// Mirrors docs/本地SAF工作区插件-方法规格.md §2 (data structures) and §3.2
// (error codes). When the spec doc and these files disagree, the spec doc
// wins — fix the code, not the doc. Types are split by domain under
// `models/`; this file re-exports them so callers keep a single import.

export 'models/enums.dart';
export 'models/errors.dart';
export 'models/file_info.dart';
export 'models/results_p0.dart';
export 'models/results_p1.dart';
export 'models/results_p2.dart';
