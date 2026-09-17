package com.artificialorctelligence.orcweather.car

import android.app.Presentation
import android.content.Context
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts a second Flutter engine (Dart entrypoint `carMain`) on the car's map surface, the way
 * Google's draw-maps guide renders Views: a VirtualDisplay over the Surface, a Presentation on it.
 * The phone's engine keeps running the phone UI; this one draws only the map.
 */
class FlutterSurface(private val context: Context, private val onConditions: (Map<String, Any?>) -> Unit) : SurfaceCallback {
    private var virtualDisplay: VirtualDisplay? = null
    private var presentation: Presentation? = null
    private var engine: FlutterEngine? = null
    private var view: FlutterView? = null
    private var channel: MethodChannel? = null

    override fun onSurfaceAvailable(surfaceContainer: SurfaceContainer) {
        val surface = surfaceContainer.surface ?: return
        val dm = context.getSystemService(DisplayManager::class.java)
        val vd = dm.createVirtualDisplay(
            "orcweather-car", surfaceContainer.width, surfaceContainer.height, surfaceContainer.dpi, surface, 0,
        )
        virtualDisplay = vd

        val eng = FlutterEngine(context)
        eng.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(FlutterInjector.instance().flutterLoader().findAppBundlePath(), "carMain"),
        )
        channel = MethodChannel(eng.dartExecutor.binaryMessenger, CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "conditions" -> { @Suppress("UNCHECKED_CAST") onConditions(call.arguments as Map<String, Any?>); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        }
        engine = eng

        val p = Presentation(context, vd.display)
        val fv = FlutterView(p.context)
        p.setContentView(fv)
        p.show()
        fv.attachToFlutterEngine(eng)
        eng.lifecycleChannel.appIsResumed()
        presentation = p
        view = fv
    }

    // Map gestures arrive here (only while the host's pan mode is on) and are forwarded to the Flutter map.
    override fun onScroll(distanceX: Float, distanceY: Float) {
        channel?.invokeMethod("pan", listOf(distanceX.toDouble(), distanceY.toDouble()))
    }

    override fun onScale(focusX: Float, focusY: Float, scaleFactor: Float) {
        channel?.invokeMethod("scale", scaleFactor.toDouble())
    }

    override fun onFling(velocityX: Float, velocityY: Float) {
        // ponytail: a fling is a big pan; no inertia animation on the car screen.
        channel?.invokeMethod("pan", listOf((velocityX / 10).toDouble(), (velocityY / 10).toDouble()))
    }

    override fun onVisibleAreaChanged(visibleArea: Rect) {
        channel?.invokeMethod("visibleArea", listOf(visibleArea.left, visibleArea.top, visibleArea.right, visibleArea.bottom))
    }

    override fun onSurfaceDestroyed(surfaceContainer: SurfaceContainer) {
        view?.detachFromFlutterEngine()
        presentation?.dismiss()
        engine?.lifecycleChannel?.appIsDetached()
        engine?.destroy()
        virtualDisplay?.release()
        view = null; presentation = null; engine = null; channel = null; virtualDisplay = null
    }

    /** Zoom in/out from the template's map action strip. */
    fun zoomBy(delta: Double) = channel?.invokeMethod("zoom", delta)

    fun recenter() = channel?.invokeMethod("recenter", null)

    fun setPanMode(on: Boolean) = channel?.invokeMethod("panMode", on)

    companion object {
        const val CHANNEL = "orcweather/car"
    }
}
