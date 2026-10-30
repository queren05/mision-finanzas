package es.david.findemes.ui

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.Whatshot
import androidx.compose.material.icons.outlined.ConfirmationNumber as TicketOutline
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/** Los iconos del iPhone (SF Symbols) solo pueden usarse en aparatos de Apple: aquí van sus equivalentes de Material. */
object Sym {
    /** corona de cinco picos */
    val crown: ImageVector by lazy {
        ImageVector.Builder("crown", 24.dp, 24.dp, 24f, 24f).path(fill = SolidColor(Color.Black)) {
            moveTo(3f, 7f); lineTo(7.5f, 11f); lineTo(12f, 4f); lineTo(16.5f, 11f); lineTo(21f, 7f)
            lineTo(19.5f, 18f); lineTo(4.5f, 18f); close()
            moveTo(4.5f, 19.5f); lineTo(19.5f, 19.5f); lineTo(19.5f, 21f); lineTo(4.5f, 21f); close()
        }.build()
    }
    /** estrella de golpe (picos irregulares) */
    val burst: ImageVector by lazy {
        ImageVector.Builder("burst", 24.dp, 24.dp, 24f, 24f).path(fill = SolidColor(Color.Black)) {
            val n = 12
            for (i in 0 until n * 2) {
                val a = i * PI / n - PI / 2
                val r = if (i % 2 == 0) 11.0 else 6.2
                val x = (12 + cos(a) * r).toFloat(); val y = (12 + sin(a) * r).toFloat()
                if (i == 0) moveTo(x, y) else lineTo(x, y)
            }
            close()
        }.build()
    }

    fun of(name: String): ImageVector = when (name) {
        "1.circle.fill" -> Icons.Filled.LooksOne
        "arrow.up.left.and.arrow.down.right" -> Icons.Filled.OpenInFull
        "bolt.fill" -> Icons.Filled.Bolt
        "burst.fill" -> burst
        "circle.circle.fill" -> Icons.Filled.RadioButtonChecked
        "circle.fill" -> Icons.Filled.Circle
        "crown.fill" -> crown
        "cup.and.saucer.fill" -> Icons.Filled.Coffee
        "dollarsign.circle.fill" -> Icons.Filled.MonetizationOn
        "dot.radiowaves.left.and.right" -> Icons.Filled.Sensors
        "drop.fill" -> Icons.Filled.WaterDrop
        "envelope.fill" -> Icons.Filled.Mail
        "envelope.open.fill" -> Icons.Filled.Drafts
        "eye.fill" -> Icons.Filled.Visibility
        "flame" -> Icons.Outlined.Whatshot
        "flame.fill" -> Icons.Filled.LocalFireDepartment
        "flame.circle.fill" -> Icons.Filled.Whatshot
        "hammer.fill" -> Icons.Filled.Hardware
        "hand.raised.fill" -> Icons.Filled.BackHand
        "hourglass" -> Icons.Filled.HourglassBottom
        "house.fill" -> Icons.Filled.Home
        "leaf.fill" -> Icons.Filled.Eco
        "list.clipboard.fill" -> Icons.Filled.Assignment
        "lungs.fill" -> Icons.Filled.SelfImprovement
        "party.popper.fill" -> Icons.Filled.Celebration
        "photo.fill" -> Icons.Filled.Photo
        "plus.circle.fill" -> Icons.Filled.AddCircle
        "rectangle.expand.vertical" -> Icons.Filled.Height
        "rosette" -> Icons.Filled.MilitaryTech
        "scope" -> Icons.Filled.GpsFixed
        "seal.fill" -> Icons.Filled.Verified
        "shield.slash.fill" -> Icons.Filled.RemoveModerator
        "shippingbox.fill" -> Icons.Filled.Inventory2
        "sofa.fill" -> Icons.Filled.Weekend
        "sparkles" -> Icons.Filled.AutoAwesome
        "timer" -> Icons.Filled.Timer
        "wind" -> Icons.Filled.Air
        "bed.double.fill" -> Icons.Filled.KingBed
        "book.closed.fill" -> Icons.Filled.Book
        "doc.text.fill" -> Icons.Filled.Description
        "hare.fill" -> Icons.Filled.CrueltyFree
        "heart.fill" -> Icons.Filled.Favorite
        "pin.fill" -> Icons.Filled.PushPin
        "square.grid.3x3.fill" -> Icons.Filled.Apps
        "star.circle.fill" -> Icons.Filled.Stars
        "star.fill" -> Icons.Filled.Star
        "sun.max.fill" -> Icons.Filled.WbSunny
        "ticket.fill" -> Icons.Filled.ConfirmationNumber
        "xmark" -> Icons.Filled.Close
        "questionmark" -> Icons.Filled.QuestionMark
        "lock.fill" -> Icons.Filled.Lock
        "moon.zzz.fill" -> Icons.Filled.Bedtime
        "magnifyingglass" -> Icons.Filled.Search
        "gearshape.fill" -> Icons.Filled.Settings
        "checkmark" -> Icons.Filled.Check
        "arrow.right" -> Icons.Filled.ArrowForward
        "eurosign.circle.fill" -> Icons.Filled.Euro
        "gift.fill" -> Icons.Filled.Redeem
        "ticket" -> Icons.Outlined.TicketOutline
        "play.rectangle.fill" -> Icons.Filled.SmartDisplay
        "cart.fill" -> Icons.Filled.ShoppingCart
        "arrow.clockwise" -> Icons.Filled.Refresh
        "hand.raised.slash.fill" -> Icons.Filled.Block
        "lock.shield.fill" -> Icons.Filled.PrivacyTip
        else -> Icons.Filled.AutoAwesome
    }
}
