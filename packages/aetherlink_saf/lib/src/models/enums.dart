// Wire enums — the `wireValue` spellings are fixed by the spec doc.

/// Sort key for [listDirectory] (spec P0). `wireValue` is the string sent
/// to the native side.
///
/// (Value names are prefixed `by*` because `name` would shadow the
/// `Enum.name` getter that produces the wire value otherwise.)
enum FileSortBy {
  byName('name'),
  bySize('size'),
  byMtime('mtime'),
  byType('type');

  const FileSortBy(this.wireValue);

  final String wireValue;
}

/// Sort order for [listDirectory] (spec P0).
enum FileSortOrder {
  asc('asc'),
  desc('desc');

  const FileSortOrder(this.wireValue);

  final String wireValue;
}

/// Picker target for `openSystemFilePicker` (spec P0).
///
/// Android cannot combine the two intents, so `'both'` is intentionally
/// absent (spec §3.4). Callers that need both should call twice.
enum PickerType {
  file('file'),
  directory('directory');

  const PickerType(this.wireValue);

  final String wireValue;
}

/// Diff format for `applyDiff` (spec P2). `searchReplace` is the agent
/// primary (matches the original Web plugin); `unified` is standard.
enum DiffFormat {
  searchReplace('search-replace'),
  unified('unified');

  const DiffFormat(this.wireValue);

  final String wireValue;
}

/// What `searchFiles` matches against (spec P2).
enum SearchType {
  name('name'),
  content('content'),
  both('both');

  const SearchType(this.wireValue);

  final String wireValue;
}

/// Hash algorithm for `getFileHash` (spec P1).
enum HashAlgorithm {
  md5('md5'),
  sha256('sha256');

  const HashAlgorithm(this.wireValue);

  final String wireValue;
}
