package com.pricehud.price_hud

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "pricehud/overlay"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "canDrawOverlays" -> result.success(canDrawOverlays())
                "isOverlayRunning" -> result.success(PriceOverlayService.isRunning)
                "openOverlaySettings" -> {
                    openOverlaySettings()
                    result.success(null)
                }
                "startOverlay" -> {
                    if (!canDrawOverlays()) {
                        result.error("overlay_permission_missing", "Overlay permission is required.", null)
                        return@setMethodCallHandler
                    }
                    val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                    val intent = Intent(this, PriceOverlayService::class.java).apply {
                        action = PriceOverlayService.ACTION_START
                        putExtra(PriceOverlayService.EXTRA_SYMBOL, args["symbol"] as? String ?: "BTCUSDT")
                        putExtra(PriceOverlayService.EXTRA_OPACITY, (args["opacity"] as? Number)?.toDouble() ?: 1.0)
                        putExtra(PriceOverlayService.EXTRA_TRANSPARENCY, (args["transparency"] as? Number)?.toDouble() ?: 0.18)
                        putExtra(PriceOverlayService.EXTRA_COLOR, (args["color"] as? Number)?.toLong() ?: 0xFF050608L)
                        putExtra(PriceOverlayService.EXTRA_RADIUS, (args["cornerRadius"] as? Number)?.toDouble() ?: 16.0)
                        putExtra(PriceOverlayService.EXTRA_TEXT_SIZE, (args["textSize"] as? Number)?.toDouble() ?: 18.0)
                        putExtra(PriceOverlayService.EXTRA_WIDGET_SCALE, (args["widgetScale"] as? Number)?.toDouble() ?: 1.0)
                        putExtra(PriceOverlayService.EXTRA_WIDGET_LAYOUT, args["widgetLayout"] as? String ?: "pill")
                        putExtra(PriceOverlayService.EXTRA_FLASH_ENABLED, args["priceFlashEnabled"] as? Boolean ?: true)
                        putExtra(PriceOverlayService.EXTRA_SHOW_DECIMALS, args["showDecimals"] as? Boolean ?: true)
                        putExtra(PriceOverlayService.EXTRA_LOCK_POSITION, args["lockPosition"] as? Boolean ?: false)
                        putExtra(PriceOverlayService.EXTRA_MT5_BACKEND_URL, args["mt5BackendUrl"] as? String ?: "")
                        putExtra(PriceOverlayService.EXTRA_MT5_DEVICE_TOKEN, args["mt5DeviceToken"] as? String ?: "")
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopOverlay" -> {
                    stopService(Intent(this, PriceOverlayService::class.java).apply {
                        action = PriceOverlayService.ACTION_STOP
                    })
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canDrawOverlays(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        if (Settings.canDrawOverlays(this)) {
            return true
        }
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_SYSTEM_ALERT_WINDOW,
                android.os.Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_SYSTEM_ALERT_WINDOW,
                android.os.Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openOverlaySettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName")
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
