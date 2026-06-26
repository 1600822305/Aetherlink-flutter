// Turns an opaque workspace path into something human-readable for display
// only (headers, tooltips). Never feed the result back to a backend — the
// real addressing token stays the original [WorkspaceEntry.path].
//
// SAF hands out `content://` URIs, not filesystem paths, because Android's
// scoped storage hides real paths. The URI still encodes a readable document
// id though, e.g.
//
//   content://com.android.externalstorage.documents/tree/primary%3ADownload
//            /document/primary%3ADownload%2Ffoo%2Fbar.txt
//
// whose `document` segment decodes to `primary:Download/foo/bar.txt`. We strip
// the `primary:` volume prefix and show `Download/foo/bar.txt`. Non-SAF
// backends (Termux / SSH posix paths) are returned unchanged.
String readableWorkspacePath(String path) {
  if (!path.startsWith('content://')) return path;
  final uri = Uri.tryParse(path);
  if (uri == null) return path;

  // pathSegments are already percent-decoded, and the document id's own `/`
  // are encoded as %2F so the whole id arrives as a single decoded segment.
  final segments = uri.pathSegments;
  String? docId;
  final docIdx = segments.indexOf('document');
  if (docIdx != -1 && docIdx + 1 < segments.length) {
    docId = segments[docIdx + 1];
  } else {
    final treeIdx = segments.indexOf('tree');
    if (treeIdx != -1 && treeIdx + 1 < segments.length) {
      docId = segments[treeIdx + 1];
    }
  }
  if (docId == null || docId.isEmpty) return path;

  // Drop the volume prefix (`primary:`, `1A2B-3C4D:`, …).
  final colon = docId.indexOf(':');
  final rel = colon >= 0 ? docId.substring(colon + 1) : docId;
  return rel.isEmpty ? '/' : rel;
}
