package es.david.caudal.ui.debts

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Rect
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Photo
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.domain.model.PALETTE
import es.david.caudal.domain.model.Person
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.breathe
import es.david.caudal.ui.common.pressable
import es.david.caudal.ui.theme.CaudalTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import es.david.caudal.ui.common.ColorRow
import es.david.caudal.ui.common.ConfirmDialog
import es.david.caudal.ui.common.EditorScaffold
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.theme.hexColor
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream

/** emojis para las personas (los mismos grupos que en iPhone) */
private val personEmojis = listOf(
    R.string.person_emoji_faces to listOf("😎", "🤠", "🥸", "🤓", "😏", "🥳", "😴", "🤑", "😇", "🤪", "😈", "👻", "💀", "🤡", "👽", "🤖", "🙃", "😬", "🫠", "🥹", "😤", "🤯", "🧐", "😵‍💫"),
    R.string.person_emoji_people to listOf("🧔", "👨", "👩", "🧑", "👱", "👨‍🦱", "👩‍🦰", "🧑‍🎤", "👸", "🤴", "🧙", "🧛", "🥷", "💃", "🕺", "🧑‍🍳", "🧑‍🚀", "🦸", "🦹", "🧜", "👮", "🧑‍🎓", "🧑‍💻", "🧑‍🎨"),
    R.string.person_emoji_animals to listOf("🐻", "🦊", "🐸", "🐱", "🐶", "🦁", "🐼", "🐵", "🐙", "🦄", "🐯", "🐨", "🐷", "🐔", "🐧", "🦉", "🐢", "🦖", "🐬", "🦈", "🐝", "🦋", "🐘", "🦒"),
    R.string.person_emoji_food to listOf("🍕", "🍔", "🌮", "🍣", "🍜", "🍩", "🍰", "🍦", "🍺", "🍷", "🍹", "☕", "🧋", "🍓", "🍉", "🥑", "🌶️", "🍟", "🥐", "🍪", "🧀", "🥓", "🍿", "🥨"),
    R.string.person_emoji_hobbies to listOf("⚽", "🏀", "🎾", "🏐", "🥊", "🏋️", "🚴", "🏄", "⛷️", "🎮", "🎧", "🎸", "🎤", "🎨", "📸", "🎬", "📚", "✈️", "🚗", "🏍️", "🛹", "🎲", "♟️", "🎯"),
    R.string.person_emoji_symbols to listOf("⭐", "🔥", "💎", "🌈", "⚡", "🌙", "☀️", "🍀", "💖", "💜", "🖤", "👑", "💯", "🚀", "🎉", "🧿", "🪩", "🌸", "🌵", "🐾", "💸", "💰", "🎁", "🏆"),
)

/** recorta al centro y reduce la foto a un cuadrado de 512 px en JPEG */
private fun shrinkPhoto(ctx: Context, uri: Uri): ByteArray? = runCatching {
    val src = ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) } ?: return null
    val side = minOf(src.width, src.height)
    val target = minOf(512, side)
    val out = Bitmap.createBitmap(target, target, Bitmap.Config.ARGB_8888)
    Canvas(out).drawBitmap(src, Rect((src.width - side) / 2, (src.height - side) / 2, (src.width + side) / 2, (src.height + side) / 2), Rect(0, 0, target, target), null)
    ByteArrayOutputStream().use { s -> out.compress(Bitmap.CompressFormat.JPEG, 82, s); s.toByteArray() }
}.getOrNull()

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PersonEditorScreen(id: String?, nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val ctx = LocalContext.current
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val data = ledger?.data

    var p by remember { mutableStateOf<Person?>(null) }
    var newPhoto by remember { mutableStateOf<ByteArray?>(null) }
    var newPhotoImg by remember { mutableStateOf<ImageBitmap?>(null) }
    var removePhoto by rememberSaveable { mutableStateOf(false) }
    var askDelete by remember { mutableStateOf(false) }
    val original = data?.people?.firstOrNull { it.id == id }

    LaunchedEffect(data != null) {
        if (data != null && p == null) {
            p = original ?: Person(name = "", color = PALETTE[data.people.size % PALETTE.size], emoji = personEmojis[0].second.random())
        }
    }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) scope.launch {
            val bytes = withContext(Dispatchers.IO) { shrinkPhoto(ctx, uri) } ?: return@launch
            newPhoto = bytes
            newPhotoImg = withContext(Dispatchers.Default) { BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.asImageBitmap() }
            removePhoto = false
        }
    }
    val person = p ?: return
    val hasPhoto = newPhoto != null || (person.photo != null && !removePhoto)

    fun save() {
        val n = person.copy(name = person.name.trim())
        vm.run { save(n, photo = newPhoto, removePhoto = removePhoto && newPhoto == null) }
        h.success()
        // devuelve la persona nueva a quien abrió el editor (por ejemplo, el de apuntar una deuda)
        if (original == null) nav.previousBackStackEntry?.savedStateHandle?.set(NEW_PERSON_KEY, n.id)
        nav.popBackStack()
    }

    EditorScaffold(
        title = stringResource(if (original == null) R.string.person_new else R.string.person_edit),
        onCancel = { nav.popBackStack() },
        onSave = ::save,
        saveEnabled = person.name.isNotBlank(),
    ) { pad ->
        Column(Modifier.padding(pad).imePadding().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                val shown = if (removePhoto && newPhoto == null) person.copy(photo = null) else person
                Box(Modifier.breathe(0.03f)) { Avatar(shown, vm.repo, 112.dp, photoOverride = newPhotoImg) }
                if (person.name.isNotBlank()) Text(person.name, style = MaterialTheme.typography.headlineSmall)
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    PillButton(stringResource(if (hasPhoto) R.string.person_photo_change else R.string.person_photo_set), Icons.Filled.Photo, CaudalTheme.colors.accent, filled = false) {
                        picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    }
                    if (hasPhoto) PillButton(stringResource(R.string.person_photo_remove), null, CaudalTheme.colors.negative, filled = false) { newPhoto = null; newPhotoImg = null; removePhoto = true }
                }
            }
            Card(padding = 14.dp) {
                OutlinedTextField(person.name, { p = person.copy(name = it) }, label = { Text(stringResource(R.string.person_name)) }, singleLine = true, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth())
                Spacer(Modifier.size(8.dp))
                OutlinedTextField(person.nick, { p = person.copy(nick = it) }, label = { Text(stringResource(R.string.person_nick)) }, singleLine = true, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth())
                Spacer(Modifier.size(8.dp))
                OutlinedTextField(person.phone, { p = person.copy(phone = it) }, label = { Text(stringResource(R.string.person_phone)) }, singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone), shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth())
            }
            Card(padding = 14.dp) {
                Text(stringResource(R.string.color), style = MaterialTheme.typography.titleSmall, color = CaudalTheme.colors.textDim)
                Spacer(Modifier.size(10.dp))
                ColorRow(person.color) { p = person.copy(color = it) }
            }
            personEmojis.forEach { (label, list) ->
                Card(padding = 14.dp) {
                    Text(stringResource(label), style = MaterialTheme.typography.titleSmall, color = CaudalTheme.colors.textDim)
                    Spacer(Modifier.size(8.dp))
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        list.forEach { e ->
                            val on = person.emoji == e && !hasPhoto
                            Box(
                                Modifier.size(46.dp).clip(RoundedCornerShape(15.dp))
                                    .background(if (on) hexColor(person.color).copy(alpha = 0.4f) else androidx.compose.ui.graphics.Color.Transparent)
                                    .pressable(0.8f, role = Role.RadioButton) {
                                        h.select()
                                        p = person.copy(emoji = e)
                                        // como en iPhone: elegir emoji quita la foto
                                        newPhoto = null; newPhotoImg = null; if (person.photo != null) removePhoto = true
                                    }
                                    .semantics { selected = on },
                                contentAlignment = Alignment.Center,
                            ) { Text(e, fontSize = 22.sp) }
                        }
                    }
                }
            }
            if (original != null) {
                PillButton(stringResource(R.string.person_delete), null, CaudalTheme.colors.negative, Modifier.fillMaxWidth(), filled = false) { askDelete = true }
            }
        }
    }
    if (askDelete && original != null) {
        ConfirmDialog(
            title = stringResource(R.string.person_confirm_delete, original.name),
            message = stringResource(R.string.person_confirm_delete_msg),
            confirm = stringResource(R.string.person_delete),
            onConfirm = {
                h.heavy(); vm.run { deletePerson(original) }
                // fuera también del detalle, que ya no existe
                nav.popBackStack()
                if (nav.currentBackStackEntry?.destination?.route?.contains("PersonDetailRoute") == true) nav.popBackStack()
            },
            onDismiss = { askDelete = false },
        )
    }
}
