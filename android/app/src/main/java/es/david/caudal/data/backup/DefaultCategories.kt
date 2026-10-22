package es.david.caudal.data.backup

import es.david.caudal.domain.model.CatKind
import es.david.caudal.domain.model.Category
import es.david.caudal.domain.model.PALETTE

/**
 * Categorías de partida (las mismas que en iPhone, con los mismos ids).
 * Los nombres se pasan desde strings.xml para poder traducirlos; aquí van en español por si no.
 */
object DefaultCategories {
    data class Def(val id: String, val kind: CatKind, val name: String, val icon: String, val keywords: String, val budget: Long = 0)

    val defs = listOf(
        Def("c_super", CatKind.EXPENSE, "Supermercado", "🛒", "mercadona, lidl, carrefour, dia, alcampo, aldi, eroski, ahorramas, hipercor, consum, alimentacion, mini super"),
        Def("c_rest", CatKind.EXPENSE, "Restaurantes", "🍽️", "restaurante, taberna, bar, sushi, glovo, just eat, uber eats, burger king, mcdonald, telepizza, kfc"),
        Def("c_snack", CatKind.EXPENSE, "Cafés y snacks", "☕", "vending, starbucks, cafeteria"),
        Def("c_transp", CatKind.EXPENSE, "Transporte", "🚇", "metro, renfe, emt, crtm, cabify, uber, bolt, blablacar, alsa"),
        Def("c_coche", CatKind.EXPENSE, "Coche y gasolina", "⛽", "easypark, e. s, e.s, estacion de servicio, repsol, cepsa, moeve, galp, shell, gasolinera, parking, itv, peaje"),
        Def("c_casa", CatKind.EXPENSE, "Vivienda", "🏠", "alquiler, hipoteca, comunidad, ibi"),
        Def("c_fact", CatKind.EXPENSE, "Facturas", "💡", "iberdrola, endesa, naturgy, movistar, vodafone, orange, digi, pepephone"),
        Def("c_subs", CatKind.EXPENSE, "Suscripciones", "📺", "netflix, spotify, hbo, disney, amazon prime, youtube premium, icloud, chatgpt"),
        Def("c_ocio", CatKind.EXPENSE, "Ocio", "🎮", "steam, playstation, nintendo, cine, groupon, parque, entradas"),
        Def("c_compras", CatKind.EXPENSE, "Compras", "🛍️", "amazon, aliexpress, shein, temu, zara, primark, toys r us, decathlon, mediamarkt, ikea"),
        Def("c_tabaco", CatKind.EXPENSE, "Tabaco", "🚬", "estanco"),
        Def("c_salud", CatKind.EXPENSE, "Salud", "💊", "farmacia, dentista, clinica, optica"),
        Def("c_deporte", CatKind.EXPENSE, "Deporte", "🏋️", "vivagym, gimnasio, basic-fit, altafit"),
        Def("c_amigos", CatKind.EXPENSE, "Amigos y Bizum", "👥", "bizum a"),
        Def("c_pareja", CatKind.EXPENSE, "Pareja", "❤️", ""),
        Def("c_regalos", CatKind.EXPENSE, "Regalos", "🎁", ""),
        Def("c_viajes", CatKind.EXPENSE, "Viajes", "✈️", "booking, airbnb, ryanair, iberia, vueling, hotel"),
        Def("c_formacion", CatKind.EXPENSE, "Formación", "📚", "udemy, coursera, libreria"),
        Def("c_comisiones", CatKind.EXPENSE, "Comisiones", "🏦", "comision, comisión, mantenimiento cuenta"),
        Def("c_otros", CatKind.EXPENSE, "Otros gastos", "📦", ""),
        Def("i_nomina", CatKind.INCOME, "Nómina", "💼", "nomina, nómina, salario"),
        Def("i_bizum", CatKind.INCOME, "Bizum recibido", "📲", "bizum de"),
        Def("i_reemb", CatKind.INCOME, "Reembolsos", "↩️", "refund, reembolso, devolucion"),
        Def("i_familia", CatKind.INCOME, "Familia", "👨‍👩‍👦", ""),
        Def("i_pareja", CatKind.INCOME, "Pareja", "❤️", ""),
        Def("i_int", CatKind.INCOME, "Intereses y dividendos", "📈", "intereses, dividendo"),
        Def("i_ventas", CatKind.INCOME, "Ventas", "🏷️", "wallapop, vinted"),
        Def("i_otros", CatKind.INCOME, "Otros ingresos", "➕", ""),
    )

    /** las categorías de partida; `names` da el nombre traducido por id */
    fun all(names: (String) -> String? = { null }): List<Category> {
        var e = 0
        var i = 0
        return defs.mapIndexed { pos, d ->
            val color = if (d.kind == CatKind.EXPENSE) PALETTE[e++ % PALETTE.size] else PALETTE[(i++ + 2) % PALETTE.size]
            Category(id = d.id, kind = d.kind, name = names(d.id) ?: d.name, icon = d.icon, color = color, budget = d.budget, keywords = d.keywords, position = pos)
        }
    }
}
