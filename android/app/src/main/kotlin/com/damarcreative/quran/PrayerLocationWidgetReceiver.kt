package com.damarcreative.quran

import com.damarcreative.quran.R

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PrayerLocationWidgetReceiver : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.prayer_location_widget_layout).apply {
                setTextViewText(R.id.widget_location, widgetData.getString("location_name", "Jakarta"))
                
                val nextPrayer = widgetData.getString("next_prayer_name", "")
                val accentColor = context.getColor(R.color.accent)
                val textPrimary = context.getColor(R.color.text_primary)
                val textSecondary = context.getColor(R.color.text_secondary)

                // Update text
                setTextViewText(R.id.fajr_time, widgetData.getString("fajr_time", "--:--"))
                setTextViewText(R.id.dhuhr_time, widgetData.getString("dhuhr_time", "--:--"))
                setTextViewText(R.id.asr_time, widgetData.getString("asr_time", "--:--"))
                setTextViewText(R.id.maghrib_time, widgetData.getString("maghrib_time", "--:--"))
                setTextViewText(R.id.isha_time, widgetData.getString("isha_time", "--:--"))

                // Reset all colors
                setTextColor(R.id.fajr_label, textSecondary)
                setTextColor(R.id.fajr_time, textPrimary)
                setTextColor(R.id.dhuhr_label, textSecondary)
                setTextColor(R.id.dhuhr_time, textPrimary)
                setTextColor(R.id.asr_label, textSecondary)
                setTextColor(R.id.asr_time, textPrimary)
                setTextColor(R.id.maghrib_label, textSecondary)
                setTextColor(R.id.maghrib_time, textPrimary)
                setTextColor(R.id.isha_label, textSecondary)
                setTextColor(R.id.isha_time, textPrimary)

                // Highlight next prayer
                when (nextPrayer) {
                    "Subuh" -> {
                        setTextColor(R.id.fajr_label, accentColor)
                        setTextColor(R.id.fajr_time, accentColor)
                    }
                    "Dzuhur" -> {
                        setTextColor(R.id.dhuhr_label, accentColor)
                        setTextColor(R.id.dhuhr_time, accentColor)
                    }
                    "Ashar" -> {
                        setTextColor(R.id.asr_label, accentColor)
                        setTextColor(R.id.asr_time, accentColor)
                    }
                    "Maghrib" -> {
                        setTextColor(R.id.maghrib_label, accentColor)
                        setTextColor(R.id.maghrib_time, accentColor)
                    }
                    "Isya" -> {
                        setTextColor(R.id.isha_label, accentColor)
                        setTextColor(R.id.isha_time, accentColor)
                    }
                }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
