package com.artificialorctelligence.orcweather.car

import android.content.Intent
import android.content.res.Configuration
import androidx.car.app.Screen
import androidx.car.app.Session

class CarSession : Session() {
    private var screen: WeatherCarScreen? = null

    override fun onCreateScreen(intent: Intent): Screen = WeatherCarScreen(carContext).also { screen = it }

    // MR-1: redraw light/dark when the host says so. The Flutter map reads the Presentation's uiMode,
    // which follows the car configuration; invalidating re-reads it.
    override fun onCarConfigurationChanged(newConfiguration: Configuration) {
        screen?.invalidate()
    }
}
