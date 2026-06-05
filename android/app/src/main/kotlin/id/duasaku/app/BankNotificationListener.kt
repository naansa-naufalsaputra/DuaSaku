package id.duasaku.app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.content.Intent
import android.util.Log

class BankNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            val packageName = sbn.packageName ?: return
            val extras = sbn.notification.extras
            val title = extras?.getCharSequence("android.title")?.toString() ?: ""
            val text = extras?.getCharSequence("android.text")?.toString() ?: ""

            // Broadcast locally to MainActivity
            val intent = Intent(NOTIFICATION_ACTION)
            intent.putExtra("packageName", packageName)
            intent.putExtra("title", title)
            intent.putExtra("text", text)
            sendBroadcast(intent)
        } catch (e: Exception) {
            Log.e("BankNotification", "Error processing notification: ${e.message}")
        }
    }

    companion object {
        const val NOTIFICATION_ACTION = "com.duasaku.app.NOTIFICATION"
    }
}

