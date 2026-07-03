package com.aetherlink.dexeditor.compat;

import java.util.Collection;
import java.util.Iterator;
import java.util.Map;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Capacitor-independent drop-in replacement for {@code com.getcapacitor.JSObject}.
 *
 * <p>The DEX/APK core logic ({@code DexManager}, {@code ApkManager}, the C++
 * helpers) was written against Capacitor's {@code JSObject}, which differs from
 * a plain {@link JSONObject} in two load-bearing ways the core relies on:
 * <ul>
 *   <li>{@code put(...)} never throws (it swallows {@link JSONException}) and
 *       returns {@code this} for chaining;</li>
 *   <li>{@code getString(key)} returns {@code null} for a missing / non-string
 *       value instead of throwing.</li>
 * </ul>
 * Reproducing that behaviour here lets the core files be reused verbatim while
 * dropping the Capacitor dependency. Values are marshalled to/from Flutter's
 * {@code StandardMessageCodec} types (Map/List/primitives) by the plugin bridge.
 */
public class JSObject extends JSONObject {

    public JSObject() {
        super();
    }

    public JSObject(String json) throws JSONException {
        super(json);
    }

    /** Deep-converts a Dart-decoded {@link Map} (nested Map/List) into a tree of
     * {@link JSObject}/{@link JSArray} so the reused core can consume it. */
    public JSObject(Map<?, ?> source) {
        super();
        if (source == null) {
            return;
        }
        for (Map.Entry<?, ?> entry : source.entrySet()) {
            put(String.valueOf(entry.getKey()), wrap(entry.getValue()));
        }
    }

    /** Deep-converts an arbitrary decoded value into shim-friendly types. */
    public static Object wrap(Object value) {
        if (value instanceof Map) {
            return new JSObject((Map<?, ?>) value);
        }
        if (value instanceof Collection) {
            return new JSArray((Collection<?>) value);
        }
        return value;
    }

    @Override
    public JSObject put(String name, boolean value) {
        try {
            super.put(name, value);
        } catch (JSONException ignored) {
        }
        return this;
    }

    @Override
    public JSObject put(String name, double value) {
        try {
            super.put(name, value);
        } catch (JSONException ignored) {
        }
        return this;
    }

    @Override
    public JSObject put(String name, int value) {
        try {
            super.put(name, value);
        } catch (JSONException ignored) {
        }
        return this;
    }

    @Override
    public JSObject put(String name, long value) {
        try {
            super.put(name, value);
        } catch (JSONException ignored) {
        }
        return this;
    }

    @Override
    public JSObject put(String name, Object value) {
        try {
            super.put(name, value);
        } catch (JSONException ignored) {
        }
        return this;
    }

    /** Returns the string value for {@code name}, or {@code null} when it is
     * absent or not a string (matches Capacitor semantics; never throws). */
    public String getString(String name) {
        return getString(name, null);
    }

    public String getString(String name, String defaultValue) {
        try {
            Object value = get(name);
            if (value instanceof String) {
                return (String) value;
            }
        } catch (JSONException ignored) {
        }
        return defaultValue;
    }

    /** Nested object accessor returning a {@link JSObject} (or {@code null}). */
    public JSObject getJSObject(String name) {
        try {
            Object value = get(name);
            if (value instanceof JSObject) {
                return (JSObject) value;
            }
            if (value instanceof JSONObject) {
                return JSObject.fromJSONObject((JSONObject) value);
            }
        } catch (JSONException ignored) {
        }
        return null;
    }

    public static JSObject fromJSONObject(JSONObject source) {
        JSObject out = new JSObject();
        if (source == null) {
            return out;
        }
        Iterator<String> keys = source.keys();
        while (keys.hasNext()) {
            String key = keys.next();
            Object value = source.opt(key);
            if (value instanceof JSONObject && !(value instanceof JSObject)) {
                value = JSObject.fromJSONObject((JSONObject) value);
            } else if (value instanceof JSONArray && !(value instanceof JSArray)) {
                value = JSArray.fromJSONArray((JSONArray) value);
            }
            out.put(key, value);
        }
        return out;
    }
}
