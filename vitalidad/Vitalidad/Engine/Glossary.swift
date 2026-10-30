import Foundation

/// Qué es cada métrica y por qué importa, sin jerga.
enum Glossary {
    static func what(_ m: Metric) -> String {
        switch m {
        case .steps: "Los pasos que cuentan el reloj y el iPhone a lo largo del día."
        case .activeEnergy: "Las calorías que gastas al moverte, por encima de lo que gastarías quieto."
        case .basalEnergy: "Lo que gasta tu cuerpo solo por estar vivo: respirar, mantener la temperatura, pensar."
        case .exerciseMinutes: "Minutos en los que te moviste a paso ligero o más rápido."
        case .standHours: "Horas en las que te levantaste y te moviste al menos un minuto."
        case .heartRate: "La media de tus pulsaciones por minuto durante el día."
        case .restingHR: "Tus pulsaciones por minuto cuando estás quieto y tranquilo. Cuanto más bajo, más descansado y en forma suele estar el corazón."
        case .hrv: "La variabilidad cardíaca (VFC o HRV) mide cuánto cambia el tiempo entre latido y latido. El reloj la mide como SDNN, en milisegundos. Más variación significa un cuerpo relajado y recuperado."
        case .respiratoryRate: "Las veces que respiras por minuto mientras duermes."
        case .vo2max: "El VO₂ máx es la cantidad máxima de oxígeno que tu cuerpo puede usar al hacer ejercicio. Es la mejor medida de tu forma física."
        case .walkingHR: "Tu pulso medio mientras caminas a paso normal."
        case .weight: "Tu peso, de la báscula o de lo que apuntas en Salud."
        case .calories: "Las calorías que has comido, según lo que apuntas en Yazio."
        case .protein: "Los gramos de proteína que has comido (carne, pescado, huevos, legumbres, lácteos…)."
        case .carbs: "Los gramos de carbohidratos (pan, pasta, arroz, fruta, azúcar…)."
        case .fat: "Los gramos de grasa (aceite, frutos secos, queso, carne…)."
        case .water: "El agua que apuntas como bebida."
        case .sleep: "El tiempo que pasaste dormido de verdad, sin contar los ratos despierto en la cama."
        }
    }

    static func why(_ m: Metric) -> String {
        switch m {
        case .steps: "Caminar a diario es de lo que más protege el corazón y la cabeza. Lo importante es moverte de forma constante."
        case .activeEnergy: "Te dice cuánto te has movido de verdad, incluido el ejercicio. Sirve para comparar días y para cuadrar lo que comes."
        case .basalEnergy: "Sumada a la energía activa, te da lo que gastas en total en un día."
        case .exerciseMinutes: "La recomendación es llegar a unos 150 minutos a la semana. Es lo que más mejora tu forma física."
        case .standHours: "Pasar muchas horas sentado seguido es malo aunque luego hagas deporte. Levantarte cada hora ayuda."
        case .heartRate: "Sube con el esfuerzo, el estrés, el café o el calor. Sirve de contexto para el resto de datos."
        case .restingHR: "Si sube unos latidos sobre tu media, suele ser señal de cansancio, estrés, alcohol o que te estás poniendo malo. Si baja con los meses, estás ganando forma."
        case .hrv: "Es la mejor pista de si tu cuerpo está recuperado. Cada persona tiene sus valores, por eso aquí se compara solo contigo: lo que importa es si estás por encima o por debajo de tu normal."
        case .respiratoryRate: "Suele ser muy estable. Si sube de golpe, a veces avisa de un catarro o de una mala noche antes de que lo notes."
        case .vo2max: "Cuanto más alto, mejor aguanta tu corazón el esfuerzo y más años de vida sana se esperan. Sube con cardio constante."
        case .walkingHR: "Si con el tiempo baja, tu corazón trabaja menos para lo mismo: estás más en forma."
        case .weight: "Un día suelto no dice nada (agua, comida, sal). Mira la tendencia de semanas."
        case .calories: "Compararlas con lo que gastas te dice si estás comiendo de más o de menos para tu objetivo."
        case .protein: "Ayuda a recuperar los músculos y a quedarte saciado. Para alguien activo, entre 1,4 y 2 g por kilo de peso al día es un buen rango."
        case .carbs: "Son el combustible principal para entrenar. En días de mucho esfuerzo conviene más."
        case .fat: "Necesaria para las hormonas y para absorber vitaminas. Llena mucho con poca cantidad."
        case .water: "Beber poco se nota en el cansancio, la concentración y el pulso."
        case .sleep: "Es la base de todo: con poco sueño baja la variabilidad, sube el pulso en reposo y rindes peor. La mayoría de adultos necesita entre 7 y 9 horas."
        }
    }
}
