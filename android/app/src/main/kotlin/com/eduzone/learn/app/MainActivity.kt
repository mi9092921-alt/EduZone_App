package com.eduzone.learn.app

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Set this natively so the protection does not depend on the
        // screen_protector method channel being ready. This blocks screenshots
        // and screen recording from the first Android frame.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            // Re-assert the protection if another Android surface or plugin
            // modified the window flags while this activity was unfocused.
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
