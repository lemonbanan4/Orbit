package com.invokerlab.orbit

// audio_service (used by just_audio_background) requires AudioServiceFragmentActivity.
//
// Why not FlutterFragmentActivity?
// AudioServicePlugin.onAttachedToActivity() checks that the activity's engine
// (flutterPluginBinding.getBinaryMessenger()) is the SAME instance as the engine
// managed by AudioServicePlugin itself (stored in FlutterEngineCache under
// "audio_service_engine").  FlutterFragmentActivity creates its own new engine so
// the two are different objects → wrongEngineDetected = true → crash on configure.
//
// AudioServiceFragmentActivity overrides provideFlutterEngine() and
// getCachedEngineId() so both the activity and the plugin use the same
// FlutterEngine — the binary-messenger check passes.
import com.ryanheise.audioservice.AudioServiceFragmentActivity

class MainActivity : AudioServiceFragmentActivity()
