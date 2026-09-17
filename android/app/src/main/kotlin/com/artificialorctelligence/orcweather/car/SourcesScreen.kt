package com.artificialorctelligence.orcweather.car

import android.os.Handler
import android.os.Looper
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.Header
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner

/** Acknowledgements. Shown for five seconds at launch (then pops itself), or from the ⓘ until Back. */
class SourcesScreen(carContext: CarContext, private val autoDismiss: Boolean) : Screen(carContext) {
    private val handler = Handler(Looper.getMainLooper())
    private val dismiss = Runnable { if (screenManager.top === this) screenManager.pop() }

    init {
        if (autoDismiss) {
            lifecycle.addObserver(object : DefaultLifecycleObserver {
                override fun onStart(owner: LifecycleOwner) { handler.postDelayed(dismiss, 5_000) }
                override fun onStop(owner: LifecycleOwner) { handler.removeCallbacks(dismiss) }
            })
        }
    }

    override fun onGetTemplate(): Template {
        fun row(title: String, text: String? = null) = Row.Builder().setTitle(title).apply { if (text != null) addText(text) }.build()
        val pane = Pane.Builder()
            .addRow(row("Map data © OpenStreetMap contributors", "Open Database License"))
            .addRow(row("Weather data via LibreWXR (librewxr.net)", "Precipitation: NOAA Enterprise Rain Rate (RRQPE)"))
            .addRow(row("Conditions and warnings: US National Weather Service"))
            .addRow(row("Roads: Illinois DOT · Work zones: USDOT WZDx"))
            .addRow(row("Not an official warning source", "Estimates are marked as such"))
            .build()
        return PaneTemplate.Builder(pane)
            .setHeader(Header.Builder().setTitle("orcweather").setStartHeaderAction(if (autoDismiss) Action.APP_ICON else Action.BACK).build())
            .build()
    }
}
