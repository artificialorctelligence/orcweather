package com.artificialorctelligence.orcweather.car

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.speech.tts.TextToSpeech
import android.util.Log
import android.view.KeyEvent
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * One Flutter engine per car session, running Dart entrypoint `carMain` from the moment the car
 * connects — headless until the map screen attaches a view. It tracks position, fetches weather
 * and pushes a conditions summary here; screens read [conditions] and re-render on change.
 */
class CarBridge(private val context: Context) {
    val engine: FlutterEngine = FlutterEngine(context)
    private val channel: MethodChannel
    /** From Dart: `strip` (one line for the card), `spoken` (what the megaphone says). */
    var conditions: Map<String, Any?> = emptyMap()
        private set
    private val listeners = mutableListOf<() -> Unit>()
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private val audio = context.getSystemService(AudioManager::class.java)
    private val speechAttrs = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE) // routed like turn-by-turn prompts
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()

    init {
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(FlutterInjector.instance().flutterLoader().findAppBundlePath(), "carMain"),
        )
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "conditions" -> {
                    @Suppress("UNCHECKED_CAST")
                    conditions = call.arguments as Map<String, Any?>
                    listeners.forEach { it() }
                    result.success(null)
                }
                "speak" -> { speak(call.arguments as String); result.success(null) }
                else -> result.notImplemented()
            }
        }
        engine.lifecycleChannel.appIsResumed()
        tts = TextToSpeech(context) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            tts?.setAudioAttributes(speechAttrs)
        }
    }

    /** Speak over the car audio, ducking whatever is playing for the duration. */
    fun speak(text: String) {
        Log.i(TAG, "speak (ttsReady=$ttsReady): $text")
        val t = tts ?: return
        if (!ttsReady) return
        val focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
            .setAudioAttributes(speechAttrs).build()
        audio.requestAudioFocus(focus)
        t.setOnUtteranceProgressListener(object : android.speech.tts.UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {}
            override fun onDone(utteranceId: String?) { audio.abandonAudioFocusRequest(focus) }
            @Deprecated("Deprecated in Java") override fun onError(utteranceId: String?) { audio.abandonAudioFocusRequest(focus) }
        })
        t.speak(text, TextToSpeech.QUEUE_FLUSH, null, "orcweather")
    }

    fun speakConditions() {
        val text = conditions["spoken"] as? String
        Log.i(TAG, "speakConditions: ${text ?: "<no conditions yet>"}")
        text?.let { speak(it) }
    }
    fun tap(x: Double, y: Double) = channel.invokeMethod("tap", listOf(x, y))
    fun zoomCycle() = channel.invokeMethod("zoomCycle", null)

    /** Play/pause whatever media app is active — a media key, no permission needed (BACKLOG #7). */
    fun toggleMedia() {
        for (action in listOf(KeyEvent.ACTION_DOWN, KeyEvent.ACTION_UP)) {
            audio.dispatchMediaKeyEvent(KeyEvent(action, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
        }
    }
    val isMediaPlaying: Boolean get() = audio.isMusicActive

    fun onConditions(listener: () -> Unit) { listeners += listener }
    fun removeListener(listener: () -> Unit) { listeners -= listener }

    fun zoomBy(delta: Double) = channel.invokeMethod("zoom", delta)
    fun recenter() = channel.invokeMethod("recenter", null)
    fun setPanMode(on: Boolean) = channel.invokeMethod("panMode", on)
    fun pan(dx: Double, dy: Double) = channel.invokeMethod("pan", listOf(dx, dy))
    fun scale(factor: Double) = channel.invokeMethod("scale", factor)

    fun destroy() {
        tts?.stop(); tts?.shutdown(); tts = null
        engine.lifecycleChannel.appIsDetached()
        engine.destroy()
    }

    companion object {
        const val CHANNEL = "orcweather/car"
        private const val TAG = "orcweather.car"
    }
}
