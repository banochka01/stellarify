package app.resonance.resonance

import android.content.ComponentName
import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.os.Process
import android.support.v4.media.MediaBrowserCompat
import androidx.media.MediaBrowserServiceCompat

/**
 * Public MediaBrowserService (Android Auto, system media controls).
 *
 * audio_service's own `AudioService` is not exported any more: it would
 * hand the user's library to any app that binds it. This relay validates
 * the caller and forwards browsing to `AudioService` inside the app; the
 * media session token is the real one, so playback controls are unchanged.
 */
class ResonanceBrowserService : MediaBrowserServiceCompat() {
    private var inner: MediaBrowserCompat? = null
    private val pending = mutableListOf<() -> Unit>()

    override fun onCreate() {
        super.onCreate()
        val browser = MediaBrowserCompat(
            this,
            ComponentName(this, AUDIO_SERVICE_CLASS),
            object : MediaBrowserCompat.ConnectionCallback() {
                override fun onConnected() {
                    val connected = inner ?: return
                    if (sessionToken == null) setSessionToken(connected.sessionToken)
                    val queued = pending.toList()
                    pending.clear()
                    queued.forEach { it() }
                }
            },
            null,
        )
        inner = browser
        browser.connect()
    }

    override fun onDestroy() {
        inner?.disconnect()
        inner = null
        super.onDestroy()
    }

    override fun onGetRoot(clientPackageName: String, clientUid: Int, rootHints: Bundle?): BrowserRoot {
        if (!CallerValidator.isAllowed(this, clientPackageName, clientUid)) {
            return BrowserRoot(EMPTY_ROOT_ID, null)
        }
        val recent = rootHints?.getBoolean(BrowserRoot.EXTRA_RECENT) == true
        return BrowserRoot(if (recent) "recent" else "root", null)
    }

    override fun onLoadChildren(
        parentId: String,
        result: Result<MutableList<MediaBrowserCompat.MediaItem>>,
    ) {
        val caller = currentBrowserInfo
        if (parentId == EMPTY_ROOT_ID ||
            !CallerValidator.isAllowed(this, caller.packageName, caller.uid)
        ) {
            result.sendResult(mutableListOf())
            return
        }
        result.detach()
        val load = load@{
            val browser = inner
            if (browser == null || !browser.isConnected) {
                result.sendResult(mutableListOf())
                return@load
            }
            browser.subscribe(
                parentId,
                object : MediaBrowserCompat.SubscriptionCallback() {
                    override fun onChildrenLoaded(
                        id: String,
                        children: MutableList<MediaBrowserCompat.MediaItem>,
                    ) {
                        browser.unsubscribe(id, this)
                        result.sendResult(children)
                    }

                    override fun onError(id: String) {
                        browser.unsubscribe(id, this)
                        result.sendResult(mutableListOf())
                    }
                },
            )
        }
        if (inner?.isConnected == true) load() else pending.add(load)
    }

    companion object {
        private const val EMPTY_ROOT_ID = "resonance:empty"
        const val AUDIO_SERVICE_CLASS = "com.ryanheise.audioservice.AudioService"
    }
}

/** PackageValidator-like allow list for media browsing. */
object CallerValidator {
    private val trustedPackages = setOf(
        "com.google.android.projection.gearhead", // Android Auto
        "com.android.systemui", // system media controls / resumption
    )

    fun isAllowed(context: Context, packageName: String, uid: Int): Boolean {
        if (uid == Process.myUid() || uid == Process.SYSTEM_UID) return true
        if (packageName !in trustedPackages) return false
        val pm = context.packageManager
        // The package name must really belong to the calling uid.
        if (pm.getPackagesForUid(uid)?.contains(packageName) != true) return false
        if (packageName == "com.android.systemui") {
            val info = runCatching { pm.getApplicationInfo(packageName, 0) }.getOrNull()
            return info != null && info.flags and ApplicationInfo.FLAG_SYSTEM != 0
        }
        return true
    }
}
