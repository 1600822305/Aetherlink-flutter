import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'models.dart';

typedef _SearchNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _FreeNative = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);

/// Thrown when libaether_rg.so can't be loaded or the native call fails,
/// so callers can distinguish "library unavailable" from "no results".
class RipgrepNativeException implements Exception {
  const RipgrepNativeException(this.message);

  final String message;

  @override
  String toString() => 'RipgrepNativeException: $message';
}

/// In-process file search backed by the bundled Rust cdylib
/// (`native/src/lib.rs`). Android-only: the .so ships in this package's
/// jniLibs. The walk runs on a background isolate, so calls never block
/// the UI thread.
class AetherlinkRipgrep {
  const AetherlinkRipgrep();

  static bool get isSupported => Platform.isAndroid;

  Future<RgSearchResponse> search(RgSearchRequest request) {
    final requestJson = jsonEncode(request.toJson());
    return Isolate.run(() {
      final responseJson = _searchSync(requestJson);
      final response = RgSearchResponse.fromJson(
        jsonDecode(responseJson) as Map<String, dynamic>,
      );
      if (!response.ok) {
        throw RipgrepNativeException(response.error);
      }
      return response;
    });
  }

  static String _searchSync(String requestJson) {
    final lib = _library;
    final searchFn = lib.lookupFunction<_SearchNative, _SearchNative>(
      'aether_rg_search',
    );
    final freeFn = lib.lookupFunction<_FreeNative, _FreeDart>(
      'aether_rg_free_string',
    );
    final requestPtr = requestJson.toNativeUtf8();
    try {
      final responsePtr = searchFn(requestPtr);
      if (responsePtr == nullptr) {
        throw const RipgrepNativeException('native search returned null');
      }
      try {
        return responsePtr.toDartString();
      } finally {
        freeFn(responsePtr);
      }
    } finally {
      malloc.free(requestPtr);
    }
  }

  static DynamicLibrary get _library {
    try {
      return _cachedLibrary ??= DynamicLibrary.open('libaether_rg.so');
    } on ArgumentError catch (e) {
      throw RipgrepNativeException('failed to load libaether_rg.so: $e');
    }
  }

  static DynamicLibrary? _cachedLibrary;
}
