package com.aetherlink.dexeditor.compat;

import java.util.Collection;

import org.json.JSONArray;
import org.json.JSONException;

/**
 * Capacitor-independent drop-in replacement for {@code com.getcapacitor.JSArray}.
 *
 * <p>Unlike {@link JSObject}, Capacitor's {@code JSArray} does not override the
 * base {@link JSONArray#put} methods, so element insertion behaviour is
 * identical to the superclass; this shim only adds the constructors the reused
 * core relies on plus deep-conversion of Dart-decoded collections.
 */
public class JSArray extends JSONArray {

    public JSArray() {
        super();
    }

    public JSArray(String json) throws JSONException {
        super(json);
    }

    /** Deep-converts a Dart-decoded {@link Collection} into shim types. */
    public JSArray(Collection<?> source) {
        super();
        if (source == null) {
            return;
        }
        for (Object value : source) {
            put(JSObject.wrap(value));
        }
    }

    public static JSArray fromJSONArray(JSONArray source) {
        JSArray out = new JSArray();
        if (source == null) {
            return out;
        }
        for (int i = 0; i < source.length(); i++) {
            Object value = source.opt(i);
            if (value instanceof org.json.JSONObject
                    && !(value instanceof JSObject)) {
                value = JSObject.fromJSONObject((org.json.JSONObject) value);
            } else if (value instanceof JSONArray && !(value instanceof JSArray)) {
                value = JSArray.fromJSONArray((JSONArray) value);
            }
            out.put(value);
        }
        return out;
    }
}
