package com.artificialorctelligence.orcweather.car

import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarIcon
import androidx.car.app.model.Header
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.MapController
import androidx.car.app.navigation.model.MapWithContentTemplate
import androidx.car.app.navigation.model.PanModeListener
import androidx.core.graphics.drawable.IconCompat
import com.artificialorctelligence.orcweather.R

/**
 * Weather category screen: our Flutter map behind a small pane of conditions.
 * WE-5: at most five annotation types on the map (radar, alerts, roads, work zones, position).
 */
class WeatherCarScreen(carContext: CarContext) : Screen(carContext) {
    private var conditions: Map<String, Any?> = emptyMap()
    private val surface = FlutterSurface(carContext) { c -> conditions = c; invalidate() }

    init {
        carContext.getCarService(AppManager::class.java).setSurfaceCallback(surface)
    }

    override fun onGetTemplate(): Template {
        // Keep the pane short: on a 6-inch head unit every row is big. One row for conditions,
        // one each for an alert or road hazard only when there is one. Attribution rides in the
        // header title so it costs no row (© OpenStreetMap is a licence requirement).
        val temp = conditions["temp"] as? String
        val wind = conditions["wind"] as? String
        val rows = Pane.Builder()
        rows.addRow(
            Row.Builder()
                .setTitle(if (temp == null) "Locating…" else "$temp · ${conditions["sky"] ?: ""}")
                .apply { if (wind != null) addText("Wind $wind") }
                .build(),
        )
        (conditions["alert"] as? String)?.let { rows.addRow(Row.Builder().setTitle(it).build()) }
        (conditions["roads"] as? String)?.let { rows.addRow(Row.Builder().setTitle(it).build()) }

        val pane = PaneTemplate.Builder(rows.build())
            .setHeader(Header.Builder().setTitle("orcweather · © OpenStreetMap · LibreWXR · NWS").setStartHeaderAction(Action.APP_ICON).build())
            .build()

        val zoomIn = Action.Builder()
            .setIcon(CarIcon.Builder(IconCompat.createWithResource(carContext, R.drawable.ic_car_zoom_in)).build())
            .setOnClickListener { surface.zoomBy(1.0) }.build()
        val zoomOut = Action.Builder()
            .setIcon(CarIcon.Builder(IconCompat.createWithResource(carContext, R.drawable.ic_car_zoom_out)).build())
            .setOnClickListener { surface.zoomBy(-1.0) }.build()

        val recenter = Action.Builder()
            .setIcon(CarIcon.Builder(IconCompat.createWithResource(carContext, R.drawable.ic_car_recenter)).build())
            .setOnClickListener { surface.recenter() }.build()

        return MapWithContentTemplate.Builder()
            .setContentTemplate(pane)
            .setMapController(
                MapController.Builder()
                    // Action.PAN must be in the strip or the host delivers no onScroll/onScale/onFling
                    // (MapController.Builder reference); max four actions, so this is the full set.
                    .setPanModeListener(PanModeListener { inPan -> surface.setPanMode(inPan) })
                    .setMapActionStrip(ActionStrip.Builder().addAction(Action.PAN).addAction(zoomIn).addAction(zoomOut).addAction(recenter).build())
                    .build(),
            )
            .build()
    }
}
