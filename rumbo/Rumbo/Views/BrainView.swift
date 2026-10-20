import SwiftUI
import PhotosUI
import QuickLook
import UniformTypeIdentifiers

/// 2. Segundo cerebro: todos tus papeles en un sitio, ordenados por Claude, y preguntas al momento
struct BrainView: View {
    @Environment(Store.self) private var store
    @State private var folder: BrainFolder? = nil
    @State private var scanning = false
    @State private var importing = false
    @State private var photo: PhotosPickerItem? = nil
    @State private var newNote = false
    @State private var search = ""
    @State private var working = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hero.appear(0)
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
                ToolbarItem(placement: .topBarLeading) { if working { ProgressView() } }
                ToolbarItem(placement: .topBarTrailing) { addMenu }
                ToolbarItem(placement: .topBarTrailing) { SettingsButton() }
            }
            .navigationDestination(for: BrainDoc.self) { DocDetail(docId: $0.id) }
            .fullScreenCover(isPresented: $scanning) { DocScanner { pages in Task { await addScan(pages) } }.ignoresSafeArea() }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .image, .plainText], allowsMultipleSelection: true) { r in
                guard case .success(let urls) = r else { return }
                Task { for u in urls { await addFile(u) } }
            }
            .onChange(of: photo) { _, item in
                guard let item else { return }
                Task {
                    if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { await addImage(img) }
                    photo = nil
                }
            }
            .sheet(isPresented: $newNote) { NoteEditor() }
        }
    }

    private var addMenu: some View {
        Menu {
            Button { scanning = true } label: { Label("Escanear documento", systemImage: "doc.viewfinder") }
            PhotosPicker(selection: $photo, matching: .images) { Label("Desde Fotos", systemImage: "photo") }
            Button { importing = true } label: { Label("PDF o archivo", systemImage: "doc.badge.plus") }
            Button { newNote = true } label: { Label("Nota", systemImage: "square.and.pencil") }
        } label: { Image(systemName: "plus.circle.fill").font(.title3) }
    }

    private var hero: some View {
        HStack(spacing: 16) {
            Image(systemName: "brain.head.profile").font(.system(size: 40, weight: .semibold)).foregroundStyle(Color.income)
                .frame(width: 70, height: 70).background(Color.income.opacity(0.15), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("Todo organizado. Todo buscable.").font(.headline)
                Text("\(store.s.docs.count) documentos · contratos, seguros, recibos, notas…").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var ask: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardTitle(title: "Pregúntale lo que quieras", icon: "sparkles")
            AskBox(placeholder: "¿Cuándo vence mi seguro del coche?",
                   suggestions: ["¿Cuándo vence mi seguro del coche?", "¿Cuándo termina mi alquiler?", "¿Cuánto pago al año de seguro?", "¿Qué garantías tengo pendientes?"],
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
            (q.isEmpty || (d.title + " " + d.summary + " " + d.text).lowercased().contains(q))
        }
    }

    @ViewBuilder private var docsList: some View {
        if store.s.docs.isEmpty {
            EmptyCard(icon: "doc.viewfinder", title: "Mete aquí tus papeles", text: "Escanea contratos, seguros o recibos con la cámara, o añade PDFs y notas. Claude los ordena y luego le preguntas lo que quieras.")
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

    private func addScan(_ pages: [UIImage]) async {
        guard !pages.isEmpty else { return }
        working = true; defer { working = false }
        let pdf = Extract.pdf(from: pages)
        var text = ""
        for p in pages { if let cg = p.cgImage { text += await Extract.text(in: cg) + "\n" } }
        let d = BrainDoc(title: "Escaneo del \(Day.shortLabel(Day.today))", kind: "pdf", file: Extract.store(pdf, ext: "pdf"), text: text)
        store.save(d); Haptic.success()
        await store.organize(d.id)
    }
    private func addImage(_ img: UIImage) async {
        working = true; defer { working = false }
        let data = Extract.jpeg(img)
        let text = await Extract.imageText(data)
        let d = BrainDoc(title: "Foto del \(Day.shortLabel(Day.today))", kind: "image", file: Extract.store(data, ext: "jpg"), text: text)
        store.save(d); Haptic.success()
        await store.organize(d.id)
    }
    private func addFile(_ url: URL) async {
        working = true; defer { working = false }
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        let ext = url.pathExtension.lowercased()
        var d = BrainDoc(title: url.deletingPathExtension().lastPathComponent)
        if ext == "pdf" { d.kind = "pdf"; d.text = await Extract.pdfText(data); d.file = Extract.store(data, ext: "pdf") }
        else if ["txt", "md"].contains(ext) { d.kind = "note"; d.text = String(data: data, encoding: .utf8) ?? "" }
        else { d.kind = "image"; d.text = await Extract.imageText(data); d.file = Extract.store(data, ext: ext.isEmpty ? "jpg" : ext) }
        store.save(d); Haptic.success()
        await store.organize(d.id)
    }
}

struct DocRow: View {
    @Environment(Store.self) private var store
    var doc: BrainDoc
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: doc.kind == "pdf" ? "doc.richtext.fill" : doc.kind == "image" ? "photo.fill" : "note.text")
                .font(.title3).foregroundStyle(Color(hex: doc.folder.color))
                .frame(width: 44, height: 44).background(Color(hex: doc.folder.color).opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title).font(.body.weight(.semibold)).lineLimit(1)
                Text(doc.summary.isEmpty ? "\(doc.folder.label) · \(Day.shortLabel(Day.str(doc.created)))" : doc.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            if store.busy.contains("org-" + doc.id) { ProgressView() } else { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }
        }
        .padding(.vertical, 8).padding(.horizontal, 6)
        .contentShape(Rectangle())
    }
}

struct DocDetail: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let docId: String
    @State private var preview: URL? = nil
    @State private var askDelete = false

    var body: some View {
        if let d = store.s.docs.first(where: { $0.id == docId }) {
            List {
                Section {
                    TextField("Título", text: Binding(get: { d.title }, set: { var n = d; n.title = $0; store.save(n) })).font(.title3.weight(.bold))
                    Picker("Carpeta", selection: Binding(get: { d.folder }, set: { var n = d; n.folder = $0; store.save(n); Haptic.select() })) {
                        ForEach(BrainFolder.allCases) { Label($0.label, systemImage: $0.icon).tag($0) }
                    }
                    if let f = d.file {
                        Button { preview = Extract.url(f) } label: { Label(d.kind == "pdf" ? "Ver el PDF" : "Ver la imagen", systemImage: "eye") }
                    }
                }
                if !d.summary.isEmpty { Section("Resumen") { Text(d.summary) } }
                Section {
                    if store.busy.contains("org-" + d.id) { HStack { ProgressView(); Text("Claude lo está ordenando…").foregroundStyle(.secondary) } }
                    else { AIButton(title: "Ordenar con Claude", key: "org-" + d.id) { await store.organize(d.id) } }
                }
                .listRowBackground(Color.clear)
                Section(d.kind == "note" ? "Nota" : "Texto reconocido") {
                    TextEditor(text: Binding(get: { d.text }, set: { var n = d; n.text = $0; store.save(n) })).frame(minHeight: 220)
                }
                Section { Button("Eliminar documento", role: .destructive) { Haptic.warning(); askDelete = true } }
            }
            .navigationTitle(d.folder.label).navigationBarTitleDisplayMode(.inline)
            .quickLookPreview($preview)
            .confirmationDialog("¿Seguro que quieres eliminar este documento?", isPresented: $askDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) { store.delete(d); Haptic.heavy(); dismiss() }
            } message: { Text(d.title) }
        } else {
            ContentUnavailableView("Documento eliminado", systemImage: "trash")
        }
    }
}

struct NoteEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var text = ""
    @State private var folder: BrainFolder = .notas
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
                        if title.isEmpty { Task { await store.organize(d.id) } }
                    }.bold().disabled(text.isEmpty)
                }
            }
        }
    }
}
