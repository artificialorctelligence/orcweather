package com.artificialorctelligence.orcweather.car

import android.content.Intent
import android.content.res.Configuration
import androidx.car.app.Screen
import androidx.car.app.ScreenManager
import androidx.car.app.Session
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner

class CarSession : Session() {
    private lateinit var bridge: CarBridge

    override fun onCreateScreen(intent: Intent): Screen {
        bridge = CarBridge(carContext)
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onDestroy(owner: LifecycleOwner) = bridge.destroy()
        })
        // The map is home; the acknowledgements card sits on top for five seconds, then pops.
        carContext.getCarService(ScreenManager::class.java).push(MapCarScreen(carContext, bridge))
        return SourcesScreen(carContext, autoDismiss = true)
    }

    // MR-1: light/dark follows the host. The Flutter map reads the Presentation's uiMode.
    override fun onCarConfigurationChanged(newConfiguration: Configuration) {
        carContext.getCarService(ScreenManager::class.java).top.invalidate()
    }
}
