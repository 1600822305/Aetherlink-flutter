package com.example.aetherlink.aetherlink_saf.core

/**
 * Error contract for the plugin (spec §3.2). Handlers translate failures into a
 * [SafException] (or a plain [IllegalArgumentException] / [java.io.FileNotFoundException]
 * / [SecurityException], which the dispatcher maps to the right code) so the
 * Dart side always sees a stable `PlatformException.code`.
 */
object SafError {
    const val NO_PERMISSION = "E_NO_PERMISSION"
    const val URI_STALE = "E_URI_STALE"
    const val NOT_FOUND = "E_NOT_FOUND"
    const val INVALID_ARG = "E_INVALID_ARG"
    const val IO = "E_IO"
    const val OUT_OF_SPACE = "E_OUT_OF_SPACE"
    const val TOO_LARGE = "E_TOO_LARGE"
    const val RANGE_CONFLICT = "E_RANGE_CONFLICT"
    const val NOT_SUPPORTED = "E_NOT_SUPPORTED"
    const val USER_CANCELLED = "E_USER_CANCELLED"
}

/**
 * A failure carrying an explicit spec error [code] plus optional [details]
 * context (`{ uri, cause, ... }`). Thrown by handlers/repository when the right
 * code can't be inferred from a stock JVM exception type.
 */
class SafException(
    val code: String,
    override val message: String,
    val details: Map<String, Any?>? = null,
    cause: Throwable? = null,
) : Exception(message, cause)
