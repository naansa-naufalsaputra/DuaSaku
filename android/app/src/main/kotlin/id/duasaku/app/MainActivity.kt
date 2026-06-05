package id.duasaku.app

import io.flutter.embedding.android.FlutterFragmentActivity
import android.view.WindowManager
import android.os.Bundle
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.ComponentName
import android.provider.Settings
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var eventSink: EventChannel.EventSink? = null
    private val NOTIFICATION_CHANNEL = "com.duasaku.app/bank_notifications"
    private val MANAGER_CHANNEL = "com.duasaku.app/bank_notification_manager"

    private val notificationReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            intent?.let {
                val packageName = it.getStringExtra("packageName") ?: ""
                val title = it.getStringExtra("title") ?: ""
                val text = it.getStringExtra("text") ?: ""

                val data = mapOf(
                    "packageName" to packageName,
                    "title" to title,
                    "text" to text
                )
                runOnUiThread {
                    eventSink?.success(data)
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // EventChannel for streaming notifications
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        // MethodChannel for permission checking and requesting
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MANAGER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPermissionGranted" -> {
                    result.success(isNotificationServiceEnabled())
                }
                "requestPermission" -> {
                    val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val cn = ComponentName(this, BankNotificationListener::class.java)
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(cn.flattenToString())
    }

    override fun onStart() {
        super.onStart()
        val filter = IntentFilter(BankNotificationListener.NOTIFICATION_ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(notificationReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(notificationReceiver, filter)
        }
    }

    override fun onStop() {
        super.onStop()
        try {
            unregisterReceiver(notificationReceiver)
        } catch (e: Exception) {
            // Ignore
        }
    }
}

