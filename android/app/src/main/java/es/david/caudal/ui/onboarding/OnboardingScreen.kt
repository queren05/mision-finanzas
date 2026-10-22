package es.david.caudal.ui.onboarding

import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import es.david.caudal.R
import es.david.caudal.core.Money
import es.david.caudal.data.repo.FinanceRepository
import es.david.caudal.data.repo.SettingsRepository
import es.david.caudal.domain.model.Account
import es.david.caudal.domain.model.AccountType
import es.david.caudal.ui.common.Pill
import es.david.caudal.ui.common.rememberHaptics
import kotlinx.coroutines.Dispatchers
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

/** Bienvenida: la app arranca vacía; o se crea la primera cuenta o se restaura una copia */
@Composable
fun OnboardingScreen() {
    val vm: OnboardingViewModel = hiltViewModel()
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    var step by rememberSaveable { mutableStateOf(0) }
    var busy by rememberSaveable { mutableStateOf(false) }
    var error by rememberSaveable { mutableStateOf(false) }
    var name by rememberSaveable { mutableStateOf("") }
    var currency by rememberSaveable { mutableStateOf("EUR") }
    val defaultAccount = stringResource(R.string.welcome_account_default)
    var account by rememberSaveable { mutableStateOf(defaultAccount) }
    var balance by rememberSaveable { mutableStateOf("") }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) scope.launch {
            busy = true
            val ok = vm.import(uri)
            busy = false
            error = !ok
            if (ok) h.success() else h.warning()
        }
    }

    AnimatedContent(step, label = "bienvenida", modifier = Modifier.fillMaxSize().safeDrawingPadding()) { s ->
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).imePadding().padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (s == 0) {
                Text("💧", fontSize = 72.sp)
                Text(stringResource(R.string.welcome_title), style = MaterialTheme.typography.headlineMedium, textAlign = TextAlign.Center, modifier = Modifier.semantics { heading() })
                Text(stringResource(R.string.welcome_text), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
                Spacer(Modifier.height(16.dp))
                Button(onClick = { h.tap(); step = 1 }, modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp)) { Text(stringResource(R.string.welcome_start), fontWeight = FontWeight.Bold) }
                OutlinedButton(onClick = { picker.launch(arrayOf("application/json", "text/plain", "application/octet-stream")) }, enabled = !busy, modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp)) {
                    if (busy) CircularProgressIndicator(Modifier.height(20.dp)) else Text(stringResource(R.string.welcome_import))
                }
                if (error) Text(stringResource(R.string.import_failed), color = MaterialTheme.colorScheme.error, textAlign = TextAlign.Center)
            } else {
                OutlinedTextField(
                    name, { name = it }, label = { Text(stringResource(R.string.welcome_name)) }, singleLine = true,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words), modifier = Modifier.fillMaxWidth(),
                )
                Column(Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.welcome_currency), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(8.dp))
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        items(CURRENCIES) { c -> Pill(c, c == currency, { currency = c }) }
                    }
                }
                Text(stringResource(R.string.welcome_first_account), style = MaterialTheme.typography.titleMedium, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(account, { account = it }, label = { Text(stringResource(R.string.welcome_account_name)) }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(
                    balance, { balance = Money.cleanInput(it) }, label = { Text(stringResource(R.string.welcome_balance)) }, singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.fillMaxWidth(),
                )
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    OutlinedButton(onClick = { step = 0 }, modifier = Modifier.weight(1f).heightIn(min = 52.dp)) { Text(stringResource(R.string.back)) }
                    Button(
                        onClick = {
                            h.success()
                            scope.launch { vm.finish(name, currency, account.ifBlank { defaultAccount }, Money.toCents(Money.parse(balance) ?: 0.0)) }
                        },
                        modifier = Modifier.weight(1f).heightIn(min = 52.dp),
                    ) { Text(stringResource(R.string.welcome_done), fontWeight = FontWeight.Bold) }
                }
            }
        }
    }
}
