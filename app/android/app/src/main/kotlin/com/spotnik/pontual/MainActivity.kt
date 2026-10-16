package com.spotnik.pontual

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Manual plugin: GNSS quality has no pub package (D68).
        flutterEngine.plugins.add(GnssQualityPlugin())
    }
}
