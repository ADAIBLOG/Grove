package com.resurrect.grove

// We change FlutterActivity to FlutterFragmentActivity to support local_auth
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
    // This allows the biometric dialog to anchor itself to the app life cycle
}
