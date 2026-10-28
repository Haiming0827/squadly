package com.squadly.health_connect_bridge

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.Build
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.Instant
import java.util.concurrent.atomic.AtomicBoolean

class HealthConnectBridgePlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {
    private val channelName = "squadly/health_connect"
    private val healthPermissionRequestCode = 7315
    private val mainHandler = Handler(Looper.getMainLooper())
    private val healthScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val healthPermissions = setOf(
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        HealthPermission.getReadPermission(DistanceRecord::class),
    )

    private lateinit var applicationContext: Context
    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var pendingHealthRead: PendingHealthRead? = null

    private data class PendingHealthRead(
        val fromMillis: Long,
        val toMillis: Long,
        val result: MethodChannel.Result,
    )

    private class OneShotResult(private val delegate: MethodChannel.Result) : MethodChannel.Result {
        private val completed = AtomicBoolean(false)

        override fun success(result: Any?) {
            if (completed.compareAndSet(false, true)) delegate.success(result)
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            if (completed.compareAndSet(false, true)) {
                delegate.error(errorCode, errorMessage, errorDetails)
            }
        }

        override fun notImplemented() {
            if (completed.compareAndSet(false, true)) delegate.notImplemented()
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, channelName).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(isHealthConnectAvailable())
            "readWorkouts" -> requestHealthWorkouts(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != healthPermissionRequestCode) return false
        val pending = pendingHealthRead ?: return true
        pendingHealthRead = null
        val granted = data
            ?.getStringArrayListExtra(HealthConnectPermissionActivity.EXTRA_GRANTED_PERMISSIONS)
            ?.toSet()
            .orEmpty()
        completePermissionResult(pending, granted)
        return true
    }

    private fun completePermissionResult(
        pending: PendingHealthRead,
        granted: Set<String>,
    ) {
        if (!granted.containsAll(healthPermissions)) {
            pending.result.error("permission_denied", "Health Connect permission was not granted", null)
        } else {
            readHealthWorkouts(pending.fromMillis, pending.toMillis, pending.result)
        }
    }

    private fun isHealthConnectAvailable(): Boolean = healthConnectProviderAvailable(
        androidApiLevel = Build.VERSION.SDK_INT,
        sdkAvailableStatus = HealthConnectClient.SDK_AVAILABLE,
    ) {
        HealthConnectClient.getSdkStatus(applicationContext)
    }

    private fun requestHealthWorkouts(call: MethodCall, result: MethodChannel.Result) {
        val reply = OneShotResult(result)
        if (!isHealthConnectAvailable()) {
            reply.error("unavailable", "Health Connect is unavailable", null)
            return
        }
        val fromMillis = (call.argument<Number>("fromMillis"))?.toLong()
        val toMillis = (call.argument<Number>("toMillis"))?.toLong()
        if (fromMillis == null || toMillis == null || fromMillis >= toMillis) {
            reply.error("invalid_range", "Invalid Health Connect read range", null)
            return
        }
        if (pendingHealthRead != null) {
            reply.error("busy", "A Health Connect permission request is already active", null)
            return
        }
        healthScope.launch {
            try {
                val client = HealthConnectClient.getOrCreate(applicationContext)
                val granted = client.permissionController.getGrantedPermissions()
                withContext(Dispatchers.Main) {
                    if (granted.containsAll(healthPermissions)) {
                        readHealthWorkouts(fromMillis, toMillis, reply)
                    } else {
                        val currentActivity = activity
                        if (currentActivity == null) {
                            reply.error("unavailable", "Health Connect needs a foreground activity", null)
                            return@withContext
                        }
                        pendingHealthRead = PendingHealthRead(fromMillis, toMillis, reply)
                        currentActivity.startActivityForResult(
                            Intent(currentActivity, HealthConnectPermissionActivity::class.java)
                                .putStringArrayListExtra(
                                    HealthConnectPermissionActivity.EXTRA_PERMISSIONS,
                                    ArrayList(healthPermissions),
                                ),
                            healthPermissionRequestCode,
                        )
                    }
                }
            } catch (_: Exception) {
                mainHandler.post {
                    reply.error("health_connect_error", "Could not check Health Connect permissions", null)
                }
            }
        }
    }

    private fun readHealthWorkouts(
        fromMillis: Long,
        toMillis: Long,
        result: MethodChannel.Result,
    ) {
        healthScope.launch {
            try {
                val client = HealthConnectClient.getOrCreate(applicationContext)
                val from = Instant.ofEpochMilli(fromMillis)
                val to = Instant.ofEpochMilli(toMillis)
                val sessions = mutableListOf<ExerciseSessionRecord>()
                var pageToken: String? = null
                do {
                    val response = client.readRecords(
                        ReadRecordsRequest(
                            recordType = ExerciseSessionRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(from, to),
                            pageToken = pageToken,
                        ),
                    )
                    sessions.addAll(response.records)
                    pageToken = response.pageToken
                } while (!pageToken.isNullOrEmpty())

                val workouts = mutableListOf<Map<String, Any>>()
                for (session in sessions) {
                    val kind = when (session.exerciseType) {
                        ExerciseSessionRecord.EXERCISE_TYPE_RUNNING,
                        ExerciseSessionRecord.EXERCISE_TYPE_RUNNING_TREADMILL -> "run"
                        ExerciseSessionRecord.EXERCISE_TYPE_HIKING -> "hike"
                        else -> continue
                    }
                    val distanceMeters = readDistanceMeters(client, session)
                    if (!distanceMeters.isFinite() || distanceMeters <= 0.0) continue
                    workouts.add(
                        mapOf(
                            "id" to session.metadata.id,
                            "kind" to kind,
                            "startedAtMillis" to session.startTime.toEpochMilli(),
                            "endedAtMillis" to session.endTime.toEpochMilli(),
                            "distanceMeters" to distanceMeters,
                        ),
                    )
                }
                mainHandler.post { result.success(workouts) }
            } catch (_: Exception) {
                mainHandler.post {
                    result.error("health_connect_error", "Could not read Health Connect workout records", null)
                }
            }
        }
    }

    private suspend fun readDistanceMeters(
        client: HealthConnectClient,
        session: ExerciseSessionRecord,
    ): Double {
        var pageToken: String? = null
        var distanceMeters = 0.0
        do {
            val response = client.readRecords(
                ReadRecordsRequest(
                    recordType = DistanceRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        session.startTime,
                        session.endTime,
                    ),
                    pageToken = pageToken,
                ),
            )
            distanceMeters += response.records
                .asSequence()
                .filter {
                    it.metadata.dataOrigin.packageName ==
                        session.metadata.dataOrigin.packageName
                }
                .sumOf { it.distance.inMeters }
            pageToken = response.pageToken
        } while (!pageToken.isNullOrEmpty())
        return distanceMeters
    }
}

internal fun healthConnectProviderAvailable(
    androidApiLevel: Int,
    sdkAvailableStatus: Int,
    sdkStatus: () -> Int,
): Boolean = androidApiLevel >= Build.VERSION_CODES.P && sdkStatus() == sdkAvailableStatus
