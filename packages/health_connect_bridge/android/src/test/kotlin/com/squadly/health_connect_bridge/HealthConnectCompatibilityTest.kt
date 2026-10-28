package com.squadly.health_connect_bridge

import androidx.health.connect.client.HealthConnectClient
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HealthConnectCompatibilityTest {
    @Test
    fun api27DoesNotQueryProviderEvenIfTheSdkWouldReportAvailable() {
        var sdkWasQueried = false

        val available = healthConnectProviderAvailable(
            androidApiLevel = 27,
            sdkAvailableStatus = HealthConnectClient.SDK_AVAILABLE,
        ) {
            sdkWasQueried = true
            HealthConnectClient.SDK_AVAILABLE
        }

        assertFalse(available)
        assertFalse(sdkWasQueried)
    }

    @Test
    fun api28AndAboveRequireAnInstalledAvailableProvider() {
        val api28Available = healthConnectProviderAvailable(
            androidApiLevel = 28,
            sdkAvailableStatus = HealthConnectClient.SDK_AVAILABLE,
        ) { HealthConnectClient.SDK_AVAILABLE }
        val api33MissingProvider = healthConnectProviderAvailable(
            androidApiLevel = 33,
            sdkAvailableStatus = HealthConnectClient.SDK_AVAILABLE,
        ) { HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED }
        val api34Available = healthConnectProviderAvailable(
            androidApiLevel = 34,
            sdkAvailableStatus = HealthConnectClient.SDK_AVAILABLE,
        ) { HealthConnectClient.SDK_AVAILABLE }

        assertTrue(api28Available)
        assertFalse(api33MissingProvider)
        assertTrue(api34Available)
    }
}
