import SwiftUI

struct SettingsView: View {
    @AppStorage("tema") private var theme = Theme.auto
    @AppStorage("energia") private var energy = EnergyUnit.kcal
    @Environment(HealthStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var asked = 0

    /// Grupos de datos y si hay algo de ellos en el último mes.
    private var groups: [(String, String, Color, [Metric])] {
        [
            ("Sueño", "moon.zzz.fill", Palette.sleep, [.sleep]),
            ("Pulso y variabilidad", "heart.fill", Palette.heart, [.restingHR, .hrv]),
            ("Respiración", "lungs.fill", Palette.breath, [.respiratoryRate]),
            ("Actividad", "flame.fill", Palette.effort, [.steps, .activeEnergy, .exerciseMinutes]),
            ("VO₂ máx", "bolt.heart.fill", Palette.recovery, [.vo2max]),
            ("Peso", "scalemass.fill", Palette.body, [.weight]),
            ("Nutrición (Yazio)", "fork.knife", Palette.nutrition, [.calories, .protein]),
        ]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(groups, id: \.0) { g in
                        let found = g.3.contains { store.has($0) }
                        HStack {
                            Label {
                                Text(g.0)
                            } icon: {
                                Image(systemName: g.1).foregroundStyle(g.2)
                            }
                            Spacer()
                            Image(systemName: found ? "checkmark.circle.fill" : "minus.circle")
                                .foregroundStyle(found ? Palette.good : .secondary)
                        }
                    }
                    if !store.workouts.isEmpty {
                        LabeledContent("Entrenos", value: "\(store.workouts.count)")
                    }
                } header: {
                    Text("Datos encontrados")
                } footer: {
                    if let u = store.updated {
                        Text("Leído de \(store.source.name) a las \(Fmt.clock(u)).")
                    }
                }

                Section("Permisos") {
                    Button {
                        Task {
                            try? await HealthKitSource.shared.requestAuthorization()
                            await store.refresh(full: true)
                            asked += 1
                        }
                    } label: {
                        Label("Pedir permisos otra vez", systemImage: "checkmark.shield")
                    }
                    Button {
                        if let url = URL(string: "x-apple-health://") { openURL(url) }
                    } label: {
                        Label("Abrir Salud", systemImage: "heart.text.square")
                    }
                    Button {
                        Task { await store.refresh(full: true); asked += 1 }
                    } label: {
                        Label(store.loading ? "Leyendo…" : "Volver a leer todo", systemImage: "arrow.clockwise")
                    }
                    .disabled(store.loading)
                }

                Section {
                    NavigationLink {
                        WidgetsGalleryView()
                    } label: {
                        Label("Widgets", systemImage: "square.grid.3x3.square")
                    }
                }

                Section("Unidades") {
                    Picker("Energía", selection: $energy) {
                        Text("Kilocalorías").tag(EnergyUnit.kcal)
                        Text("Kilojulios").tag(EnergyUnit.kJ)
                    }
                }

                Section("Tema") {
                    Picker("Tema", selection: $theme) {
                        ForEach(Theme.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            .scrollContentBackground(.hidden)
            .background(MoodBackground(mood: .neutral))
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .sensoryFeedback(.success, trigger: asked)
        }
    }
}

#Preview {
    SettingsView()
        .environment(HealthStore.preview())
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
}
