package app.resonance.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONObject

private const val CAPABILITY = "resonance_phone_player"
private const val CONTROL_PATH = "/resonance/control"
private const val STATE_PATH = "/resonance/state"

data class RemoteState(
    val connected: Boolean = false,
    val title: String = "",
    val artist: String = "",
    val playing: Boolean = false,
    val volume: Int = 0,
)

class RemoteActivity : ComponentActivity() {
    private var state by mutableStateOf(RemoteState())

    private val listener = MessageClient.OnMessageReceivedListener { event ->
        if (event.path != STATE_PATH) return@OnMessageReceivedListener
        val json = runCatching { JSONObject(String(event.data, Charsets.UTF_8)) }.getOrNull()
            ?: return@OnMessageReceivedListener
        state = RemoteState(
            connected = json.optBoolean("connected"),
            title = json.optString("title"),
            artist = json.optString("artist"),
            playing = json.optBoolean("playing"),
            volume = json.optInt("volume"),
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val scope = rememberCoroutineScope()
            LaunchedEffect(Unit) { send("state") }
            RemoteScreen(state) { command -> scope.launch { send(command) } }
        }
    }

    override fun onResume() {
        super.onResume()
        Wearable.getMessageClient(this).addListener(listener)
    }

    override fun onPause() {
        Wearable.getMessageClient(this).removeListener(listener)
        super.onPause()
    }

    private suspend fun send(command: String) {
        val nodes = runCatching {
            Wearable.getCapabilityClient(this)
                .getCapability(CAPABILITY, CapabilityClient.FILTER_REACHABLE)
                .await()
                .nodes
        }.getOrDefault(emptySet())
        if (nodes.isEmpty()) {
            state = RemoteState(connected = false)
            return
        }
        val target = nodes.firstOrNull { it.isNearby } ?: nodes.first()
        runCatching {
            Wearable.getMessageClient(this)
                .sendMessage(target.id, CONTROL_PATH, command.toByteArray(Charsets.UTF_8))
                .await()
        }
    }
}

@Composable
private fun RemoteScreen(state: RemoteState, onCommand: (String) -> Unit) {
    MaterialTheme {
        Column(
            modifier = Modifier.fillMaxSize().padding(12.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = if (state.connected) state.title.ifEmpty { "Ничего не играет" }
                else "Нет связи с телефоном",
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
                style = MaterialTheme.typography.title3,
            )
            Text(
                text = state.artist,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                style = MaterialTheme.typography.caption2,
            )
            Row(
                modifier = Modifier.padding(vertical = 6.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SmallButton("⏮", "Предыдущий") { onCommand("previous") }
                Button(
                    onClick = { onCommand("toggle") },
                    modifier = Modifier,
                ) {
                    if (state.playing) Text("❚❚")
                    else Icon(Icons.Filled.PlayArrow, contentDescription = "Играть")
                }
                SmallButton("⏭", "Следующий") { onCommand("next") }
            }
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SmallButton("−", "Тише") { onCommand("volume_down") }
                Text("${state.volume}%", style = MaterialTheme.typography.caption1)
                Button(
                    onClick = { onCommand("volume_up") },
                    modifier = Modifier,
                    colors = ButtonDefaults.secondaryButtonColors(),
                ) { Icon(Icons.Filled.Add, contentDescription = "Громче") }
            }
        }
    }
}

@Composable
private fun SmallButton(label: String, description: String, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        modifier = Modifier.semantics { contentDescription = description },
        colors = ButtonDefaults.secondaryButtonColors(),
    ) {
        Text(label, modifier = Modifier.padding(2.dp))
    }
}
