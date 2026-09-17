package com.artificialorctelligence.orcweather.car

import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarIcon
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.MapController
import androidx.car.app.navigation.model.MapWithContentTemplate
import androidx.car.app.navigation.model.PanModeListener
import androidx.core.graphics.drawable.IconCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.artificialorctelligence.orcweather.R

/**
 * The Flutter map on the car surface with the smallest legal overlay: a text-only card carrying
 * the phone's compact strip in glyphs. The four map-strip slots are pan (required for gestures),
 * media play/stop, speak, and a zoom button cycling 30/60/120 mi; recentering happens on its own
 * 15 s after the last gesture.
 * WE-5: at most five annotation types on the map (radar, alerts, roads, work zones, position).
 */
class MapCarScreen(carContext: CarContext, private val bridge: CarBridge) : Screen(carContext) {
    private val surface = FlutterSurface(carContext, bridge)
    private val refresh = { invalidate() }
    private val handler = Handler(Looper.getMainLooper())

    init {
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                carContext.getCarService(AppManager::class.java).setSurfaceCallback(surface)
                bridge.onConditions(refresh)
            }
            override fun onStop(owner: LifecycleOwner) {
                bridge.removeListener(refresh)
                carContext.getCarService(AppManager::class.java).setSurfaceCallback(null)
            }
        })
    }

    override fun onGetTemplate(): Template {
        val line = (bridge.conditions["strip"] as? String) ?: "Locating…"
        fun action(res: Int, onClick: () -> Unit) = Action.Builder().setIcon(bitmapIcon(res)).setOnClickListener(onClick).build()
        val mediaIcon = if (bridge.isMediaPlaying) R.drawable.ic_car_stop else R.drawable.ic_car_play
        val strip = ActionStrip.Builder()
            .addAction(Action.PAN) // required, or the host delivers no pan/scale gestures
            .addAction(action(mediaIcon) { bridge.toggleMedia(); handler.postDelayed({ invalidate() }, 600) })
            .addAction(action(R.drawable.ic_car_speak) { bridge.speakConditions() })
            .addAction(action(R.drawable.ic_car_zoom_cycle) { bridge.zoomCycle() })
            .build()
        return MapWithContentTemplate.Builder()
            .setContentTemplate(MessageTemplate.Builder(line).build()) // content is mandatory; text-only is the smallest
            .setMapController(
                MapController.Builder()
                    .setPanModeListener(PanModeListener { inPan -> bridge.setPanMode(inPan) })
                    .setMapActionStrip(strip)
                    .build(),
            )
            .build()
    }

    /**
     * Icons as bitmaps rather than resource ids: the host caches our resource table, so after a
     * reinstall that renumbers drawables it would draw the wrong icon for each id (seen 2026-09-16).
     */
    private fun bitmapIcon(res: Int): CarIcon {
        val d = checkNotNull(carContext.getDrawable(res)) { "missing drawable $res" }
        val bmp = Bitmap.createBitmap(96, 96, Bitmap.Config.ARGB_8888)
        d.setBounds(0, 0, 96, 96)
        d.draw(Canvas(bmp))
        return CarIcon.Builder(IconCompat.createWithBitmap(bmp)).build()
    }
}
