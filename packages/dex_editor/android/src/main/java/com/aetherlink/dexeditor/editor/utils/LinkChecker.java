package com.aetherlink.dexeditor.editor.utils;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.util.Patterns;

public class LinkChecker {
    
    public static boolean isLink(String text) {
        if (text == null || text.isEmpty()) return false;
        return Patterns.WEB_URL.matcher(text.trim()).matches();
    }
    
    public static void openLinkInBrowser(Context context, String url) {
        try {
            String trimmedUrl = url.trim();
            if (!trimmedUrl.startsWith("http://") && !trimmedUrl.startsWith("https://")) {
                trimmedUrl = "https://" + trimmedUrl;
            }
            Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(trimmedUrl));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
