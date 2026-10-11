package com.squadly.squadly

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "squadly/notifications"
    private val permissionRequestCode = 7314
    private var pendingPushResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestMiPushToken" -> requestMiPushToken(result)
                    "unregisterMiPush" -> {
                        unregisterMiPush()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestMiPushToken(result: MethodChannel.Result) {
        if (!BuildConfig.MIPUSH_ENABLED) {
            result.success(null)
            return
        }
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(
                this, Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingPushResult = result
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), permissionRequestCode)
            return
        }
        registerAndReadMiPushToken(result)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequestCode) return
        val result = pendingPushResult ?: return
        pendingPushResult = null
        if (grantResults.firstOrNull() != PackageManager.PERMISSION_GRANTED) {
            result.error("permission_denied", "Notification permission was not granted", null)
        } else {
            registerAndReadMiPushToken(result)
        }
    }

    private fun registerAndReadMiPushToken(result: MethodChannel.Result) {
        try {
            val sdk = Class.forName("com.xiaomi.mipush.sdk.MiPushClient")
            sdk.getMethod("registerPush", android.content.Context::class.java, String::class.java, String::class.java)
                .invoke(null, applicationContext, BuildConfig.MIPUSH_APP_ID, BuildConfig.MIPUSH_APP_KEY)
            readMiPushToken(sdk, result, 0)
        } catch (error: ReflectiveOperationException) {
            result.error("unavailable", "Mi Push SDK is not available in this build", null)
        }
    }

    private fun readMiPushToken(sdk: Class<*>, result: MethodChannel.Result, attempt: Int) {
        try {
            val token = sdk.getMethod("getRegId", android.content.Context::class.java)
                .invoke(null, applicationContext) as? String
            if (!token.isNullOrBlank()) {
                result.success(token)
            } else if (attempt >= 20) {
                result.success(null)
            } else {
                mainHandler.postDelayed({ readMiPushToken(sdk, result, attempt + 1) }, 500)
            }
        } catch (error: ReflectiveOperationException) {
            result.error("unavailable", "Mi Push could not read a registration token", null)
        }
    }

    private fun unregisterMiPush() {
        if (!BuildConfig.MIPUSH_ENABLED) return
        try {
            Class.forName("com.xiaomi.mipush.sdk.MiPushClient")
                .getMethod("unregisterPush", android.content.Context::class.java)
                .invoke(null, applicationContext)
        } catch (_: ReflectiveOperationException) {
            // Best effort: the server-side token is independently revoked.
        }
    }
}
