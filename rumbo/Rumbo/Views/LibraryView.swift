import SwiftUI

/// 5. Biblioteca de vida: lo que lees, escuchas y ves, con sus ideas clave, y preguntas a toda tu biblioteca
struct LibraryView: View {
    @Environment(Store.self) private var store
    @State private var status: ItemStatus? = nil
    @State private var adding = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    shelf.appear(0)
                    ask.appear(0.05)
                    filters.appear(0.1)
                    items.appear(0.15)
                    Color.clear.frame(height: 30)
                }
                .padding(.horizontal, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Mi biblioteca de vida")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button { adding = true } label: { Image(systemName: "plus.circle.fill").font(.title3) } }
                ToolbarItem(placement: .topBarTrailing) { SettingsButton() }
            }
            .navigationDestination(for: LibItem.self) { LibDetail(itemId: $0.id) }
            .sheet(isPresented: $adding) { LibEditor(original: nil) }
        }
    }

    private var shelf: some View {
        let done = store.s.library.filter { $0.status == .terminado }.count
        let reading = store.s.library.filter { $0.status == .enCurso }
        let year = String(Day.today.prefix(4))
        let thisYear = store.s.library.filter { $0.status == .terminado && $0.finished.hasPrefix(year) }.count
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                stat("\(done)", "terminados", "checkmark.seal.fill", .income)
                stat("\(thisYear)", "este año", "calendar", Color(hex: "#f0c46a"))
                stat("\(store.s.library.reduce(0) { $0 + $1.ideas.count })", "ideas", "lightbulb.fill", Color(hex: "#b39cff"))
            }
            if !reading.isEmpty {
                Text("Ahora mismo").font(.subheadline.weight(.bold)).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(reading) { it in
                            NavigationLink(value: it) { Cover(item: it, width: 96) }.buttonStyle(PressableStyle())
                        }
                    }
                }
            }
        }
        .card()
    }
    private func stat(_ v: String, _ l: String, _ icon: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).foregroundStyle(c)
            Text(v).font(.system(size: 24, weight: .bold, design: .rounded))
            Text(l).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ask: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardTitle(title: "Pregúntale a tu biblioteca", icon: "sparkles")
            AskBox(placeholder: "¿Cuáles son las ideas clave sobre productividad?",
                   suggestions: ["¿Cuáles son las ideas clave sobre productividad?", "¿Qué he aprendido sobre hábitos?", "Recomiéndame qué leer después"],
                   busyKey: "library", answers: store.s.libraryQA) { q in await store.askLibrary(q) }
        }
        .card()
    }

    private var filters: some View {
        HStack(spacing: 6) {
            chip("Todo", nil)
            ForEach(ItemStatus.allCases) { chip($0.label, $0) }
        }
    }
    private func chip(_ t: String, _ s: ItemStatus?) -> some View {
        Button { Haptic.select(); withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { status = s } } label: {
            Text(t).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 9)
                .foregroundStyle(status == s ? Color.black : Color.primary)
                .background(status == s ? Color.accentColor : Color.cardBG, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    @ViewBuilder private var items: some View {
        let list = store.s.library.filter { status == nil || $0.status == status }
        if store.s.library.isEmpty {
            EmptyCard(icon: "books.vertical.fill", title: "Tu biblioteca está vacía", text: "Cada libro, artículo o podcast que consumes queda aquí con tus notas y sus ideas clave. Luego puedes preguntarle a toda tu biblioteca.")
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                ForEach(list) { it in
                    NavigationLink(value: it) {
                        VStack(alignment: .leading, spacing: 6) {
                            Cover(item: it, width: nil)
                            Text(it.title).font(.caption.weight(.semibold)).lineLimit(2).foregroundStyle(.primary)
                            if it.rating > 0 { Text(String(repeating: "★", count: it.rating)).font(.caption2).foregroundStyle(Color(hex: "#f0c46a")) }
                        }
                    }
                    .buttonStyle(PressableStyle())
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}

/// portada dibujada con el color del libro
struct Cover: View {
    var item: LibItem
    var width: CGFloat?
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Color(hex: item.color), Color(hex: item.color).opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Rectangle().fill(.black.opacity(0.18)).frame(width: 6).frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: item.kind.icon).font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.85))
                Spacer(minLength: 0)
                Text(item.title).font(.system(size: 13, weight: .heavy, design: .serif)).foregroundStyle(.white).lineLimit(4)
                if !item.author.isEmpty { Text(item.author).font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.8)).lineLimit(1) }
            }
            .padding(10).padding(.leading, 4)
        }
        .frame(width: width)
        .aspectRatio(0.68, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
    }
}

struct LibDetail: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let itemId: String
    @State private var editing = false
    @State private var askDelete = false

    var body: some View {
        if let it = store.s.library.first(where: { $0.id == itemId }) {
            ScrollView {
                VStack(spacing: 18) {
                    HStack(alignment: .bottom, spacing: 16) {
                        Cover(item: it, width: 120)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(it.kind.label.uppercased()).font(.caption.weight(.heavy)).foregroundStyle(Color(hex: it.color))
                            Text(it.title).font(.title2.weight(.bold))
                            if !it.author.isEmpty { Text(it.author).foregroundStyle(.secondary) }
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { n in
                                    Image(systemName: n <= it.rating ? "star.fill" : "star").foregroundStyle(Color(hex: "#f0c46a"))
                                        .onTapGesture { Haptic.select(); var x = it; x.rating = n; withAnimation(.spring) { store.save(x) } }
                                }
                            }
                        }
                        Spacer()
                    }
                    Picker("Estado", selection: Binding(get: { it.status }, set: { v in var x = it; x.status = v; if v == .terminado && x.finished.isEmpty { x.finished = Day.today }; store.save(x); Haptic.select() })) {
                        ForEach(ItemStatus.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            CardTitle(title: "Ideas clave", icon: "lightbulb.fill", color: Color(hex: "#f0c46a"))
                            AIButton(title: it.ideas.isEmpty ? "Sacar ideas" : "Rehacer", key: "ideas-" + it.id) { await store.extractIdeas(it.id) }
                        }
                        if it.ideas.isEmpty { Text("Escribe tus notas abajo y Claude sacará las ideas clave (o las de la obra si aún no tienes notas).").font(.subheadline).foregroundStyle(.secondary) }
                        else { Bullets(items: it.ideas, color: Color(hex: "#f0c46a"), icon: "lightbulb.fill") }
                    }
                    .card()
                    VStack(alignment: .leading, spacing: 8) {
                        CardTitle(title: "Mis notas y subrayados", icon: "highlighter", color: Color(hex: "#7ac8ff"))
                        TextEditor(text: Binding(get: { it.notes }, set: { var x = it; x.notes = $0; store.save(x) }))
                            .frame(minHeight: 200).scrollContentBackground(.hidden)
                            .padding(8).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .card()
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { editing = true } label: { Label("Editar", systemImage: "pencil") }
                        Button(role: .destructive) { Haptic.warning(); askDelete = true } label: { Label("Eliminar", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $editing) { LibEditor(original: it) }
            .confirmationDialog("¿Seguro que quieres eliminar «\(it.title)»?", isPresented: $askDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) { store.delete(it); Haptic.heavy(); dismiss() }
            } message: { Text("Se borrarán también tus notas e ideas.") }
        } else {
            ContentUnavailableView("Eliminado", systemImage: "trash")
        }
    }
}

struct LibEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: LibItem?
    @State private var it = LibItem(title: "")
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $it.kind) { ForEach(ItemKind.allCases) { Label($0.label, systemImage: $0.icon).tag($0) } }
                    TextField("Título", text: $it.title)
                    TextField(it.kind == .libro ? "Autor" : "Autor o fuente", text: $it.author)
                    Picker("Estado", selection: $it.status) { ForEach(ItemStatus.allCases) { Text($0.label).tag($0) } }
                }
                Section("Color de la portada") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(palette, id: \.self) { c in
                                Circle().fill(Color(hex: c)).frame(width: 30, height: 30)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: it.color == c ? 3 : 0))
                                    .onTapGesture { Haptic.select(); withAnimation(.spring) { it.color = c } }
                            }
                        }
                        .padding(3)
                    }
                }
                Section("Notas") { TextEditor(text: $it.notes).frame(minHeight: 140) }
            }
            .navigationTitle(original == nil ? "Añadir a la biblioteca" : "Editar").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        var n = it
                        if n.status == .terminado && n.finished.isEmpty { n.finished = Day.today }
                        store.save(n); Haptic.success(); dismiss()
                        if original == nil && Claude.hasKey { Task { await store.extractIdeas(n.id) } }
                    }.bold().disabled(it.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { if let original { it = original } else { it.color = palette.randomElement() ?? "#b39cff" } }
        }
    }
}
