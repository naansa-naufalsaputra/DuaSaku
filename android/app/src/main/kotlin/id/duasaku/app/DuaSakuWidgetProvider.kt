package id.duasaku.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class DuaSakuWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.duasaku_widget_layout)

            // Intent to launch the MainActivity and pass the custom action URI
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("duasaku://new_transaction")
            )
            views.setOnClickPendingIntent(R.id.btn_new_transaction, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

