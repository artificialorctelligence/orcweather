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
        // Straight to the map; licence attribution is drawn on the map surface (5 s, then an (i) chip).
        return MapCarScreen(carContext, bridge)
    }

    // MR-1: light/dark follows the host. The Flutter map reads the Presentation's uiMode.
    override fun onCarConfigurationChanged(newConfiguration: Configuration) {
        carContext.getCarService(ScreenManager::class.java).top.invalidate()
    }
}
