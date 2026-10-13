package app.resonance.resonance

import android.content.ComponentName
import android.media.AudioManager
import android.os.Handler
import android.os.HandlerThread
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaControllerCompat
import android.support.v4.media.session.PlaybackStateCompat
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import org.json.JSONObject
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Phone side of the Wear OS remote (module `:wear`).
 *
 * The watch sends `/resonance/control` messages with a UTF-8 command
 * (`toggle`, `play`, `pause`, `next`, `previous`, `volume_up`, `volume_down`,
 * `state`). The command is forwarded to Resonance's own media session
 * (audio_service MediaBrowserService) and the current state is replied on
 * `/resonance/state` as JSON. No audio is ever sent to the watch.
 */
class WearRemoteListenerService : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != CONTROL_PATH) return
        val command = String(event.data, Charsets.UTF_8).trim()
        val thread = HandlerThread("resonance-wear").apply { start() }
        try {
            val state = withController(Handler(thread.looper)) { controller ->
                apply(controller, command)
                snapshot(controller)
            } ?: JSONObject().put("connected", false)
            state.put("volume", volumePercent())
            Tasks.await(
                Wearable.getMessageClient(this)
                    .sendMessage(event.sourceNodeId, STATE_PATH, state.toString().toByteArray()),
                5,
                TimeUnit.SECONDS,
            )
        } catch (_: Exception) {
            // Watch disconnected or session unavailable: nothing else to do.
        } finally {
            thread.quitSafely()
        }
    }

    private fun apply(controller: MediaControllerCompat, command: String) {
        val controls = controller.transportControls
        when (command) {
            "play" -> controls.play()
            "pause" -> controls.pause()
            "toggle" ->
                if (controller.playbackState?.state == PlaybackStateCompat.STATE_PLAYING) {
                    controls.pause()
                } else {
                    controls.play()
                }
            "next" -> controls.skipToNext()
            "previous" -> controls.skipToPrevious()
            "volume_up" -> adjustVolume(AudioManager.ADJUST_RAISE)
            "volume_down" -> adjustVolume(AudioManager.ADJUST_LOWER)
        }
    }

    private fun snapshot(controller: MediaControllerCompat): JSONObject {
        val metadata = controller.metadata
        return JSONObject()
            .put("connected", true)
            .put("title", metadata?.getString(MediaMetadataCompat.METADATA_KEY_TITLE) ?: "")
            .put("artist", metadata?.getString(MediaMetadataCompat.METADATA_KEY_ARTIST) ?: "")
            .put("playing", controller.playbackState?.state == PlaybackStateCompat.STATE_PLAYING)
    }

    private fun adjustVolume(direction: Int) {
        val audio = getSystemService(AUDIO_SERVICE) as AudioManager
        audio.adjustStreamVolume(AudioManager.STREAM_MUSIC, direction, 0)
    }

    private fun volumePercent(): Int {
        val audio = getSystemService(AUDIO_SERVICE) as AudioManager
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
        return audio.getStreamVolume(AudioManager.STREAM_MUSIC) * 100 / max
    }

    private fun <T> withController(handler: Handler, block: (MediaControllerCompat) -> T): T? {
        val latch = CountDownLatch(1)
        var browser: MediaBrowserCompat? = null
        var controller: MediaControllerCompat? = null
        handler.post {
            browser = MediaBrowserCompat(
                this,
                ComponentName(packageName, AUDIO_SERVICE_CLASS),
                object : MediaBrowserCompat.ConnectionCallback() {
                    override fun onConnected() {
                        controller = MediaControllerCompat(this@WearRemoteListenerService, browser!!.sessionToken)
                        latch.countDown()
                    }

                    override fun onConnectionFailed() = latch.countDown()
                },
                null,
            ).also { it.connect() }
        }
        latch.await(5, TimeUnit.SECONDS)
        val result = controller?.let(block)
        // Give the transport command a moment to reach the session before reading state.
        Thread.sleep(250)
        val refreshed = controller?.let { snapshotIfJson(result, it) } ?: result
        handler.post { browser?.disconnect() }
        return refreshed
    }

    @Suppress("UNCHECKED_CAST")
    private fun <T> snapshotIfJson(result: T?, controller: MediaControllerCompat): T? =
        if (result is JSONObject) snapshot(controller) as T else result

    companion object {
        const val CONTROL_PATH = "/resonance/control"
        const val STATE_PATH = "/resonance/state"
        private const val AUDIO_SERVICE_CLASS = "com.ryanheise.audioservice.AudioService"
    }
}
