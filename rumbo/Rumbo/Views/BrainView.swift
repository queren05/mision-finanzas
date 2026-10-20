import SwiftUI
import PhotosUI
import QuickLook
import UniformTypeIdentifiers
import VisionKit

/// 2. Segundo cerebro: todos tus papeles en un sitio, ordenados por Claude, y preguntas al momento
struct BrainView: View {
    @Environment(Store.self) private var store
    @State private var folder: BrainFolder? = nil
    @State private var scanning = false
    @State private var importing = false
    @State private var pickingPhotos = false
    @State private var photos: [PhotosPickerItem] = []
    @State private var newNote = false
    @State private var search = ""
    @State private var working = 0
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 18) {
                    hero.appear(0)
                    addBar.appear(0.03)
                    ask.appear(0.05)
                    folders.appear(0.1)
                    docsList.appear(0.15)
                    Color.clear.frame(height: 30)
                }
                .padding(.horizontal, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Mi segundo cerebro")
            .searchable(text: $search, prompt: "Buscar en tus documentos")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { if working > 0 { ProgressView() } }
                ToolbarItem(placement: .topBarTrailing) { addMenu }
                ToolbarItem(placement: .topBarTrailing) { SettingsButton() }
            }
            .navigationDestination(for: BrainDoc.self) { DocDetail(docId: $0.id) }
            .fullScreenCover(isPresented: $scanning) {
                DocScanner { pages in
                    scanning = false
                    Task { await addScan(pages) }
                }
                .ignoresSafeArea()
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .image, .plainText, .text], allowsMultipleSelection: true) { r in
                switch r {
                case .success(let urls): Task { for u in urls { await addFile(u) } }
                case .failure(let e): store.error = "No se ha podido abrir el archivo: \(e.localizedDescription)"
                }
            }
            .photosPicker(isPresented: $pickingPhotos, selection: $photos, maxSelectionCount: 10, matching: .images)
            .onChange(of: photos) { _, items in
                guard !items.isEmpty else { return }
                photos = []
                Task {
                    for item in items {
                        if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { await addImage(img) }
                        else { store.error = "No se ha podido leer una de las fotos." }
                    }
                }
            }
            .sheet(isPresented: $newNote) { NoteEditor(folder: folder ?? .notas) }
            .task { await demoAdd() }
        }
    }

    private func scan() {
        if VNDocumentCameraViewController.isSupported { scanning = true }
        else { store.error = "Este iPhone no puede usar el escáner. Haz una foto y añádela desde Fotos." }
    }

    private var addMenu: some View {
        Menu {
            Button { scan() } label: { Label("Escanear documento", systemImage: "doc.viewfinder") }
            Button { pickingPhotos = true } label: { Label("Desde Fotos", systemImage: "photo.on.rectangle") }
            Button { importing = true } label: { Label("PDF o archivo", systemImage: "doc.badge.plus") }
            Button { newNote = true } label: { Label("Nota", systemImage: "square.and.pencil") }
        } label: { Image(systemName: "plus.circle.fill").font(.title3) }
    }

    private var hero: some View {
        let month = Day.monthKey(Day.today)
        let spent = store.s.docs.filter { Day.monthKey($0.docDate.isEmpty ? Day.str($0.created) : $0.docDate) == month }.compactMap(\.amount).reduce(0, +)
        let soon = store.s.docs.filter { !$0.due.isEmpty && $0.due >= Day.today && $0.due <= Day.add(Day.today, days: 30) }.count
        return HStack(spacing: 12) {
            stat("\(store.s.docs.count)", "documentos", "doc.on.doc.fill", Color(hex: "#8fb4ff"))
            stat(Money.eur(spent), "en recibos este mes", "receipt.fill", Color(hex: "#62cfd0"))
            stat("\(soon)", "vencen en 30 días", "calendar.badge.exclamationmark", Color(hex: "#ff9f7a"))
        }
    }
    private func stat(_ v: String, _ l: String, _ icon: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(c)
            Text(v).font(.system(size: 20, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6).contentTransition(.numericText())
            Text(l).font(.caption).foregroundStyle(.secondary).lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading).card(14)
    }

    private var addBar: some View {
        HStack(spacing: 10) {
            addButton("Escanear", "doc.viewfinder", "#62cfd0") { scan() }
            addButton("Fotos", "photo.on.rectangle", "#b39cff") { pickingPhotos = true }
            addButton("Archivo", "doc.badge.plus", "#7ac8ff") { importing = true }
            addButton("Nota", "square.and.pencil", "#f0c46a") { newNote = true }
        }
    }
    private func addButton(_ t: String, _ icon: String, _ c: String, _ action: @escaping () -> Void) -> some View {
        Button { Haptic.tap(); action() } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title2.weight(.semibold)).foregroundStyle(Color(hex: c))
                Text(t).font(.caption.weight(.semibold)).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Color.cardBG, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private var ask: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardTitle(title: "Pregúntale lo que quieras", icon: "sparkles")
            AskBox(placeholder: "¿Cuánto me gasté en el súper este mes?",
                   suggestions: ["¿Cuánto me gasté en recibos este mes?", "¿Cuándo vence mi seguro del coche?", "¿Qué facturas tengo pendientes?", "¿Qué garantías tengo?"],
                   busyKey: "brain", answers: store.s.brainQA) { q in await store.askBrain(q) }
        }
        .card()
    }

    private var folders: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(BrainFolder.allCases) { f in
                let n = store.s.docs.filter { $0.folder == f }.count
                Button {
                    Haptic.select()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { folder = folder == f ? nil : f }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: f.icon).font(.title2).foregroundStyle(Color(hex: f.color))
                        Text(f.label).font(.caption.weight(.semibold)).lineLimit(1)
                        Text("\(n)").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(folder == f ? Color(hex: f.color).opacity(0.25) : Color.cardBG, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(folder == f ? Color(hex: f.color) : .clear, lineWidth: 2))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var shown: [BrainDoc] {
        let q = search.lowercased()
        return store.s.docs.filter { d in
            (folder == nil || d.folder == folder) &&
            (q.isEmpty || (d.title + " " + d.summary + " " + d.issuer + " " + d.text).lowercased().contains(q))
        }
    }

    @ViewBuilder private var docsList: some View {
        if store.s.docs.isEmpty {
            EmptyCard(icon: "doc.viewfinder", title: "Sin documentos", text: "")
        } else {
            VStack(spacing: 0) {
                ForEach(shown) { d in
                    NavigationLink(value: d) { DocRow(doc: d) }.buttonStyle(.plain)
                    if d.id != shown.last?.id { Divider().padding(.leading, 60) }
                }
                if shown.isEmpty { Text("Nada por aquí").foregroundStyle(.secondary).padding() }
            }
            .card(10)
        }
    }

    // MARK: añadir

    /// guarda el documento nuevo (en la carpeta que estés viendo) y lo abre
    private func added(_ d: BrainDoc) async {
        var d = d
        if let folder { d.folder = folder }
        store.save(d); Haptic.success()
        search = ""
        path.append(d)
        await store.organize(d.id)
    }

    private func addScan(_ pages: [UIImage]) async {
        guard !pages.isEmpty else { return }
        working += 1; defer { working -= 1 }
        let pdf = Extract.pdf(from: pages)
        var text = ""
        for p in pages { if let cg = p.cgImage { text += await Extract.text(in: cg) + "\n" } }
        guard !pdf.isEmpty else { store.error = "No se ha podido guardar el escaneo."; return }
        await added(BrainDoc(title: "Escaneo del \(Day.shortLabel(Day.today))", kind: pages.count == 1 ? "image" : "pdf",
                             file: pages.count == 1 ? Extract.store(Extract.jpeg(pages[0], maxSide: 2200), ext: "jpg") : Extract.store(pdf, ext: "pdf"),
                             text: text, docDate: Day.today))
    }
    private func addImage(_ img: UIImage) async {
        working += 1; defer { working -= 1 }
        let data = Extract.jpeg(img, maxSide: 2200)
        let text = await Extract.imageText(data)
        await added(BrainDoc(title: "Foto del \(Day.shortLabel(Day.today))", kind: "image", file: Extract.store(data, ext: "jpg"), text: text))
    }
    private func addFile(_ url: URL) async {
        working += 1; defer { working -= 1 }
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { store.error = "No se ha podido leer «\(url.lastPathComponent)»."; return }
        let ext = url.pathExtension.lowercased()
        var d = BrainDoc(title: url.deletingPathExtension().lastPathComponent)
        if ext == "pdf" { d.kind = "pdf"; d.text = await Extract.pdfText(data); d.file = Extract.store(data, ext: "pdf") }
        else if let img = UIImage(data: data) { d.kind = "image"; let j = Extract.jpeg(img, maxSide: 2200); d.text = await Extract.imageText(j); d.file = Extract.store(j, ext: "jpg") }
        else if let t = String(data: data, encoding: .utf8) { d.kind = "note"; d.text = t }
        else { store.error = "«\(url.lastPathComponent)» no es un PDF, una imagen ni un texto."; return }
        await added(d)
    }

    /// prueba automática del simulador (-testadd): añade un ticket dibujado como si viniera de Fotos
    private func demoAdd() async {
        guard ProcessInfo.processInfo.arguments.contains("-testadd"), !store.s.docs.contains(where: { $0.title.hasPrefix("Foto") }) else { return }
        let size = CGSize(width: 900, height: 1300)
        let img = UIGraphicsImageRenderer(size: size).image { _ in
            UIColor.white.setFill(); UIRectFill(CGRect(origin: .zero, size: size))
            let lines = ["MERCADONA S.A.", "C/ Mayor 12, Coslada", "FACTURA SIMPLIFICADA", "Fecha: 18/10/2026", "", "LECHE ENTERA      1,05", "PAN BARRA          0,60", "POLLO ENTERO       6,20", "TOMATES            2,15", "", "TOTAL (€)         10,00", "TARJETA BANCARIA"]
            for (i, l) in lines.enumerated() {
                (l as NSString).draw(at: CGPoint(x: 70, y: 80 + i * 90), withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 52, weight: .bold), .foregroundColor: UIColor.black])
            }
        }
        await addImage(img)
    }
}

struct DocRow: View {
    @Environment(Store.self) private var store
    var doc: BrainDoc
    var body: some View {
        HStack(spacing: 12) {
            Thumb(doc: doc, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title).font(.body.weight(.semibold)).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            if store.busy.contains("org-" + doc.id) { ProgressView() }
            else if let a = doc.amount { Text(Money.eur(a)).font(.subheadline.weight(.bold)).monospacedDigit() }
            else { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }
        }
        .padding(.vertical, 8).padding(.horizontal, 6)
        .contentShape(Rectangle())
    }
    private var subtitle: String {
        var p: [String] = [doc.folder.label]
        p.append(Day.shortLabel(doc.docDate.isEmpty ? Day.str(doc.created) : doc.docDate))
        if !doc.due.isEmpty { p.append("vence \(Day.shortLabel(doc.due))") }
        return p.joined(separator: " · ")
    }
}

/// miniatura: la foto si es una imagen, si no el icono de la carpeta
struct Thumb: View {
    var doc: BrainDoc
    var size: CGFloat
    var body: some View {
        Group {
            if doc.kind == "image", let f = doc.file, let ui = UIImage(contentsOfFile: Extract.url(f).path) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Image(systemName: doc.kind == "pdf" ? "doc.richtext.fill" : doc.folder == .recibos ? "receipt.fill" : doc.kind == "note" ? "note.text" : doc.folder.icon)
                    .font(.system(size: size * 0.45)).foregroundStyle(Color(hex: doc.folder.color))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(hex: doc.folder.color).opacity(0.18))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
    }
}

struct DocDetail: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let docId: String
    @State private var preview: URL? = nil
    @State private var askDelete = false
    @State private var amountText = ""
    @FocusState private var amountFocus: Bool

    var body: some View {
        if let d = store.s.docs.first(where: { $0.id == docId }) {
            let set: (BrainDoc) -> Void = { store.save($0) }
            List {
                if let f = d.file {
                    Section {
                        Button { preview = Extract.url(f) } label: {
                            if d.kind == "image", let ui = UIImage(contentsOfFile: Extract.url(f).path) {
                                Image(uiImage: ui).resizable().scaledToFit().frame(maxHeight: 260).frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            } else {
                                Label("Ver el PDF", systemImage: "doc.richtext")
                            }
                        }
                    }
                    .listRowBackground(d.kind == "image" ? Color.clear : nil)
                    .listRowInsets(d.kind == "image" ? EdgeInsets() : nil)
                }
                Section {
                    TextField("Título", text: Binding(get: { d.title }, set: { var n = d; n.title = $0; set(n) })).font(.title3.weight(.bold))
                    Picker("Carpeta", selection: Binding(get: { d.folder }, set: { var n = d; n.folder = $0; set(n); Haptic.select() })) {
                        ForEach(BrainFolder.allCases) { Label($0.label, systemImage: $0.icon).tag($0) }
                    }
                }
                Section("Datos") {
                    LabeledContent("Tienda o empresa") {
                        TextField("—", text: Binding(get: { d.issuer }, set: { var n = d; n.issuer = $0; set(n) })).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Importe") {
                        TextField("0,00 €", text: $amountText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($amountFocus)
                            .onChange(of: amountText) { _, t in var n = d; n.amount = t.isEmpty ? nil : Money.parse(t); set(n) }
                    }
                    dateRow("Fecha", d.docDate) { var n = d; n.docDate = $0; set(n) }
                    dateRow("Vence", d.due) { var n = d; n.due = $0; set(n) }
                }
                if !d.summary.isEmpty { Section("Resumen") { Text(d.summary) } }
                Section {
                    if store.busy.contains("org-" + d.id) { HStack { ProgressView(); Text("Claude lo está leyendo…").foregroundStyle(.secondary) } }
                    else { AIButton(title: "Leer con Claude", key: "org-" + d.id) { guard Claude.hasKey else { store.error = Claude.Failure.noKey.errorDescription; return }; await store.organize(d.id); amountText = store.s.docs.first { $0.id == docId }?.amount.map(Money.num) ?? amountText } }
                }
                .listRowBackground(Color.clear)
                Section(d.kind == "note" ? "Nota" : "Texto") {
                    TextEditor(text: Binding(get: { d.text }, set: { var n = d; n.text = $0; set(n) })).frame(minHeight: 180)
                }
                Section { Button("Eliminar documento", role: .destructive) { Haptic.warning(); askDelete = true } }
            }
            .navigationTitle(d.folder.label).navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .quickLookPreview($preview)
            .onAppear { amountText = d.amount.map(Money.num) ?? "" }
            .onChange(of: d.amount) { _, a in if !amountFocus { amountText = a.map(Money.num) ?? "" } }
            .confirmationDialog("¿Seguro que quieres eliminar este documento?", isPresented: $askDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) { store.delete(d); Haptic.heavy(); dismiss() }
            } message: { Text(d.title) }
        } else {
            ContentUnavailableView("Documento eliminado", systemImage: "trash")
        }
    }

    /// fecha opcional: interruptor para ponerla o quitarla
    @ViewBuilder private func dateRow(_ label: String, _ value: String, _ set: @escaping (String) -> Void) -> some View {
        Toggle(label, isOn: Binding(get: { !value.isEmpty }, set: { set($0 ? Day.today : "") }))
        if !value.isEmpty {
            DatePicker(label == "Vence" ? "Día que vence" : "Día", selection: Binding(get: { Day.date(value) }, set: { set(Day.str($0)) }), displayedComponents: .date)
        }
    }
}

struct NoteEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var text = ""
    @State var folder: BrainFolder = .notas
    var body: some View {
        NavigationStack {
            Form {
                TextField("Título", text: $title)
                Picker("Carpeta", selection: $folder) { ForEach(BrainFolder.allCases) { Text($0.label).tag($0) } }
                Section("Nota") { TextEditor(text: $text).frame(minHeight: 240) }
            }
            .navigationTitle("Nueva nota").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let d = BrainDoc(title: title.isEmpty ? "Nota del \(Day.shortLabel(Day.today))" : title, folder: folder, kind: "note", text: text)
                        store.save(d); Haptic.success(); dismiss()
                        Task { await store.organize(d.id) }
                    }.bold().disabled(text.isEmpty && title.isEmpty)
                }
            }
        }
    }
}
