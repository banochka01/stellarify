package app.resonance.resonance

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.view.KeyEvent
import android.widget.RemoteViews
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * Home-screen widget: cover, title, play/pause, next and "Моя волна".
 *
 * Play/pause and next are sent as media-button events to audio_service, so
 * they reach the running media session. "Моя волна" opens the app with a
 * quick action that Dart handles (see lib/core/playback/android_home_widget.dart).
 */
class ResonanceWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        render(context, manager, appWidgetIds)
    }

    companion object {
        private const val PREFS = "resonance_widget"
        private const val COVER_FILE = "widget_cover.png"
        const val ACTION_QUICK = "app.resonance.ACTION_QUICK"
        const val EXTRA_ACTION = "action"
        private val io = Executors.newSingleThreadExecutor()

        /** Called from Dart with the now-playing snapshot. */
        fun update(context: Context, title: String, artist: String, artworkUrl: String?, playing: Boolean) {
            val app = context.applicationContext
            val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val previousArtwork = prefs.getString("artworkUrl", null)
            prefs.edit()
                .putString("title", title)
                .putString("artist", artist)
                .putString("artworkUrl", artworkUrl)
                .putBoolean("playing", playing)
                .apply()
            refresh(app)
            if (artworkUrl != previousArtwork) {
                io.execute {
                    val file = File(app.filesDir, COVER_FILE)
                    val bitmap = artworkUrl?.let(::downloadCover)
                    if (bitmap == null) {
                        file.delete()
                    } else {
                        file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                    }
                    refresh(app)
                }
            }
        }

        private fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, ResonanceWidgetProvider::class.java))
            if (ids.isNotEmpty()) render(context, manager, ids)
        }

        private fun downloadCover(url: String): Bitmap? = try {
            if (!url.startsWith("https://") && !url.startsWith("http://")) {
                null
            } else {
                val connection = URL(url).openConnection() as HttpURLConnection
                connection.connectTimeout = 8_000
                connection.readTimeout = 8_000
                connection.inputStream.use { stream ->
                    BitmapFactory.decodeStream(stream)?.let { source ->
                        // RemoteViews bitmaps must stay small.
                        Bitmap.createScaledBitmap(source, 256, 256, true)
                    }
                }
            }
        } catch (_: Exception) {
            null
        }

        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.resonance_widget)
            views.setTextViewText(R.id.widget_title, prefs.getString("title", null) ?: "Resonance")
            views.setTextViewText(
                R.id.widget_artist,
                prefs.getString("artist", null) ?: context.getString(R.string.widget_idle),
            )
            val playing = prefs.getBoolean("playing", false)
            views.setImageViewResource(
                R.id.widget_play,
                if (playing) R.drawable.ic_widget_pause else R.drawable.ic_widget_play,
            )
            val cover = File(context.filesDir, COVER_FILE)
            val bitmap = if (cover.exists()) BitmapFactory.decodeFile(cover.path) else null
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_cover, bitmap)
            } else {
                views.setImageViewResource(R.id.widget_cover, R.mipmap.ic_launcher)
            }
            views.setOnClickPendingIntent(
                R.id.widget_play,
                mediaButton(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, 1),
            )
            views.setOnClickPendingIntent(
                R.id.widget_next,
                mediaButton(context, KeyEvent.KEYCODE_MEDIA_NEXT, 2),
            )
            views.setOnClickPendingIntent(R.id.widget_wave, openApp(context, "wave", 3))
            views.setOnClickPendingIntent(R.id.widget_cover, openApp(context, null, 4))
            manager.updateAppWidget(ids, views)
        }

        private fun mediaButton(context: Context, keyCode: Int, requestCode: Int): PendingIntent {
            val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                component = ComponentName(context, "com.ryanheise.audioservice.MediaButtonReceiver")
                putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
            }
            return PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun openApp(context: Context, action: String?, requestCode: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                this.action = if (action == null) Intent.ACTION_MAIN else ACTION_QUICK
                if (action != null) putExtra(EXTRA_ACTION, action)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            return PendingIntent.getActivity(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
