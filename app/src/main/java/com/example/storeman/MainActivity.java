package com.example.storeman;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebSettings;

public class MainActivity extends Activity {

    private WebView webView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        webView = new WebView(this);

        WebSettings settings =
                webView.getSettings();

        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setJavaScriptCanOpenWindowsAutomatically(true);

        webView.setWebViewClient(
            new WebViewClient() {

                @Override
                public boolean shouldOverrideUrlLoading(
                        WebView view,
                        WebResourceRequest request) {

                    return handleUrl(
                        request.getUrl().toString()
                    );
                }

                @Override
                public boolean shouldOverrideUrlLoading(
                        WebView view,
                        String url) {

                    return handleUrl(url);
                }

                private boolean handleUrl(String url) {

                    if (
                        url.startsWith("mailto:") ||
                        url.startsWith("https://wa.me/") ||
                        url.startsWith("whatsapp:")
                    ) {

                        try {

                            Intent intent =
                                new Intent(
                                    Intent.ACTION_VIEW,
                                    Uri.parse(url)
                                );

                            startActivity(intent);

                        } catch(Exception ignored) {}

                        return true;
                    }

                    return false;
                }
            }
        );

        webView.loadUrl(
            "file:///android_asset/index.html"
        );

        setContentView(webView);
    }

    @Override
    public void onBackPressed() {

        if (webView != null &&
            webView.canGoBack()) {

            webView.goBack();

        } else {

            super.onBackPressed();
        }
    }
}
