package com.squadly.health_connect_bridge

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.health.connect.client.PermissionController

class HealthConnectPermissionActivity : ComponentActivity() {
    companion object {
        const val EXTRA_PERMISSIONS = "health_connect_permissions"
        const val EXTRA_GRANTED_PERMISSIONS = "health_connect_granted_permissions"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val permissions = intent.getStringArrayListExtra(EXTRA_PERMISSIONS)?.toSet().orEmpty()
        if (permissions.isEmpty()) {
            setResult(RESULT_CANCELED)
            finish()
            return
        }

        val launcher = registerForActivityResult(
            PermissionController.createRequestPermissionResultContract(),
        ) { granted ->
            val result = Intent().putStringArrayListExtra(
                EXTRA_GRANTED_PERMISSIONS,
                ArrayList(granted),
            )
            setResult(RESULT_OK, result)
            finish()
        }
        launcher.launch(permissions)
    }
}
