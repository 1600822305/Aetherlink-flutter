package com.example.aetherlink.aetherlink_saf.core

import io.flutter.plugin.common.MethodCall

/** Required argument; throws [IllegalArgumentException] (→ `E_INVALID_ARG`) if absent. */
fun <T> MethodCall.req(name: String): T =
    argument<T>(name) ?: throw IllegalArgumentException("missing arg: $name")

/** Optional argument with a default. */
fun <T> MethodCall.opt(name: String, fallback: T): T = argument<T>(name) ?: fallback
