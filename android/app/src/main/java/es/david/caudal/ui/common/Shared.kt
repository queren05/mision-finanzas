package es.david.caudal.ui.common

import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionScope
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed

/** para las transiciones compartidas entre pantallas (la tarjeta de una cuenta que crece hasta su detalle) */
@OptIn(ExperimentalSharedTransitionApi::class)
val LocalSharedScope = compositionLocalOf<SharedTransitionScope?> { null }
val LocalNavScope = compositionLocalOf<AnimatedVisibilityScope?> { null }

/** la misma `key` en dos pantallas: el elemento viaja de una a otra al navegar */
@OptIn(ExperimentalSharedTransitionApi::class)
fun Modifier.sharedCard(key: String): Modifier = composed {
    val shared = LocalSharedScope.current
    val nav = LocalNavScope.current
    if (shared == null || nav == null || !es.david.caudal.ui.theme.LocalMotion.current) this
    else with(shared) { this@composed.sharedBounds(rememberSharedContentState(key), nav, resizeMode = SharedTransitionScope.ResizeMode.RemeasureToBounds) }
}
