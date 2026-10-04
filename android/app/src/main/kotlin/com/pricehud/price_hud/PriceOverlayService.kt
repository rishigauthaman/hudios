package com.pricehud.price_hud

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.text.TextUtils
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

class PriceOverlayService : Service() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var windowManager: WindowManager
    private lateinit var preferences: SharedPreferences

    private var bubbleView: LinearLayout? = null
    private var closeTarget: TextView? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var priceThread: Thread? = null
    private var running = false
    private var expanded = false

    private var symbol = "BTCUSDT"
    private var previousPrice = 0.0
    private var latestPrice = 0.0
    private var priceError: String? = null
    private var opacity = 1.0
    private var transparency = 0.18
    private var overlayColor = 0xFF050608.toInt()
    private var cornerRadius = 16.0
    private var textSize = 18.0
    private var widgetScale = 1.0
    private var widgetLayout = LAYOUT_PILL
    private var flashEnabled = true
    private var showDecimals = true
    private var lockPosition = false
    private var mt5BackendUrl = ""
    private var mt5DeviceToken = ""

    private lateinit var symbolText: TextView
    private lateinit var priceText: TextView
    private lateinit var changeText: TextView
    private lateinit var updatedText: TextView

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        preferences = getSharedPreferences("pricehud_overlay", MODE_PRIVATE)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START, null -> {
                readIntent(intent)
                isRunning = true
                startForeground(NOTIFICATION_ID, buildNotification())
                showOverlay()
                startPriceLoop()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        isRunning = false
        priceThread?.interrupt()
        removeOverlay()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun readIntent(intent: Intent?) {
        val nextSymbol = intent?.getStringExtra(EXTRA_SYMBOL)?.uppercase(Locale.US) ?: symbol
        if (nextSymbol != symbol) {
            previousPrice = 0.0
            latestPrice = 0.0
            priceError = null
        }
        symbol = nextSymbol
        opacity = intent?.getDoubleExtra(EXTRA_OPACITY, opacity) ?: opacity
        transparency = intent?.getDoubleExtra(EXTRA_TRANSPARENCY, transparency) ?: transparency
        overlayColor = intent?.getLongExtra(EXTRA_COLOR, overlayColor.toLong())?.toInt() ?: overlayColor
        cornerRadius = intent?.getDoubleExtra(EXTRA_RADIUS, cornerRadius) ?: cornerRadius
        textSize = intent?.getDoubleExtra(EXTRA_TEXT_SIZE, textSize) ?: textSize
        widgetScale = intent?.getDoubleExtra(EXTRA_WIDGET_SCALE, widgetScale) ?: widgetScale
        widgetLayout = normalizedLayout(intent?.getStringExtra(EXTRA_WIDGET_LAYOUT) ?: widgetLayout)
        flashEnabled = intent?.getBooleanExtra(EXTRA_FLASH_ENABLED, flashEnabled) ?: flashEnabled
        showDecimals = intent?.getBooleanExtra(EXTRA_SHOW_DECIMALS, showDecimals) ?: showDecimals
        lockPosition = intent?.getBooleanExtra(EXTRA_LOCK_POSITION, lockPosition) ?: lockPosition
        mt5BackendUrl = intent?.getStringExtra(EXTRA_MT5_BACKEND_URL)?.trim() ?: mt5BackendUrl
        mt5DeviceToken = intent?.getStringExtra(EXTRA_MT5_DEVICE_TOKEN)?.trim() ?: mt5DeviceToken
    }

    private fun showOverlay() {
        if (bubbleView != null) {
            applyAppearance()
            updateBubbleTexts()
            return
        }

        bubbleView = buildBubbleView().also { view ->
            bubbleParams = WindowManager.LayoutParams(
                overlayWidth(),
                overlayHeight(),
                overlayWindowType(),
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = clampInitialX(preferences.getInt(KEY_X, dp(28)))
                y = clampInitialY(preferences.getInt(KEY_Y, dp(180)))
            }
            windowManager.addView(view, bubbleParams)
            applyAppearance()
        }
    }

    private fun buildBubbleView(): LinearLayout {
        symbolText = TextView(this).apply {
            setTextColor(withAlpha(textColor(), 215))
            textSize = 13f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            includeFontPadding = false
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }
        priceText = TextView(this).apply {
            setTextColor(textColor())
            textSize = scaledPriceTextSize().toFloat()
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            includeFontPadding = false
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }
        changeText = TextView(this).apply {
            setTextColor(withAlpha(textColor(), 190))
            textSize = 12f
            visibility = View.GONE
            includeFontPadding = false
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }
        updatedText = TextView(this).apply {
            setTextColor(withAlpha(textColor(), 150))
            textSize = 11f
            visibility = View.GONE
            includeFontPadding = false
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }

        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = bubbleBackground(Color.TRANSPARENT)
            elevation = dp(10).toFloat()
            addView(symbolText)
            addView(priceText)
            addView(changeText)
            addView(updatedText)
            applyLayoutMetrics(this)
            setOnTouchListener(DragTouchListener())
            setOnLongClickListener {
                openApp()
                true
            }
            updateBubbleTexts()
        }
    }

    private fun applyAppearance() {
        val textColor = textColor()
        symbolText.setTextColor(withAlpha(textColor, 215))
        priceText.setTextColor(textColor)
        priceText.textSize = scaledPriceTextSize().toFloat()
        symbolText.textSize = scaledSymbolTextSize().toFloat()
        changeText.textSize = (12.0 * scale()).toFloat()
        updatedText.textSize = (11.0 * scale()).toFloat()
        changeText.setTextColor(withAlpha(textColor, 190))
        updatedText.setTextColor(withAlpha(textColor, 150))
        bubbleView?.background = bubbleBackground(Color.TRANSPARENT)
        bubbleView?.let { applyLayoutMetrics(it) }
    }

    private fun updateBubbleTexts() {
        symbolText.text = compactSymbol(symbol)
        priceText.text = if (latestPrice > 0) formatPrice(latestPrice) else priceError ?: "Loading"
        val detailsVisible = expanded && !isCompactLayout()
        changeText.visibility = if (detailsVisible) View.VISIBLE else View.GONE
        updatedText.visibility = if (detailsVisible) View.VISIBLE else View.GONE

        if (latestPrice > 0 && previousPrice > 0) {
            val change = ((latestPrice - previousPrice) / previousPrice) * 100
            val down = latestPrice < previousPrice
            changeText.text = "${if (down) "DOWN" else "UP"} ${String.format(Locale.US, "%.3f", change)}%"
            changeText.setTextColor(
                if (!flashEnabled) {
                    withAlpha(textColor(), 190)
                } else if (down) {
                    Color.rgb(248, 113, 113)
                } else {
                    Color.rgb(74, 222, 128)
                }
            )
        }
        updatedText.text = "Long press settings"
    }

    private fun setExpanded(value: Boolean) {
        expanded = value && !isCompactLayout()
        bubbleView?.let { applyLayoutMetrics(it) }
        updateBubbleTexts()
    }

    private fun applyLayoutMetrics(view: LinearLayout) {
        val scale = scale()
        val compact = isCompactLayout()
        view.gravity = if (compact) Gravity.CENTER else Gravity.START
        symbolText.gravity = if (compact) Gravity.CENTER else Gravity.START
        priceText.gravity = if (compact) Gravity.CENTER else Gravity.START
        changeText.gravity = Gravity.START
        updatedText.gravity = Gravity.START

        val horizontalPadding = if (compact) 8.0 * scale else 10.0 * scale
        val verticalPadding = if (compact) 8.0 * scale else if (expanded) 11.0 * scale else 8.0 * scale
        view.setPadding(
            dp(horizontalPadding),
            dp(verticalPadding),
            dp(horizontalPadding),
            dp(verticalPadding)
        )
        view.minimumWidth = when {
            compact -> overlaySide()
            expanded -> dp(210.0 * scale)
            else -> dp(74.0 * scale)
        }
        view.minimumHeight = if (compact) overlaySide() else 0

        bubbleParams?.let { params ->
            val nextWidth = overlayWidth()
            val nextHeight = overlayHeight()
            val oldX = params.x
            val oldY = params.y
            params.x = clampInitialX(params.x)
            params.y = clampInitialY(params.y)
            if (params.width != nextWidth || params.height != nextHeight || params.x != oldX || params.y != oldY) {
                params.width = nextWidth
                params.height = nextHeight
                bubbleView?.let { current -> windowManager.updateViewLayout(current, params) }
            }
        }
        view.requestLayout()
    }

    private fun isCompactLayout(): Boolean {
        return widgetLayout == LAYOUT_SQUARE || widgetLayout == LAYOUT_CIRCLE
    }

    private fun overlayWidth(): Int {
        return if (isCompactLayout()) overlaySide() else WindowManager.LayoutParams.WRAP_CONTENT
    }

    private fun overlayHeight(): Int {
        return if (isCompactLayout()) overlaySide() else WindowManager.LayoutParams.WRAP_CONTENT
    }

    private fun overlaySide(): Int = dp(96.0 * scale())

    private fun scaledPriceTextSize(): Double {
        val multiplier = if (isCompactLayout()) 0.9 else 1.0
        return (textSize * scale() * multiplier).coerceIn(10.0, 34.0)
    }

    private fun scaledSymbolTextSize(): Double {
        return ((if (isCompactLayout()) 12.0 else 13.0) * scale()).coerceIn(9.0, 18.0)
    }

    private fun scale(): Double = widgetScale.coerceIn(0.75, 1.6)

    private fun normalizedLayout(value: String): String {
        return when (value.lowercase(Locale.US)) {
            LAYOUT_SQUARE -> LAYOUT_SQUARE
            LAYOUT_CIRCLE -> LAYOUT_CIRCLE
            else -> LAYOUT_PILL
        }
    }

    private fun startPriceLoop() {
        running = false
        priceThread?.interrupt()
        running = true
        priceThread = Thread {
            while (running && !Thread.currentThread().isInterrupted) {
                val price = fetchPrice(symbol)
                if (price != null) {
                    mainHandler.post {
                        priceError = null
                        previousPrice = if (latestPrice > 0) latestPrice else price
                        latestPrice = price
                        flashBubble(price >= previousPrice)
                        updateBubbleTexts()
                    }
                } else {
                    mainHandler.post {
                        if (latestPrice <= 0) {
                            if (priceError == null) priceError = "No live rate"
                            updateBubbleTexts()
                        }
                    }
                }
                try {
                    Thread.sleep(1000)
                } catch (_: InterruptedException) {
                    return@Thread
                }
            }
        }.apply {
            name = "PriceHUD-price-loop"
            start()
        }
    }

    private fun fetchPrice(symbol: String): Double? {
        return if (SUPPORTED_BINANCE_SYMBOLS.contains(symbol)) {
            fetchBinancePrice(symbol)
        } else if (MT5_SYMBOLS.contains(symbol)) {
            fetchMt5Price(symbol)
        } else {
            null
        }
    }

    private fun fetchMt5Price(symbol: String): Double? {
        return try {
            if (!mt5BackendUrl.startsWith("https://") || mt5DeviceToken.length < 32) {
                mainHandler.post {
                    priceError = "Activate MT5 in the app"
                    if (latestPrice <= 0) updateBubbleTexts()
                }
                return null
            }
            val url = URL("${mt5BackendUrl.trimEnd('/')}/v1/quotes/$symbol")
            val connection = (url.openConnection() as HttpURLConnection).apply {
                connectTimeout = 3000
                readTimeout = 3000
                requestMethod = "GET"
                setRequestProperty("Accept", "application/json")
                setRequestProperty("Authorization", "Bearer $mt5DeviceToken")
            }
            try {
                if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                    val message = if (connection.responseCode == 503) "MT5 price unavailable" else "MT5 ${connection.responseCode}"
                    mainHandler.post {
                        priceError = message
                        if (latestPrice <= 0) updateBubbleTexts()
                    }
                    return null
                }
                val body = connection.inputStream.bufferedReader().use { it.readText() }
                JSONObject(body).optDouble("midpoint").takeIf { it.isFinite() && it > 0 }
            } finally {
                connection.disconnect()
            }
        } catch (_: Exception) {
            mainHandler.post {
                priceError = "MT5 price unavailable"
                if (latestPrice <= 0) updateBubbleTexts()
            }
            null
        }
    }

    private fun fetchBinancePrice(symbol: String): Double? {
        return try {
            val url = URL("https://api.binance.com/api/v3/ticker/price?symbol=$symbol")
            val connection = (url.openConnection() as HttpURLConnection).apply {
                connectTimeout = 4500
                readTimeout = 4500
                requestMethod = "GET"
            }
            connection.inputStream.bufferedReader().use { reader ->
                val body = reader.readText()
                val match = Regex("\"price\"\\s*:\\s*\"([0-9.]+)\"").find(body)
                match?.groupValues?.getOrNull(1)?.toDoubleOrNull()
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun mockPrice(symbol: String): Double {
        val seed = MOCK_PRICES[symbol] ?: 100.0
        val base = if (latestPrice > 0) latestPrice else seed
        val drift = ((System.currentTimeMillis() % 17) - 8) / 10000.0
        return max(0.0001, base * (1 + drift))
    }

    private fun flashBubble(up: Boolean) {
        if (!flashEnabled || latestPrice == previousPrice) return
        val flashColor = if (up) Color.rgb(22, 163, 74) else Color.rgb(220, 38, 38)
        bubbleView?.background = bubbleBackground(withAlpha(flashColor, 70))
        mainHandler.postDelayed({
            bubbleView?.background = bubbleBackground(Color.TRANSPARENT)
        }, 260)
    }

    private fun showCloseTarget() {
        if (closeTarget != null) return
        closeTarget = TextView(this).apply {
            text = "Drag here to close"
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            textSize = 14f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(Color.argb(230, 185, 28, 28))
                cornerRadius = dp(28).toFloat()
            }
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            dp(64),
            overlayWindowType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            x = 0
            y = dp(24)
        }
        windowManager.addView(closeTarget, params)
    }

    private fun hideCloseTarget() {
        closeTarget?.let { windowManager.removeView(it) }
        closeTarget = null
    }

    private fun isOverCloseTarget(rawY: Float): Boolean {
        val displayHeight = resources.displayMetrics.heightPixels
        return rawY > displayHeight - dp(120)
    }

    private fun removeOverlay() {
        bubbleView?.let { windowManager.removeView(it) }
        bubbleView = null
        hideCloseTarget()
    }

    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        startActivity(intent)
    }

    private fun buildNotification(): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            1,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val stopIntent = PendingIntent.getService(
            this,
            2,
            Intent(this, PriceOverlayService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("PriceHUD overlay running")
            .setContentText("Drag the bubble anywhere. Drag to the red target to close.")
            .setContentIntent(contentIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopIntent)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "PriceHUD overlay",
            NotificationManager.IMPORTANCE_LOW
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun bubbleBackground(flashColor: Int): GradientDrawable {
        return GradientDrawable().apply {
            shape = if (widgetLayout == LAYOUT_CIRCLE) {
                GradientDrawable.OVAL
            } else {
                GradientDrawable.RECTANGLE
            }
            setColor(blendColors(withAlpha(overlayColor, overlayAlpha()), flashColor))
            if (widgetLayout != LAYOUT_CIRCLE) {
                val radius = if (widgetLayout == LAYOUT_SQUARE) {
                    this@PriceOverlayService.cornerRadius.coerceIn(4.0, 22.0)
                } else {
                    this@PriceOverlayService.cornerRadius
                }
                this.cornerRadius = dp(radius).toFloat()
            }
            setStroke(1, Color.argb(26, 255, 255, 255))
        }
    }

    private fun overlayAlpha(): Int {
        return ((1 - transparency).coerceIn(0.08, 1.0) * 255).toInt()
    }

    private fun textColor(): Int {
        val red = Color.red(overlayColor) / 255.0
        val green = Color.green(overlayColor) / 255.0
        val blue = Color.blue(overlayColor) / 255.0
        val luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return if (luminance > 0.65) Color.rgb(11, 15, 20) else Color.WHITE
    }

    private fun compactSymbol(value: String): String {
        return if (value.endsWith("USDT")) value.removeSuffix("USDT") else value
    }

    private fun formatPrice(value: Double): String {
        if (!showDecimals) {
            return String.format(Locale.US, "%.0f", value)
        }

        return when {
            value >= 1000 -> String.format(Locale.US, "%.2f", value)
            value >= 1 -> String.format(Locale.US, "%.4f", value)
            else -> String.format(Locale.US, "%.6f", value)
        }
    }

    private fun overlayWindowType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun dp(value: Double): Int = (value * resources.displayMetrics.density).toInt()

    private fun clampInitialX(value: Int): Int {
        val maxX = resources.displayMetrics.widthPixels - estimatedOverlayWidth() - dp(8)
        return min(max(dp(8), value), max(dp(8), maxX))
    }

    private fun clampInitialY(value: Int): Int {
        val maxY = resources.displayMetrics.heightPixels - estimatedOverlayHeight() - dp(8)
        return min(max(dp(8), value), max(dp(8), maxY))
    }

    private fun estimatedOverlayWidth(): Int {
        return if (isCompactLayout()) overlaySide() else dp(if (expanded) 220.0 * scale() else 118.0 * scale())
    }

    private fun estimatedOverlayHeight(): Int {
        return if (isCompactLayout()) overlaySide() else dp(if (expanded) 150.0 * scale() else 58.0 * scale())
    }

    private fun withAlpha(color: Int, alpha: Int): Int {
        return Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
    }

    private fun blendColors(base: Int, overlay: Int): Int {
        if (Color.alpha(overlay) == 0) return base
        val alpha = Color.alpha(overlay) / 255f
        return Color.argb(
            max(Color.alpha(base), Color.alpha(overlay)),
            (Color.red(base) * (1 - alpha) + Color.red(overlay) * alpha).toInt(),
            (Color.green(base) * (1 - alpha) + Color.green(overlay) * alpha).toInt(),
            (Color.blue(base) * (1 - alpha) + Color.blue(overlay) * alpha).toInt()
        )
    }

    private inner class DragTouchListener : View.OnTouchListener {
        private var initialX = 0
        private var initialY = 0
        private var initialTouchX = 0f
        private var initialTouchY = 0f
        private var downTime = 0L
        private var moved = false
        private var lastTapTime = 0L

        override fun onTouch(view: View, event: MotionEvent): Boolean {
            val params = bubbleParams ?: return false
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    downTime = System.currentTimeMillis()
                    moved = false
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    showCloseTarget()
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    if (lockPosition) {
                        return true
                    }
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (abs(dx) > dp(3) || abs(dy) > dp(3)) moved = true
                    params.x = clampX(initialX + dx, view.width)
                    params.y = clampY(initialY + dy, view.height)
                    windowManager.updateViewLayout(view, params)
                    closeTarget?.alpha = if (isOverCloseTarget(event.rawY)) 1f else 0.72f
                    return true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    hideCloseTarget()
                    if (isOverCloseTarget(event.rawY) && moved) {
                        stopSelf()
                        return true
                    }

                    preferences.edit().putInt(KEY_X, params.x).putInt(KEY_Y, params.y).apply()
                    if (!moved && System.currentTimeMillis() - downTime < 240) {
                        val now = System.currentTimeMillis()
                        if (now - lastTapTime < 280) {
                            setExpanded(false)
                            lastTapTime = 0L
                        } else {
                            setExpanded(!expanded)
                            lastTapTime = now
                        }
                    }
                    return true
                }
            }
            return false
        }

        private fun clampX(value: Int, width: Int): Int {
            val maxX = resources.displayMetrics.widthPixels - width - dp(8)
            return min(max(dp(8), value), maxX)
        }

        private fun clampY(value: Int, height: Int): Int {
            val maxY = resources.displayMetrics.heightPixels - height - dp(8)
            return min(max(dp(8), value), maxY)
        }
    }

    companion object {
        const val ACTION_START = "com.pricehud.price_hud.START_OVERLAY"
        const val ACTION_STOP = "com.pricehud.price_hud.STOP_OVERLAY"
        const val EXTRA_SYMBOL = "symbol"
        const val EXTRA_OPACITY = "opacity"
        const val EXTRA_TRANSPARENCY = "transparency"
        const val EXTRA_COLOR = "color"
        const val EXTRA_RADIUS = "radius"
        const val EXTRA_TEXT_SIZE = "textSize"
        const val EXTRA_WIDGET_SCALE = "widgetScale"
        const val EXTRA_WIDGET_LAYOUT = "widgetLayout"
        const val EXTRA_FLASH_ENABLED = "flashEnabled"
        const val EXTRA_SHOW_DECIMALS = "showDecimals"
        const val EXTRA_LOCK_POSITION = "lockPosition"
        const val EXTRA_MT5_BACKEND_URL = "mt5BackendUrl"
        const val EXTRA_MT5_DEVICE_TOKEN = "mt5DeviceToken"

        @Volatile
        var isRunning = false

        private const val CHANNEL_ID = "pricehud_overlay"
        private const val NOTIFICATION_ID = 4818
        private const val KEY_X = "x"
        private const val KEY_Y = "y"
        private const val LAYOUT_PILL = "pill"
        private const val LAYOUT_SQUARE = "square"
        private const val LAYOUT_CIRCLE = "circle"

        private val SUPPORTED_BINANCE_SYMBOLS = setOf(
            "BTCUSDT",
            "ETHUSDT",
            "BNBUSDT",
            "SOLUSDT",
            "XRPUSDT"
        )

        private val MT5_SYMBOLS = setOf("XAUUSD", "EURUSD", "GBPUSD", "USDJPY")

        private val MOCK_PRICES = mapOf(
            "XAUUSD" to 3412.20,
            "EURUSD" to 1.1725,
            "GBPUSD" to 1.3412,
            "USDJPY" to 148.22,
            "NAS100" to 22840.50,
            "US30" to 44720.80,
            "SPX500" to 6042.10
        )
    }
}
