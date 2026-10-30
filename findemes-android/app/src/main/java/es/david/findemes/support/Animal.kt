package es.david.findemes.support

import es.david.findemes.model.SkinDef

/** Los textos hablan del animal que llevas: «+4 vacas a la vez», «+4 cerdos a la vez».
 *  En los textos se escribe {huchas}, {hucha}, {Hucha}, {HUCHAS} y las terminaciones {a}, {as}, {la}, {las}, {una}, {lo}. */
object Animal {
    var singular = "vaca"
    var plural = "vacas"
    var female = true

    fun use(s: SkinDef) {
        singular = s.singular; plural = s.plural; female = s.female
    }
}

/** cambia las marcas por el animal de ahora */
val String.a: String
    get() {
        if (!contains("{")) return this
        val f = Animal.female
        return this
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
fun String.filling(v: String): String = replaceFirst("%", v)
