package com.agiomartinez.rastreiodex

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import com.agiomartinez.rastreiodex.R
import android.app.PendingIntent
import android.net.Uri 

class TrackingWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.tracking_widget).apply {
                // Recupera os dados salvos pelo Flutter
                val title = widgetData.getString("pkg_title", "")
                val code = widgetData.getString("pkg_code", "---")
                val status = widgetData.getString("pkg_status", "Aguardando")
                val description = widgetData.getString("pkg_desc", "Sem detalhes")

                // Lógica de Visibilidade: Esconde cabeçalho se o nome for igual ao código ou vazio
                if (title.isNullOrEmpty() || title == code) {
                    setViewVisibility(R.id.header_layout, View.GONE)
                } else {
                    setViewVisibility(R.id.header_layout, View.VISIBLE)
                    setTextViewText(R.id.widget_title, title)
                }

                // CORREÇÃO DE NULIDADE: Chamada segura para lidar com String?
                val statusText = status?.uppercase() ?: "AGUARDANDO"
                val statusLower = status?.lowercase() ?: ""

                setTextViewText(R.id.widget_code, code)
                setTextViewText(R.id.widget_status, statusText)
                setTextViewText(R.id.widget_description, description)

                // Lógica de Cores e Ícones
                when {
                    statusLower.contains("entregue") -> {
                        setInt(R.id.widget_icon, "setColorFilter", Color.parseColor("#4CAF50"))
                        setImageViewResource(R.id.widget_icon, android.R.drawable.checkbox_on_background)
                    }
                    statusLower.contains("saiu") || statusLower.contains("trânsito") || statusLower.contains("transferência") -> {
                        setInt(R.id.widget_icon, "setColorFilter", Color.parseColor("#2196F3"))
                        setImageViewResource(R.id.widget_icon, android.R.drawable.ic_dialog_info)
                    }
                    else -> {
                        setInt(R.id.widget_icon, "setColorFilter", Color.parseColor("#FF9800"))
                        setImageViewResource(R.id.widget_icon, android.R.drawable.ic_menu_send)
                    }
                }

                // Lógica de Clique: Usa HomeWidgetLaunchIntent para integração correta com Flutter
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("rastreiodex://widget_click")
                )

                setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
