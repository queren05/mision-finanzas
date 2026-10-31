package es.david.findemes.support

import es.david.findemes.model.SkinDef

/** Los textos hablan del animal que llevas: «+4 vacas a la vez», «+4 cerdos a la vez».
 *  En los textos se escribe {huchas}, {hucha}, {Hucha}, {HUCHAS} y las terminaciones {a}, {as}, {la}, {las}, {una}, {lo}. */
object Animal {
    var singular = "vaca"
    var plural = "vacas"
    var female = true
    private var id = "vaca"

    /** nombre, plural y si es femenino en cada idioma */
    private val names: Map<Lang, Map<String, Triple<String, String, Boolean>>> = mapOf(
        Lang.en to mapOf(
            "vaca" to Triple("cow", "cows", true), "cerdo" to Triple("pig", "pigs", false), "carlino" to Triple("pug", "pugs", false),
            "llama" to Triple("llama", "llamas", true), "caballo" to Triple("horse", "horses", false), "cebra" to Triple("zebra", "zebras", true),
            "oveja" to Triple("sheep", "sheep", true), "perro" to Triple("dog", "dogs", false), "gato" to Triple("cat", "cats", false),
            "zorro" to Triple("fox", "foxes", false), "pollito" to Triple("chick", "chicks", false)),
        Lang.pt to mapOf(
            "vaca" to Triple("vaca", "vacas", true), "cerdo" to Triple("porco", "porcos", false), "carlino" to Triple("pug", "pugs", false),
            "llama" to Triple("lhama", "lhamas", true), "caballo" to Triple("cavalo", "cavalos", false), "cebra" to Triple("zebra", "zebras", true),
            "oveja" to Triple("ovelha", "ovelhas", true), "perro" to Triple("cachorro", "cachorros", false), "gato" to Triple("gato", "gatos", false),
            "zorro" to Triple("raposa", "raposas", true), "pollito" to Triple("pintinho", "pintinhos", false)),
    )

    fun use(s: SkinDef) {
        id = s.id
        val n = names[L10n.lang]?.get(s.id)
        if (n != null) { singular = n.first; plural = n.second; female = n.third }
        else { singular = s.singular; plural = s.plural; female = s.female }
    }
}

/** cambia las marcas por el animal de ahora */
val String.a: String
    get() {
        val t = L10n.tr(this)
        if (!t.contains("{")) return t
        val f = Animal.female
        if (L10n.lang == Lang.en) return t
            .replace("{HUCHAS}", Animal.plural.uppercase())
            .replace("{HUCHA}", Animal.singular.uppercase())
            .replace("{LAS}", "THE").replace("{AS}", "").replace("{A}", "")
            .replace("{Huchas}", Animal.plural.capitalizedFirst)
            .replace("{Hucha}", Animal.singular.capitalizedFirst)
            .replace("{huchas}", Animal.plural).replace("{hucha}", Animal.singular)
            .replace("{as}", "").replace("{a}", "")
            .replace("{las}", "the").replace("{Las}", "The").replace("{la}", "the").replace("{La}", "The")
            .replace("{una}", "a").replace("{lo}", "it").replace("{Lo}", "It")
        if (L10n.lang == Lang.pt) return t
            .replace("{HUCHAS}", Animal.plural.uppercase())
            .replace("{HUCHA}", Animal.singular.uppercase())
            .replace("{LAS}", if (f) "AS" else "OS").replace("{AS}", if (f) "AS" else "OS").replace("{A}", if (f) "A" else "O")
            .replace("{Huchas}", Animal.plural.capitalizedFirst)
            .replace("{Hucha}", Animal.singular.capitalizedFirst)
            .replace("{huchas}", Animal.plural).replace("{hucha}", Animal.singular)
            .replace("{as}", if (f) "as" else "os").replace("{a}", if (f) "a" else "o")
            .replace("{las}", if (f) "as" else "os").replace("{Las}", if (f) "As" else "Os")
            .replace("{la}", if (f) "a" else "o").replace("{La}", if (f) "A" else "O")
            .replace("{una}", if (f) "uma" else "um").replace("{lo}", if (f) "a" else "o").replace("{Lo}", if (f) "A" else "O")
        return t
            .replace("{HUCHAS}", Animal.plural.uppercase())
            .replace("{HUCHA}", Animal.singular.uppercase())
            .replace("{LAS}", if (f) "LAS" else "LOS")
            .replace("{AS}", if (f) "AS" else "OS")
            .replace("{A}", if (f) "A" else "O")
            .replace("{Huchas}", Animal.plural.capitalizedFirst)
            .replace("{Hucha}", Animal.singular.capitalizedFirst)
            .replace("{huchas}", Animal.plural)
            .replace("{hucha}", Animal.singular)
            .replace("{as}", if (f) "as" else "os")
            .replace("{a}", if (f) "a" else "o")
            .replace("{las}", if (f) "las" else "los")
            .replace("{Las}", if (f) "Las" else "Los")
            .replace("{la}", if (f) "la" else "el")
            .replace("{La}", if (f) "La" else "El")
            .replace("{una}", if (f) "una" else "un")
            .replace("{lo}", if (f) "la" else "lo")
            .replace("{Lo}", if (f) "La" else "Lo")
    }

val String.capitalizedFirst: String get() = take(1).uppercase() + drop(1)

/** «+%» en una descripción: cambia la primera marca por el valor */
fun String.filling(v: String): String = L10n.tr(this).replaceFirst("%", v)
