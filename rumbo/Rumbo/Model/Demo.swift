import Foundation

/// datos de ejemplo solo para las capturas del simulador (argumento -demo); nunca se usan en el iPhone
enum Demo {
    static func fill(_ store: Store) {
        guard store.s.docs.isEmpty else { return }
        var st = store.s
        st.briefing = Briefing(date: Day.today, text: "¡Buenos días, David! Hoy tienes un día tranquilo.\n• Empieza por revisar el presupuesto del mes: es tu prioridad y tienes la mañana libre.\n• Llama al seguro del coche antes del viernes: vence el día 24.\n• A las 18:00 tienes gimnasio; deja las 20 páginas para la noche.\nVas por buen camino: 4 días seguidos cumpliendo lo importante 💪")
        st.docs = [
            BrainDoc(title: "Seguro del coche Mapfre", folder: .seguros, kind: "pdf", text: "Póliza 123. Vencimiento 24/06/2027. Prima anual 420 €.", summary: "Póliza a todo riesgo. Vence el 24 de junio de 2027. Prima anual: 420 €."),
            BrainDoc(title: "Contrato de alquiler", folder: .alquileres, kind: "pdf", text: "Fin del contrato 12/11/2027. Renta 750 €.", summary: "Termina el 12 de noviembre de 2027. Renta de 750 € al mes."),
            BrainDoc(title: "Garantía del portátil", folder: .recibos, kind: "image", text: "Garantía 3 años desde 03/2025", summary: "Garantía hasta marzo de 2028."),
            BrainDoc(title: "Factura de la luz", folder: .recibos, kind: "pdf", text: "Endesa", summary: "Factura de septiembre.", amount: 48.37, docDate: Day.add(Day.today, days: -6), due: Day.add(Day.today, days: 4), issuer: "Endesa"),
            BrainDoc(title: "Compra Mercadona", folder: .recibos, kind: "image", text: "Ticket", summary: "Compra semanal.", amount: 32.15, docDate: Day.add(Day.today, days: -2), issuer: "Mercadona"),
            BrainDoc(title: "Gasolina Repsol", folder: .recibos, kind: "image", text: "Ticket", summary: "Repostaje.", amount: 40, docDate: Day.today, issuer: "Repsol"),
        ]
        st.docs[0].due = Day.add(Day.today, days: 9)
        st.tasks = [TaskItem(title: "Revisar el presupuesto del mes", priority: true, due: Day.today),
                    TaskItem(title: "Llamar al seguro del coche", due: Day.add(Day.today, days: 2)),
                    TaskItem(title: "Pagar la factura de la luz", due: Day.add(Day.today, days: 4)),
                    TaskItem(title: "Leer 20 páginas")]
        st.brainQA = [QA(question: "¿Cuándo vence mi seguro del coche?", answer: "Tu seguro del coche vence el 24 de junio de 2027 y la prima anual es de 420 €.", sources: ["Seguro del coche Mapfre"])]
        st.checkIns = [CheckIn(date: Day.today, mood: 4, text: "Cerré la propuesta y fui al gimnasio. Me distraje por la mañana.",
                               wins: ["Cerré la propuesta", "Buena llamada con cliente", "Fui al gimnasio"],
                               improve: ["Me distraje por la mañana", "No hice el seguimiento", "Demasiado tiempo en reuniones"]),
                       CheckIn(date: Day.add(Day.today, days: -1), mood: 3, text: "Día normal", wins: ["Leí 20 páginas"], improve: [])]
        st.weekly = [WeeklyReview(weekStart: Store.weekStart(Day.today), summary: ["4 días cumpliste las prioridades", "Buen ritmo de trabajo", "Necesitas mejorar el foco por las mañanas"],
                                  improvements: ["Bloquear mañanas", "Agrupar reuniones", "Hacer seguimiento antes"],
                                  focus: "trabajo profundo y seguimientos", goal: "cerrar la propuesta", habit: "rutina de mañana a las 8:00")]
        st.library = [
            LibItem(kind: .libro, title: "Hábitos atómicos", author: "James Clear", status: .terminado, rating: 5, ideas: ["Mejorar un 1 % cada día", "Sistemas mejor que metas", "Haz los buenos hábitos obvios y fáciles"], color: "#f0c46a", finished: Day.today),
            LibItem(kind: .libro, title: "Deep Work", author: "Cal Newport", status: .enCurso, rating: 4, color: "#7ac8ff"),
            LibItem(kind: .libro, title: "Flow", author: "Mihaly Csikszentmihalyi", status: .terminado, rating: 4, color: "#b39cff", finished: Day.today),
            LibItem(kind: .podcast, title: "Cómo organizar tu semana", author: "Podcast", status: .pendiente, color: "#ff9ecf"),
        ]
        st.libraryQA = [QA(question: "¿Cuáles son las ideas clave sobre productividad?", answer: "• Trabaja en bloques sin distracciones — Deep Work\n• Mejora un 1 % cada día con sistemas — Hábitos atómicos\n• Busca tareas con reto y foco total — Flow", sources: ["Deep Work", "Hábitos atómicos", "Flow"])]
        st.brandInfo = BrandInfo(about: "StellIA: automatización con IA para pymes", samples: "", visual: "", audience: "Pymes y autónomos", offer: "Automatizaciones e IA", avoid: "Tecnicismos")
        st.kit = BrandKit(name: "StellIA", tagline: "Automatiza tu negocio con IA",
                          colors: [BrandColor(name: "Naranja", hex: "#F26B1D"), BrandColor(name: "Melocotón", hex: "#FFB38A"), BrandColor(name: "Carbón", hex: "#16151C"), BrandColor(name: "Crema", hex: "#FFF4EC"), BrandColor(name: "Gris", hex: "#8A8A93")],
                          headingFont: "rounded", bodyFont: "default", tone: ["Cercano y directo", "Profesional pero simple", "Enfocado en resultados", "Sin tecnicismos innecesarios", "Motivador y práctico"],
                          visual: ["Fondos oscuros con acentos naranjas", "Mucho aire", "Fotos reales de equipos"])
        st.pieces = [BrandPiece(type: "post", topic: "tareas repetitivas", title: "De tareas repetitivas a resultados reales", text: "Cada hora que pasas copiando datos es una hora que no dedicas a tus clientes. Te enseñamos a automatizarlo en una semana."),
                     BrandPiece(type: "web", topic: "landing", title: "Automatiza tu negocio con IA", text: "Más ventas, menos trabajo manual. Sistemas a medida para pymes.")]
        store.s = st
    }
}
