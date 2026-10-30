import SwiftUI

/// Primera pantalla: qué lee la app y botón para dar permiso a Salud.
struct WelcomeView: View {
    var onDone: () -> Void
    @State private var asking = false
    @State private var failed = false

    private let rows: [(String, Color, String, String)] = [
        ("moon.zzz.fill", Palette.sleep, "Sueño", "Horas, fases y a qué hora te acuestas"),
        ("heart.fill", Palette.heart, "Corazón", "Pulso en reposo, variabilidad y respiración"),
        ("flame.fill", Palette.effort, "Actividad", "Pasos, energía, ejercicio y entrenos"),
        ("fork.knife", Palette.nutrition, "Nutrición", "Lo que apuntas en Yazio"),
    ]

    var body: some View {
        ZStack {
            MoodBackground(mood: .recovered)
            ScrollView {
                VStack(spacing: Space.xxl) {
                    ZStack {
                        Ring(progress: 0.78, color: Palette.recovery, lineWidth: 14).frame(width: 128, height: 128)
                        Ring(progress: 0.62, color: Palette.effort, lineWidth: 14).frame(width: 92, height: 92)
                        Ring(progress: 0.86, color: Palette.sleep, lineWidth: 14).frame(width: 56, height: 56)
                    }
                    .padding(.top, 56)
                    .stagger(0)

                    VStack(spacing: Space.s) {
                        Text("Vitalidad")
                            .bigFont(44)
                        Text("Tus datos de salud, explicados y comparados contigo mismo.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .stagger(1)

                    VStack(alignment: .leading, spacing: Space.l) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                            HStack(spacing: Space.l) {
                                MetricGlyph(symbol: r.0, color: r.1, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.2).font(.headline)
                                    Text(r.3).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            .stagger(i + 2)
                        }
                    }
                    .card()

                    Label("Solo lectura. Tus datos no salen del iPhone.", systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .stagger(7)
                }
                .padding(.horizontal, Space.xl)
                .padding(.bottom, 140)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack {
                Spacer()
                Button {
                    connect()
                } label: {
                    HStack {
                        if asking { ProgressView().tint(.white) }
                        Text("Conectar con Salud").font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .primaryButton()
                .controlSize(.large)
                .tint(Palette.recovery)
                .disabled(asking)
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.l)
            }
        }
        .sensoryFeedback(.success, trigger: asking) { old, new in old && !new && !failed }
        .alert("No se pudo conectar con Salud", isPresented: $failed) {
            Button("Entrar igualmente") { onDone() }
            Button("Reintentar", role: .cancel) { connect() }
        } message: {
            Text("Es posible que el certificado con el que firmaste la app no incluya HealthKit. Mira la guía de instalación.")
        }
    }

    private func connect() {
        asking = true
        Task {
            do {
                try await HealthKitSource.shared.requestAuthorization()
                asking = false
                onDone()
            } catch {
                failed = true
                asking = false
            }
        }
    }
}

#Preview {
    WelcomeView {}
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
}
