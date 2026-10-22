package es.david.caudal.ui.onboarding

import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import es.david.caudal.R
import es.david.caudal.core.Money
import es.david.caudal.data.repo.FinanceRepository
import es.david.caudal.data.repo.SettingsRepository
import es.david.caudal.domain.model.Account
import es.david.caudal.domain.model.AccountType
import es.david.caudal.ui.common.Confetti
import es.david.caudal.ui.common.GlowBackground
import es.david.caudal.ui.common.Gotita
import es.david.caudal.ui.common.Mood
import es.david.caudal.ui.common.Pill
import es.david.caudal.ui.common.contentOn
import es.david.caudal.ui.common.pressable
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.theme.ACCENTS
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.hexColor
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

/** monedas que se pueden elegir (código ISO) */
val CURRENCIES = listOf("EUR", "USD", "GBP", "MXN", "ARS", "COP", "CLP", "CHF")

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val repo: FinanceRepository,
    private val settings: SettingsRepository,
    @ApplicationContext private val context: Context,
) : ViewModel() {
    /** nombre traducido de las categorías de partida (cat_<id> en strings.xml) */
    fun categoryName(id: String): String? {
        val res = context.resources.getIdentifier("cat_$id", "string", context.packageName)
        return if (res != 0) context.getString(res) else null
    }

    /** el color se ve al momento en toda la bienvenida */
    fun setAccent(hex: String) = viewModelScope.launch { settings.update { it.copy(accent = hex) } }

    suspend fun finish(name: String, currency: String, accountName: String, balance: Long) {
        repo.setUp(::categoryName, Account(name = accountName, type = AccountType.CORRIENTE, currency = currency, initial = balance, icon = AccountType.CORRIENTE.icon))
        settings.update { it.copy(name = name.trim(), currency = currency, onboarded = true) }
    }

    /** restaura la copia del iPhone (o de esta app); devuelve false si el archivo no vale */
    suspend fun import(uri: Uri): Boolean = runCatching {
        val text = withContext(Dispatchers.IO) { context.contentResolver.openInputStream(uri)!!.use { it.readBytes().decodeToString() } }
        repo.importBackup(text)
        true
    }.getOrDefault(false)
}

/**
 * Bienvenida en 4 pasos con Gotita: hola, cómo te llamas, tu color y tu primera cuenta.
 * O, en el primer paso, restaurar una copia de Caudal.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun OnboardingScreen() {
    val vm: OnboardingViewModel = hiltViewModel()
    val h = rememberHaptics()
    val c = CaudalTheme.colors
    val scope = rememberCoroutineScope()
    var step by rememberSaveable { mutableIntStateOf(0) }
    var busy by rememberSaveable { mutableStateOf(false) }
    var error by rememberSaveable { mutableStateOf(false) }
    var name by rememberSaveable { mutableStateOf("") }
    var currency by rememberSaveable { mutableStateOf("EUR") }
    var accent by rememberSaveable { mutableStateOf(ACCENTS.first().hex) }
    val defaultAccount = stringResource(R.string.welcome_account_default)
    var account by rememberSaveable { mutableStateOf(defaultAccount) }
    var balance by rememberSaveable { mutableStateOf("") }
    var party by rememberSaveable { mutableStateOf<Int?>(null) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) scope.launch {
            busy = true
            val ok = vm.import(uri)
            busy = false
            error = !ok
            if (ok) h.success() else h.warning()
        }
    }
    fun next() { h.tap(); step++ }

    Box(Modifier.fillMaxSize()) {
        GlowBackground(c.accent, Modifier.fillMaxWidth().height(460.dp))
        Column(Modifier.fillMaxSize().safeDrawingPadding().imePadding()) {
            // puntitos de progreso
            Row(Modifier.fillMaxWidth().padding(top = 18.dp), horizontalArrangement = Arrangement.Center) {
                repeat(4) { i ->
                    val w by animateFloatAsState(if (i == step) 26f else 8f, spring(dampingRatio = 0.6f), label = "punto")
                    Box(Modifier.padding(3.dp).height(8.dp).width(w.dp).clip(CircleShape).background(if (i <= step) c.accent else c.cardAlt))
                }
            }
            AnimatedContent(
                step,
                transitionSpec = {
                    val dir = if (targetState > initialState) 1 else -1
                    (slideInHorizontally { it / 3 * dir } + fadeIn()).togetherWith(slideOutHorizontally { -it / 3 * dir } + fadeOut())
                },
                label = "bienvenida",
                modifier = Modifier.weight(1f),
            ) { s ->
                Column(
                    Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    val mood = when (s) { 0 -> Mood.HAPPY; 1 -> Mood.WINK; 2 -> Mood.LOVE; else -> Mood.WOW }
                    Gotita(mood, if (s == 0) 150.dp else 110.dp, description = stringResource(R.string.gotita))
                    when (s) {
                        0 -> {
                            Title(stringResource(R.string.welcome_hello))
                            Text(stringResource(R.string.welcome_text), style = MaterialTheme.typography.bodyLarge, color = c.textDim, textAlign = TextAlign.Center)
                            Spacer(Modifier.height(8.dp))
                            BigButton(stringResource(R.string.welcome_start)) { next() }
                            SoftButton(stringResource(R.string.welcome_import), busy) { picker.launch(arrayOf("application/json", "text/plain", "application/octet-stream")) }
                            if (error) Text(stringResource(R.string.import_failed), color = c.negative, textAlign = TextAlign.Center)
                        }
                        1 -> {
                            Title(stringResource(R.string.welcome_name))
                            Field(name, { name = it }, stringResource(R.string.name), KeyboardOptions(capitalization = KeyboardCapitalization.Words))
                            BigButton(stringResource(R.string.welcome_next)) { next() }
                        }
                        2 -> {
                            Title(stringResource(R.string.welcome_color))
                            FlowRow(horizontalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterHorizontally), verticalArrangement = Arrangement.spacedBy(14.dp), maxItemsInEachRow = 4) {
                                ACCENTS.forEach { a ->
                                    val on = a.hex == accent
                                    val label = stringResource(a.name)
                                    val sc by animateFloatAsState(if (on) 1.12f else 1f, spring(dampingRatio = 0.45f, stiffness = Spring.StiffnessMedium), label = "color")
                                    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.width(64.dp)) {
                                        Box(
                                            Modifier.size(56.dp).graphicsLayer { scaleX = sc; scaleY = sc }.clip(CircleShape).background(hexColor(a.hex))
                                                .border(if (on) 3.dp else 0.dp, if (on) c.text else Color.Transparent, CircleShape)
                                                .pressable(0.85f, role = Role.RadioButton) { h.select(); accent = a.hex; vm.setAccent(a.hex) }
                                                .semantics { contentDescription = label; selected = on },
                                            contentAlignment = Alignment.Center,
                                        ) { if (on) Icon(Icons.Filled.Check, null, tint = contentOn(hexColor(a.hex))) }
                                        Spacer(Modifier.height(4.dp))
                                        Text(label, style = MaterialTheme.typography.labelSmall, color = c.textDim)
                                    }
                                }
                            }
                            BigButton(stringResource(R.string.welcome_next)) { next() }
                        }
                        else -> {
                            Title(stringResource(R.string.welcome_first_account))
                            Field(account, { account = it }, stringResource(R.string.welcome_account_name))
                            Field(balance, { balance = Money.cleanInput(it) }, stringResource(R.string.welcome_balance), KeyboardOptions(keyboardType = KeyboardType.Decimal))
                            Column(Modifier.fillMaxWidth()) {
                                Text(stringResource(R.string.welcome_currency), style = MaterialTheme.typography.labelLarge, color = c.textDim)
                                Spacer(Modifier.height(8.dp))
                                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                    CURRENCIES.forEach { cur -> Pill(cur, cur == currency, { currency = cur }) }
                                }
                            }
                            BigButton(stringResource(R.string.welcome_done)) {
                                h.success()
                                party = (party ?: 0) + 1
                                scope.launch { delay(900); vm.finish(name, currency, account.ifBlank { defaultAccount }, Money.toCents(Money.parse(balance) ?: 0.0)) }
                            }
                        }
                    }
                    if (s > 0) Text(
                        stringResource(R.string.back), style = MaterialTheme.typography.labelLarge, color = c.textDim,
                        modifier = Modifier.clip(CircleShape).pressable { step-- }.padding(horizontal = 16.dp, vertical = 10.dp),
                    )
                }
            }
        }
        Confetti(party, listOf(c.accent, c.income, c.warning, Color(0xFF8FC8FF), Color(0xFFB9A4FF)))
    }
}

@Composable
private fun Title(text: String) {
    Text(text, style = MaterialTheme.typography.headlineLarge, textAlign = TextAlign.Center, modifier = Modifier.semantics { heading() })
}

@Composable
private fun Field(value: String, onChange: (String) -> Unit, label: String, keyboard: KeyboardOptions = KeyboardOptions.Default) {
    val c = CaudalTheme.colors
    OutlinedTextField(
        value, onChange, label = { Text(label) }, singleLine = true, keyboardOptions = keyboard,
        shape = RoundedCornerShape(20.dp),
        colors = OutlinedTextFieldDefaults.colors(focusedContainerColor = c.card, unfocusedContainerColor = c.card, unfocusedBorderColor = c.hairline, focusedBorderColor = c.accent),
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun BigButton(text: String, onClick: () -> Unit) {
    val c = CaudalTheme.colors
    Box(
        Modifier.fillMaxWidth().heightIn(min = 58.dp).clip(CircleShape).pressable(0.95f, onClick = onClick).background(c.accent),
        contentAlignment = Alignment.Center,
    ) { Text(text, style = MaterialTheme.typography.titleMedium, color = contentOn(c.accent)) }
}

@Composable
private fun SoftButton(text: String, busy: Boolean, onClick: () -> Unit) {
    val c = CaudalTheme.colors
    Box(
        Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(CircleShape).pressable(0.95f, enabled = !busy, onClick = onClick).background(c.card).border(1.dp, c.hairline, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        if (busy) CircularProgressIndicator(Modifier.size(22.dp), color = c.accent, strokeWidth = 2.dp)
        else Text(text, style = MaterialTheme.typography.labelLarge)
    }
}
