import SwiftUI
import VisionKit
import PhotosUI

/// Lo que has apuntado un día, por comidas.
struct FoodDayCard: View {
    @Environment(HealthStore.self) private var store
    @State private var log = FoodLog.shared
    var day: Date
    @State private var add = Launch.args.contains("-comer")
    @State private var deleting: FoodEntry?

    var body: some View {
        let list = log.entries(on: day)
        let total = list.reduce(0) { $0 + $1.kcal }
        VStack(alignment: .leading, spacing: Space.l) {
            CardHeader("Lo que has comido", symbol: "fork.knife", color: Palette.nutrition,
                       trailing: list.isEmpty ? nil : Fmt.full(.calories, total))
            ForEach(Meal.allCases) { m in
                let items = list.filter { $0.meal == m }
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: Space.s) {
                        HStack {
                            Label(m.title, systemImage: m.symbol).font(.subheadline.weight(.bold)).foregroundStyle(Palette.nutrition)
                            Spacer()
                            Text(Fmt.full(.calories, items.reduce(0) { $0 + $1.kcal })).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        ForEach(items) { e in
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(e.item.name).font(.subheadline).lineLimit(1)
                                    Text("\(Fmt.number(e.grams)) g · P \(Fmt.number(e.protein)) · C \(Fmt.number(e.carbs)) · G \(Fmt.number(e.fat))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(Fmt.number(Fmt.energy(e.kcal))).font(.subheadline.weight(.semibold).monospacedDigit())
                            }
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button(role: .destructive) { deleting = e } label: { Label("Borrar", systemImage: "trash") }
                            }
                        }
                    }
                }
            }
            HStack(spacing: Space.s) {
                Button { add = true } label: {
                    Label("Apuntar comida", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(Palette.nutrition))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Button {
                    Task { await log.addWater(0.25, store: store) }
                } label: {
                    Label("250 ml", systemImage: "drop.fill")
                        .font(.subheadline.weight(.bold))
                        .padding(.vertical, 13).padding(.horizontal, 14)
                        .background(Capsule().fill(Palette.breath.opacity(0.18)))
                        .foregroundStyle(Palette.breath)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Apuntar un vaso de agua")
            }
        }
        .card(tint: Palette.nutrition)
        .sheet(isPresented: $add) { AddFoodView(day: day) }
        .confirmationDialog("¿Borrar \(deleting?.item.name ?? "")?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                if let e = deleting { Task { await log.delete(e, store: store) } }
                deleting = nil
            }
            Button("Cancelar", role: .cancel) { deleting = nil }
        }
        .sensoryFeedback(.success, trigger: log.entries.count)
    }
}

/// Buscar, escanear o hacer foto para apuntar una comida.
struct AddFoodView: View {
    var day: Date
    @Environment(\.dismiss) private var dismiss
    @State private var log = FoodLog.shared
    @State private var query = ""
    @State private var results: [FoodItem] = []
    @State private var searching = false
    @State private var scan = false
    @State private var camera = false
    @State private var photo: PhotosPickerItem?
    @State private var picked: FoodItem?
    @State private var fromPhoto: [(FoodItem, Double)] = []
    @State private var thinking = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: Space.s) {
                        if DataScannerViewController.isSupported {
                            tool("Código", "barcode.viewfinder") { scan = true }
                        }
                        if Claude.hasKey {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                tool("Foto", "camera.fill") { camera = true }
                            }
                            PhotosPicker(selection: $photo, matching: .images) {
                                toolLabel("Galería", "photo.on.rectangle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                if thinking {
                    Section { HStack { ProgressView(); Text("Mirando la foto…").foregroundStyle(.secondary) } }
                }
                if let error {
                    Section { Text(error).foregroundStyle(Palette.heart) }
                }
                if !fromPhoto.isEmpty {
                    Section("En la foto") {
                        ForEach(Array(fromPhoto.enumerated()), id: \.offset) { _, f in
                            Button { picked = f.0 } label: { FoodRow(item: f.0, grams: f.1) }.buttonStyle(.plain)
                        }
                    }
                }
                if query.isEmpty {
                    if !log.recents.isEmpty {
                        Section("Recientes") {
                            ForEach(log.recents) { f in Button { picked = f } label: { FoodRow(item: f) }.buttonStyle(.plain) }
                        }
                    }
                } else {
                    Section {
                        if searching && results.isEmpty {
                            HStack { ProgressView(); Text("Buscando…").foregroundStyle(.secondary) }
                        }
                        ForEach(results) { f in Button { picked = f } label: { FoodRow(item: f) }.buttonStyle(.plain) }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar alimento o marca")
            .task(id: query) {
                let q = query.trimmingCharacters(in: .whitespaces)
                guard q.count >= 2 else { results = []; return }
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard !Task.isCancelled else { return }
                searching = true
                let r = await OpenFoodFacts.search(q)
                if !Task.isCancelled { results = r }
                searching = false
            }
            .navigationTitle("Apuntar comida")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } } }
            .sheet(item: $picked) { f in
                FoodAmountView(item: f, day: day) { dismiss() }
            }
            .fullScreenCover(isPresented: $scan) {
                BarcodeScanner { code in
                    scan = false
                    Task {
                        if let f = await OpenFoodFacts.product(code) { picked = f } else { error = "No encuentro el código \(code) en Open Food Facts." }
                    }
                }
                .ignoresSafeArea()
                .overlay(alignment: .topTrailing) {
                    Button { scan = false } label: { Image(systemName: "xmark.circle.fill").font(.largeTitle).symbolRenderingMode(.hierarchical) }
                        .padding()
                }
            }
            .fullScreenCover(isPresented: $camera) {
                CameraPicker { img in
                    camera = false
                    if let img { analyze(img.jpegData(compressionQuality: 0.6)) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: photo) { _, p in
                guard let p else { return }
                Task {
                    if let d = try? await p.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                        analyze(img.jpegData(compressionQuality: 0.6))
                    }
                    photo = nil
                }
            }
        }
    }

    private func analyze(_ jpeg: Data?) {
        guard let jpeg else { return }
        thinking = true
        error = nil
        Task {
            do { fromPhoto = try await FoodPhoto.analyze(jpeg, hint: query) } catch { self.error = error.localizedDescription }
            thinking = false
        }
    }

    private func tool(_ t: String, _ s: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) { toolLabel(t, s) }.buttonStyle(.plain)
    }

    private func toolLabel(_ t: String, _ s: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: s).font(.title2)
            Text(t).font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.m)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.nutrition.opacity(0.14)))
        .foregroundStyle(Palette.nutrition)
    }
}

struct FoodRow: View {
    var item: FoodItem
    var grams: Double? = nil
    var body: some View {
        HStack(spacing: Space.m) {
            AsyncImage(url: item.image.flatMap(URL.init(string:))) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "fork.knife").foregroundStyle(Palette.nutrition)
            }
            .frame(width: 40, height: 40)
            .background(Palette.nutrition.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).foregroundStyle(.primary).lineLimit(2)
                Text([item.brand, grams.map { "\(Fmt.number($0)) g" }].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(Fmt.number(Fmt.energy(item.kcal * (grams ?? 100) / 100))).font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(.primary)
                Text(grams == nil ? "\(Fmt.energyUnit)/100 g" : Fmt.energyUnit).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

/// Cuánto has comido y en qué comida.
struct FoodAmountView: View {
    var item: FoodItem
    var day: Date
    var done: () -> Void
    @Environment(HealthStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var grams: Double = 100
    @State private var meal = Meal.now
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    FoodRow(item: item)
                }
                Section("Cantidad") {
                    HStack {
                        NumberField(value: $grams, decimals: false).frame(width: 90)
                        Text("gramos").foregroundStyle(.secondary)
                        Spacer()
                        Stepper("", value: $grams, in: 0...3000, step: 10).labelsHidden()
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if let s = item.serving, s > 0 { chip("1 ración (\(Fmt.number(s)) g)", s) }
                            ForEach([30.0, 50, 100, 150, 200, 300], id: \.self) { g in chip("\(Fmt.number(g)) g", g) }
                        }
                    }
                }
                Section("Comida") {
                    Picker("Comida", selection: $meal) {
                        ForEach(Meal.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    HStack(spacing: 0) {
                        macro(Fmt.number(Fmt.energy(item.kcal * grams / 100)), Fmt.energyUnit, Palette.nutrition)
                        macro(Fmt.number(item.protein * grams / 100), "proteína", Palette.recovery)
                        macro(Fmt.number(item.carbs * grams / 100), "carbos", Palette.effort)
                        macro(Fmt.number(item.fat * grams / 100), "grasa", Palette.breath)
                    }
                }
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Añadir") {
                        saving = true
                        Task {
                            await FoodLog.shared.add(item, grams: grams, meal: meal, day: day, store: store)
                            dismiss()
                            done()
                        }
                    }
                    .bold()
                    .disabled(grams <= 0 || saving)
                }
            }
            .onAppear { if let s = item.serving, s > 0 { grams = s } }
        }
        .presentationDetents([.large])
    }

    private func chip(_ t: String, _ g: Double) -> some View {
        Button { grams = g } label: {
            Text(t).font(.caption.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Capsule().fill(grams == g ? Palette.nutrition : Ink.track.opacity(0.5)))
                .foregroundStyle(grams == g ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func macro(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(c).monospacedDigit()
            Text(l).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Cámara

/// Lector de códigos de barras con la cámara.
struct BarcodeScanner: UIViewControllerRepresentable {
    var found: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
                                           qualityLevel: .balanced, recognizesMultipleItems: false,
                                           isHighFrameRateTrackingEnabled: false, isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(found: found) }

    @MainActor final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var found: (String) -> Void
        var done = false
        init(found: @escaping (String) -> Void) { self.found = found }

        func dataScanner(_ s: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !done else { return }
            for i in items {
                if case .barcode(let b) = i, let code = b.payloadStringValue {
                    done = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    found(code)
                    return
                }
            }
        }
    }
}

/// Hacer una foto con la cámara.
struct CameraPicker: UIViewControllerRepresentable {
    var picked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(picked: picked) }

    @MainActor final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var picked: (UIImage?) -> Void
        init(picked: @escaping (UIImage?) -> Void) { self.picked = picked }
        func imagePickerController(_ p: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picked(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ p: UIImagePickerController) { picked(nil) }
    }
}
