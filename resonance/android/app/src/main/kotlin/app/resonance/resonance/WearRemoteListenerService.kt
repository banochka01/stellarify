package app.resonance.resonance

import android.content.ComponentName
import android.media.AudioManager
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaControllerCompat
import android.support.v4.media.session.PlaybackStateCompat
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
 * `state`). Commands go to Resonance's own media session through one
 * MediaController kept for the service lifetime; state changes are pushed back
 * on `/resonance/state` as JSON. No audio is ever sent to the watch.
 */
class WearRemoteListenerService : WearableListenerService() {
    private var browser: MediaBrowserCompat? = null
    @Volatile private var controller: MediaControllerCompat? = null
    private val connected = CountDownLatch(1)
    @Volatile private var watchNodeId: String? = null

    private val controllerCallback = object : MediaControllerCompat.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackStateCompat?) = pushState()
        override fun onMetadataChanged(metadata: MediaMetadataCompat?) = pushState()
    }

    override fun onCreate() {
        super.onCreate()
        // Created on the main thread; callbacks arrive on the main looper.
        browser = MediaBrowserCompat(
            this,
            ComponentName(this, ResonanceBrowserService.AUDIO_SERVICE_CLASS),
            object : MediaBrowserCompat.ConnectionCallback() {
                override fun onConnected() {
                    val token = browser?.sessionToken ?: return
                    controller = MediaControllerCompat(this@WearRemoteListenerService, token).also {
                        it.registerCallback(controllerCallback)
                    }
                    connected.countDown()
                }

                override fun onConnectionFailed() = connected.countDown()
            },
            null,
        ).also { it.connect() }
    }

    override fun onDestroy() {
        controller?.unregisterCallback(controllerCallback)
        browser?.disconnect()
        super.onDestroy()
    }

    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != CONTROL_PATH) return
        watchNodeId = event.sourceNodeId
        // onMessageReceived runs on a binder worker thread, not the main one.
        connected.await(5, TimeUnit.SECONDS)
        val current = controller
        val command = String(event.data, Charsets.UTF_8).trim()
        if (current != null) apply(current, command)
        // Transport commands answer through controllerCallback; volume and
        // `state` requests do not change the session, so reply directly.
        if (current == null || command in setOf("state", "volume_up", "volume_down")) pushState()
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

    private fun pushState() {
        val node = watchNodeId ?: return
        val current = controller
        val metadata = current?.metadata
        val state = JSONObject()
            .put("connected", current != null)
            .put("title", metadata?.getString(MediaMetadataCompat.METADATA_KEY_TITLE) ?: "")
            .put("artist", metadata?.getString(MediaMetadataCompat.METADATA_KEY_ARTIST) ?: "")
            .put("playing", current?.playbackState?.state == PlaybackStateCompat.STATE_PLAYING)
            .put("volume", volumePercent())
        Wearable.getMessageClient(this)
            .sendMessage(node, STATE_PATH, state.toString().toByteArray())
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

    companion object {
        const val CONTROL_PATH = "/resonance/control"
        const val STATE_PATH = "/resonance/state"
    }
}
