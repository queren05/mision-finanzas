package es.david.caudal.ui.common

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.ScaffoldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberTopAppBarState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import es.david.caudal.R
import es.david.caudal.ui.theme.CaudalTheme

/**
 * Pantalla con título grande que se encoge al bajar (como en iPhone), botones redondos
 * y un brillo suave del color de la app arriba. `onBack` pone la flecha de volver.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScreenScaffold(
    title: String,
    onBack: (() -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {},
    floating: @Composable () -> Unit = {},
    bottomBar: @Composable () -> Unit = {},
    large: Boolean = true,
    contentWindowInsets: WindowInsets = ScaffoldDefaults.contentWindowInsets,
    content: @Composable (PaddingValues) -> Unit,
) {
    val c = CaudalTheme.colors
    val behavior = if (large) TopAppBarDefaults.exitUntilCollapsedScrollBehavior(rememberTopAppBarState())
    else TopAppBarDefaults.pinnedScrollBehavior(rememberTopAppBarState())
    val colors = TopAppBarDefaults.topAppBarColors(
        containerColor = Color.Transparent,
        scrolledContainerColor = c.bg.copy(alpha = 0.96f),
        titleContentColor = c.text,
        navigationIconContentColor = c.text,
        actionIconContentColor = c.text,
    )
    Box(Modifier.fillMaxSize()) {
        GlowBackground(c.accent, Modifier.fillMaxWidth().height(320.dp))
        Scaffold(
            modifier = Modifier.nestedScroll(behavior.nestedScrollConnection),
            containerColor = Color.Transparent,
            contentWindowInsets = contentWindowInsets,
            topBar = {
                val nav: @Composable () -> Unit = {
                    if (onBack != null) CircleIconButton(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.back), Modifier.padding(start = 4.dp), onClick = onBack)
                }
                if (large) {
                    LargeTopAppBar(
                        title = { Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis, style = if (behavior.state.collapsedFraction > 0.5f) MaterialTheme.typography.titleLarge else MaterialTheme.typography.headlineLarge) },
                        navigationIcon = nav, actions = actions, scrollBehavior = behavior, colors = colors,
                    )
                } else {
                    TopAppBar(
                        title = { Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.titleLarge) },
                        navigationIcon = nav, actions = actions, scrollBehavior = behavior, colors = colors,
                    )
                }
            },
            floatingActionButton = floating,
            bottomBar = bottomBar,
            content = content,
        )
    }
}

/**
 * Editor a pantalla completa: cerrar (X) a la izquierda y Guardar a la derecha, como las hojas de iPhone.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditorScaffold(
    title: String,
    onCancel: () -> Unit,
    onSave: (() -> Unit)?,
    saveEnabled: Boolean = true,
    saveLabel: String = stringResource(R.string.save),
    bottomBar: @Composable () -> Unit = {},
    content: @Composable (PaddingValues) -> Unit,
) {
    val c = CaudalTheme.colors
    Box(Modifier.fillMaxSize()) {
        GlowBackground(c.accent, Modifier.fillMaxWidth().height(260.dp))
        Scaffold(
            containerColor = Color.Transparent,
            topBar = {
                TopAppBar(
                    title = { Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.titleLarge) },
                    navigationIcon = { CircleIconButton(Icons.Filled.Close, stringResource(R.string.cancel), Modifier.padding(start = 4.dp), onClick = onCancel) },
                    actions = {
                        if (onSave != null) {
                            Text(
                                saveLabel,
                                style = MaterialTheme.typography.labelLarge,
                                color = if (saveEnabled) contentOn(c.accent) else c.textDim,
                                modifier = Modifier
                                    .padding(end = 10.dp)
                                    .clip(CircleShape)
                                    .pressable(0.9f, enabled = saveEnabled, onClick = onSave)
                                    .background(if (saveEnabled) c.accent else c.cardAlt, CircleShape)
                                    .padding(horizontal = 18.dp, vertical = 11.dp),
                            )
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                )
            },
            bottomBar = bottomBar,
            content = content,
        )
    }
}

/** contenido de las pantallas con su margen */
@Composable
fun Padded(padding: PaddingValues, content: @Composable () -> Unit) {
    Box(Modifier.fillMaxSize().padding(padding)) { content() }
}

