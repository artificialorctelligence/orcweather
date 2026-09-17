package com.artificialorctelligence.orcweather.car

import android.app.Presentation
import android.content.Context
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import io.flutter.embedding.android.FlutterView

/**
 * Attaches the session's Flutter engine to the car's map surface the way Google's draw-maps
 * guide renders Views: a VirtualDisplay over the Surface, a Presentation on it, a FlutterView in
 * the Presentation. Map gestures from the host are forwarded to Dart through [CarBridge].
 */
class FlutterSurface(private val context: Context, private val bridge: CarBridge) : SurfaceCallback {
    private var virtualDisplay: VirtualDisplay? = null
    private var presentation: Presentation? = null
    private var view: FlutterView? = null

    override fun onSurfaceAvailable(surfaceContainer: SurfaceContainer) {
        val surface = surfaceContainer.surface ?: return
        val vd = context.getSystemService(DisplayManager::class.java).createVirtualDisplay(
            "orcweather-car", surfaceContainer.width, surfaceContainer.height, surfaceContainer.dpi, surface, 0,
        )
        val p = Presentation(context, vd.display)
        val fv = FlutterView(p.context)
        p.setContentView(fv)
        p.show()
        fv.attachToFlutterEngine(bridge.engine)
        virtualDisplay = vd; presentation = p; view = fv
    }

    override fun onSurfaceDestroyed(surfaceContainer: SurfaceContainer) {
        view?.detachFromFlutterEngine()
        presentation?.dismiss()
        virtualDisplay?.release()
        view = null; presentation = null; virtualDisplay = null
    }

    override fun onClick(x: Float, y: Float) = bridge.tap(x.toDouble(), y.toDouble())
    override fun onScroll(distanceX: Float, distanceY: Float) = bridge.pan(distanceX.toDouble(), distanceY.toDouble())
    override fun onScale(focusX: Float, focusY: Float, scaleFactor: Float) = bridge.scale(scaleFactor.toDouble())
    // ponytail: a fling is a big pan; no inertia animation on the car screen.
    override fun onFling(velocityX: Float, velocityY: Float) = bridge.pan((velocityX / 10).toDouble(), (velocityY / 10).toDouble())
}
