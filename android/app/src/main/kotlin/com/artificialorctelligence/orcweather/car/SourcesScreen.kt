package com.artificialorctelligence.orcweather.car

import android.os.Handler
import android.os.Looper
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.Header
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
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

    /** A list scrolls and keeps every row short enough for a 6-inch unit; a pane clips. */
    override fun onGetTemplate(): Template {
        fun row(title: String, text: String) = Row.Builder().setTitle(title).addText(text).build()
        val list = ItemList.Builder()
            .addItem(row("© OpenStreetMap contributors", "Map data, Open Database License"))
            .addItem(row("LibreWXR (librewxr.net)", "Radar and alerts"))
            .addItem(row("NOAA Enterprise Rain Rate", "Precipitation (RRQPE)"))
            .addItem(row("US National Weather Service", "Conditions and warnings"))
            .addItem(row("Illinois DOT · USDOT WZDx", "Road conditions and work zones"))
            .addItem(row("Not an official warning source", "Estimates are marked as such"))
            .build()
        return ListTemplate.Builder()
            .setSingleList(list)
            .setHeader(Header.Builder().setTitle("orcweather").setStartHeaderAction(if (autoDismiss) Action.APP_ICON else Action.BACK).build())
            .build()
    }
}
