package com.spotnik.pontual

import android.content.Context
import android.location.GnssStatus
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import java.lang.reflect.Method

// Streams GNSS signal quality (satellites in view and in fix, mean
// carrier-to-noise density) to Dart while a trip listens. No coordinates
// cross this channel, only signal quality, so it carries no location
// data and needs no permission beyond the location grant the trip
// already holds. Registered from MainActivity.
// See DECISIONS.md D68.
class GnssQualityPlugin : FlutterPlugin, EventChannel.StreamHandler {
    companion object {
        const val CHANNEL = "pontual/gnss_quality"
        private const val MIN_INTERVAL_MS = 1000L

        // usedInFix(int) exists since API 30. On API 24-29 the only public
        // spelling is getUsedInFix(int), which was dropped from the API 35+
        // compile stubs, so it is reached reflectively there.
        // See DECISIONS.md#D72.
        private val legacyUsedInFix: Method? by lazy {
            try {
                GnssStatus::class.java.getMethod("getUsedInFix", Integer.TYPE)
            } catch (e: NoSuchMethodException) {
                null
            } catch (e: SecurityException) {
                null
            }
        }

        private fun isUsedInFix(status: GnssStatus, index: Int): Boolean {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                return status.usedInFix(index)
            }
            val method = legacyUsedInFix ?: return false
            return try {
                method.invoke(status, index) as? Boolean ?: false
            } catch (e: ReflectiveOperationException) {
                false
            }
        }
    }

    private var channel: EventChannel? = null
    private var appContext: Context? = null
    private var active: ActiveListener? = null

    private data class ActiveListener(
        val manager: LocationManager,
        val callback: GnssStatus.Callback,
    )

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = EventChannel(binding.binaryMessenger, CHANNEL).also {
            it.setStreamHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopListening()
        channel?.setStreamHandler(null)
        channel = null
        appContext = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        stopListening()
        val context = appContext
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N || context == null || events == null) {
            events?.error("unavailable", "GNSS status needs API 24", null)
            return
        }
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        if (manager == null) {
            events.error("unavailable", "no location manager", null)
            return
        }
        val callback = QualityCallback(events)
        try {
            manager.registerGnssStatusCallback(callback, Handler(Looper.getMainLooper()))
        } catch (e: SecurityException) {
            events.error("permission", "location permission needed", null)
            return
        }
        active = ActiveListener(manager, callback)
    }

    override fun onCancel(arguments: Any?) {
        stopListening()
    }

    private fun stopListening() {
        val current = active
        active = null
        if (current != null) {
            try {
                current.manager.unregisterGnssStatusCallback(current.callback)
            } catch (e: Exception) {
                // Best effort: the trip is ending anyway.
            }
        }
    }

    private class QualityCallback(
        private val events: EventChannel.EventSink,
    ) : GnssStatus.Callback() {
        private var lastSentMs: Long = 0

        override fun onSatelliteStatusChanged(status: GnssStatus) {
            val now = SystemClock.elapsedRealtime()
            if (now - lastSentMs < MIN_INTERVAL_MS) {
                return
            }
            lastSentMs = now
            var used = 0
            var snrSum = 0.0
            val total = status.satelliteCount
            for (i in 0 until total) {
                if (isUsedInFix(status, i)) {
                    used += 1
                    snrSum += status.getCn0DbHz(i)
                }
            }
            val mean = if (used > 0) (snrSum / used * 10).toInt() / 10.0 else 0.0
            try {
                events.success(
                    mapOf(
                        "satsUsed" to used,
                        "satsView" to total,
                        "meanSnrDb" to mean,
                    ),
                )
            } catch (e: Exception) {
                // Sink gone (trip ended mid-send): the next status update
                // is throttled anyway, and onCancel unregisters us.
            }
        }
    }
}
