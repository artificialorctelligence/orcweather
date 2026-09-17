package com.artificialorctelligence.orcweather.car

import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.SessionInfo
import androidx.car.app.validation.HostValidator

/** Entry point Android Auto binds to. One [CarSession] per connection. */
class OrcCarAppService : CarAppService() {
    // ponytail: accept any host while developing (the DHU is unsigned); ship with
    // HostValidator.Builder(applicationContext).addAllowedHosts(R.array.hosts_allowlist_sample).build()
    override fun createHostValidator(): HostValidator = HostValidator.ALLOW_ALL_HOSTS_VALIDATOR

    override fun onCreateSession(sessionInfo: SessionInfo): Session = CarSession()
}
