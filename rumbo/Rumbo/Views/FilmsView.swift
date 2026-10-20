import SwiftUI

private let lbGreen = Color(hex: "#00e054")
private let lbOrange = Color(hex: "#ff8000")
private let lbBlue = Color(hex: "#40bcf4")

/// estrellas de 0 a 5 (con medias)
struct Stars: View {
    var value: Double
    var size: CGFloat = 12
    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { n in
                let v = value - Double(n - 1)
                if v >= 1 { Image(systemName: "star.fill") }
                else if v >= 0.5 { Image(systemName: "star.leadinghalf.filled") }
            }
        }
        .font(.system(size: size, weight: .bold))
        .foregroundStyle(lbGreen)
    }
}

/// puntuar arrastrando o tocando (medias estrellas)
struct StarPicker: View {
    @Binding var value: Double
    var size: CGFloat = 34
    var body: some View {
        GeometryReader { g in
            HStack(spacing: 0) {
                ForEach(1...5, id: \.self) { n in
                    let v = value - Double(n - 1)
                    Image(systemName: v >= 1 ? "star.fill" : v >= 0.5 ? "star.leadinghalf.filled" : "star")
                        .font(.system(size: size, weight: .semibold))
                        .foregroundStyle(v > 0 ? lbGreen : Color.secondary.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .symbolEffect(.bounce, value: value >= Double(n))
                }
            }
            .frame(height: g.size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { d in
                let x = min(max(d.location.x, 0), g.size.width)
                let nv = max(0.5, (x / g.size.width * 10).rounded(.up) / 2)
                if nv != value { value = nv; Haptic.select() }
            })
        }
        .frame(height: size + 8)
    }
}

/// póster: el guardado, el de internet o uno dibujado con el título
struct Poster: View {
    var film: Film
    var width: CGFloat? = nil
    var body: some View {
        ZStack {
            if let p = film.poster, let ui = UIImage(contentsOfFile: Extract.url(p).path) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else if let u = URL(string: film.posterURL), !film.posterURL.isEmpty {
                AsyncImage(url: u) { img in img.resizable().scaledToFill() } placeholder: { fallback }
            } else { fallback }
        }
        .frame(width: width, height: width.map { $0 * 1.5 })
        .frame(maxWidth: width == nil ? .infinity : nil)
        .aspectRatio(2/3, contentMode: .fit)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.4), radius: 5, y: 3)
    }
    private var fallback: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Color(hex: "#2c3440"), Color(hex: "#14181c")], startPoint: .top, endPoint: .bottom)
            Text(film.title).font(.system(size: (width ?? 80) < 50 ? 7 : 12, weight: .heavy)).foregroundStyle(.white.opacity(0.9)).lineLimit(4).padding((width ?? 80) < 50 ? 3 : 8)
        }
    }
}

/// la parte de Pelis y series de la biblioteca
struct CineSection: View {
    @Environment(Store.self) private var store
    @State private var kind: FilmKind? = nil
    @State private var status: FilmStatus? = nil

    var body: some View {
        VStack(spacing: 18) {
            stats.appear(0)
            ask.appear(0.05)
            diary.appear(0.08)
            watchlist.appear(0.1)
            filters.appear(0.12)
            grid.appear(0.15)
        }
    }

    private var stats: some View {
        let year = String(Day.today.prefix(4))
        let views = store.s.films.flatMap { f in f.watched.filter { $0.hasPrefix(year) }.map { _ in f } }
        let hours = views.reduce(0) { $0 + $1.runtime } / 60
        return HStack(spacing: 12) {
            stat("\(views.filter { $0.kind == .pelicula }.count)", "pelis este año", "film.fill", lbOrange)
            stat("\(views.filter { $0.kind == .serie }.count)", "series este año", "tv.fill", lbBlue)
            stat(hours > 0 ? "\(hours) h" : "\(store.s.films.filter(\.liked).count)", hours > 0 ? "de pantalla" : "favoritas", hours > 0 ? "clock.fill" : "heart.fill", lbGreen)
        }
    }
    private func stat(_ v: String, _ l: String, _ icon: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).foregroundStyle(c)
            Text(v).font(.system(size: 24, weight: .bold, design: .rounded))
            Text(l).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).card(14)
    }

    private var ask: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardTitle(title: "¿Qué veo?", icon: "sparkles", color: lbGreen)
            AskBox(placeholder: "Recomiéndame una peli para esta noche",
                   suggestions: ["Recomiéndame una peli para esta noche", "Una serie corta que me vaya a gustar", "¿Cuáles son mis favoritas?"],
                   busyKey: "films", answers: store.s.filmQA) { q in await store.askFilms(q) }
        }
        .card()
    }

    @ViewBuilder private var diary: some View {
        let entries = store.s.films.flatMap { f in f.watched.map { (f, $0) } }.sorted { $0.1 > $1.1 }.prefix(6)
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                CardTitle(title: "Diario", icon: "book.pages.fill", color: lbOrange)
                ForEach(Array(entries.enumerated()), id: \.offset) { _, e in
                    NavigationLink(value: e.0) {
                        HStack(spacing: 12) {
                            VStack(spacing: 0) {
                                Text(Day.month(e.1).prefix(3).uppercased()).font(.system(size: 9, weight: .heavy)).foregroundStyle(.secondary)
                                Text("\(Day.cal.component(.day, from: Day.date(e.1)))").font(.system(size: 20, weight: .bold, design: .rounded))
                            }
                            .frame(width: 36)
                            Poster(film: e.0, width: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 4) {
                                    Text(e.0.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                                    if !e.0.year.isEmpty { Text(e.0.year).font(.caption).foregroundStyle(.secondary) }
                                }
                                HStack(spacing: 6) {
                                    Stars(value: e.0.rating, size: 10)
                                    if e.0.liked { Image(systemName: "heart.fill").font(.caption2).foregroundStyle(lbOrange) }
                                    if e.0.watched.count > 1 { Image(systemName: "arrow.triangle.2.circlepath").font(.caption2).foregroundStyle(.secondary) }
                                }
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .card()
        }
    }

    @ViewBuilder private var watchlist: some View {
        let list = store.s.films.filter { $0.status == .quiero }
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                CardTitle(title: "Quiero verlas", icon: "clock.fill", color: lbBlue)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(list) { f in NavigationLink(value: f) { Poster(film: f, width: 86) }.buttonStyle(PressableStyle()) }
                    }
                    .padding(.vertical, 4)
                }
            }
            .card()
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip("Todo", kind == nil && status == nil) { kind = nil; status = nil }
                chip("Pelis", kind == .pelicula) { kind = kind == .pelicula ? nil : .pelicula }
                chip("Series", kind == .serie) { kind = kind == .serie ? nil : .serie }
                chip("Vistas", status == .vista) { status = status == .vista ? nil : .vista }
                chip("Viendo", status == .viendo) { status = status == .viendo ? nil : .viendo }
            }
        }
    }
    private func chip(_ t: String, _ on: Bool, _ a: @escaping () -> Void) -> some View {
        Button { Haptic.select(); withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { a() } } label: {
            Text(t).font(.subheadline.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(on ? Color.black : Color.primary)
                .background(on ? lbGreen : Color.cardBG, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    @ViewBuilder private var grid: some View {
        let list = store.s.films.filter { (kind == nil || $0.kind == kind) && (status == nil || $0.status == status) }
            .sorted { ($0.lastWatched.isEmpty ? Day.str($0.created) : $0.lastWatched) > ($1.lastWatched.isEmpty ? Day.str($1.created) : $1.lastWatched) }
        if store.s.films.isEmpty {
            EmptyCard(icon: "film.stack", title: "Sin pelis ni series", text: "")
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 14) {
                ForEach(list) { f in
                    NavigationLink(value: f) {
                        VStack(spacing: 4) {
                            Poster(film: f)
                            HStack(spacing: 3) {
                                Stars(value: f.rating, size: 8)
                                if f.liked { Image(systemName: "heart.fill").font(.system(size: 8)).foregroundStyle(lbOrange) }
                            }
                            .frame(height: 10)
                        }
                    }
                    .buttonStyle(PressableStyle())
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}

/// buscar una peli o serie para añadirla
struct FilmSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var query = ""
    @State private var kind: FilmKind = .pelicula
    @State private var results: [FilmSearch.Result] = []
    @State private var loading = false
    @State private var picked: Film? = nil
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("", selection: $kind) { ForEach(FilmKind.allCases) { Text($0 == .pelicula ? "Películas" : "Series").tag($0) } }
                        .pickerStyle(.segmented)
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(kind == .pelicula ? "Título de la película" : "Título de la serie", text: $query)
                            .focused($focused).submitLabel(.search).autocorrectionDisabled()
                        if loading { ProgressView() }
                    }
                }
                Section {
                    ForEach(results) { r in
                        Button { picked = r.film } label: {
                            HStack(spacing: 12) {
                                Poster(film: r.film, width: 46)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(r.film.title).font(.body.weight(.semibold)).lineLimit(2)
                                    Text([r.film.year, r.film.kind == .pelicula ? r.film.director : [r.film.season, r.film.director].filter { !$0.isEmpty }.joined(separator: " · ")].filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(lbGreen)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    if !query.isEmpty && results.isEmpty && !loading { Text("Sin resultados").foregroundStyle(.secondary) }
                    Button { picked = Film(kind: kind, title: query) } label: { Label("Añadir «\(query.isEmpty ? "…" : query)» a mano", systemImage: "square.and.pencil") }
                        .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Añadir").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } } }
            .task(id: query + kind.rawValue) {
                let q = query.trimmingCharacters(in: .whitespaces)
                guard q.count >= 2 else { results = []; return }
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                loading = true
                let r = await FilmSearch.search(q, kind: kind)
                guard !Task.isCancelled else { return }
                withAnimation { results = r }
                loading = false
            }
            .onAppear { if query.isEmpty { focused = true } }
            .sheet(item: $picked) { f in FilmEditor(original: f, isNew: true) { dismiss() } }
        }
    }
}

/// puntuar y apuntar cuándo la has visto
struct FilmEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: Film
    var isNew = false
    var onSaved: () -> Void = {}
    @State private var f = Film(title: "")
    @State private var day = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 14) {
                        Poster(film: f, width: 90)
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Título", text: $f.title, axis: .vertical).font(.title3.weight(.bold))
                            Text([f.year, f.kind == .pelicula ? f.director : f.season].filter { !$0.isEmpty }.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
                            if !f.genre.isEmpty { Text(f.genre).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
                Section {
                    Picker("", selection: $f.status.animation()) { ForEach(FilmStatus.allCases) { Text($0.label(f.kind)).tag($0) } }.pickerStyle(.segmented)
                    if f.status == .vista && isNew { DatePicker("La vi el", selection: $day, in: ...Date(), displayedComponents: .date) }
                }
                if f.status != .quiero {
                    Section("Tu nota") {
                        StarPicker(value: $f.rating).padding(.vertical, 4)
                        Toggle(isOn: $f.liked) { Label("Me ha encantado", systemImage: f.liked ? "heart.fill" : "heart").foregroundStyle(f.liked ? lbOrange : .primary) }
                            .tint(lbOrange)
                    }
                    Section("Reseña") { TextEditor(text: $f.review).frame(minHeight: 120) }
                }
            }
            .navigationTitle(isNew ? "Añadir \(f.kind.label.lowercased())" : "Editar").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        var n = f
                        if isNew && n.status == .vista { n.watched = [Day.str(day)] }
                        if !isNew && n.status == .vista && n.watched.isEmpty { n.watched = [Day.today] }
                        Haptic.success(); dismiss(); onSaved()
                        Task { await store.add(n) }
                    }.bold().disabled(f.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { f = original }
        }
    }
}

struct FilmDetail: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let filmId: String
    @State private var editing = false
    @State private var askDelete = false
    @State private var removeDay: String? = nil

    var body: some View {
        if let f = store.s.films.first(where: { $0.id == filmId }) {
            let set: (Film) -> Void = { store.save($0) }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .bottom, spacing: 16) {
                        Poster(film: f, width: 120)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(f.kind.label.uppercased()).font(.caption.weight(.heavy)).foregroundStyle(f.kind == .pelicula ? lbOrange : lbBlue)
                            Text(f.title).font(.title2.weight(.bold))
                            Text([f.year, f.kind == .pelicula ? f.director : f.season].filter { !$0.isEmpty }.joined(separator: " · ")).foregroundStyle(.secondary)
                            Text([f.genre, f.runtime > 0 ? "\(f.runtime) min" : ""].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Picker("", selection: Binding(get: { f.status }, set: { v in var n = f; n.status = v; if v == .vista && n.watched.isEmpty { n.watched = [Day.today] }; set(n); Haptic.select() })) {
                        ForEach(FilmStatus.allCases) { Text($0.label(f.kind)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    VStack(spacing: 12) {
                        StarPicker(value: Binding(get: { f.rating }, set: { var n = f; n.rating = $0; set(n) }))
                        HStack {
                            Button { Haptic.tap(); var n = f; n.liked.toggle(); set(n) } label: {
                                Label("Me encanta", systemImage: f.liked ? "heart.fill" : "heart").font(.subheadline.weight(.semibold))
                                    .foregroundStyle(f.liked ? lbOrange : .secondary)
                                    .symbolEffect(.bounce, value: f.liked)
                            }
                            Spacer()
                            Button { Haptic.success(); var n = f; n.watched.append(Day.today); n.status = .vista; set(n) } label: {
                                Label(f.watched.isEmpty ? "La he visto hoy" : "La he vuelto a ver", systemImage: "arrow.triangle.2.circlepath").font(.subheadline.weight(.semibold))
                            }
                            .tint(lbGreen)
                        }
                    }
                    .card()
                    if !f.watched.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            CardTitle(title: f.watched.count > 1 ? "Vista \(f.watched.count) veces" : "Vista", icon: "eye.fill", color: lbGreen)
                            ForEach(f.watched.sorted(by: >), id: \.self) { d in
                                HStack {
                                    Text(Day.header(d)).font(.subheadline)
                                    Spacer()
                                    Button { removeDay = d } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                                }
                            }
                        }
                        .card()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        CardTitle(title: "Reseña", icon: "text.quote", color: lbBlue)
                        TextEditor(text: Binding(get: { f.review }, set: { var n = f; n.review = $0; set(n) }))
                            .frame(minHeight: 120).scrollContentBackground(.hidden)
                            .padding(8).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .card()
                    if !f.synopsis.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            CardTitle(title: "Sinopsis", icon: "film", color: .secondary)
                            Text(f.synopsis).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .card()
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background {
                ZStack {
                    Color(.systemGroupedBackground)
                    Poster(film: f).scaleEffect(1.6).blur(radius: 50).opacity(0.35).frame(maxHeight: .infinity, alignment: .top).allowsHitTesting(false)
                }
                .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { editing = true } label: { Label("Editar", systemImage: "pencil") }
                        Button(role: .destructive) { Haptic.warning(); askDelete = true } label: { Label("Eliminar", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $editing) { FilmEditor(original: f) }
            .confirmationDialog("¿Seguro que quieres eliminar «\(f.title)»?", isPresented: $askDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) { store.delete(f); Haptic.heavy(); dismiss() }
            } message: { Text("Se borrarán tu nota, tu reseña y tu diario.") }
            .confirmationDialog("¿Quitar este visionado?", isPresented: Binding(get: { removeDay != nil }, set: { if !$0 { removeDay = nil } }), titleVisibility: .visible) {
                Button("Quitar", role: .destructive) { if let d = removeDay, let i = f.watched.firstIndex(of: d) { var n = f; n.watched.remove(at: i); set(n) }; removeDay = nil }
            } message: { Text(removeDay.map { Day.header($0) } ?? "") }
        } else {
            ContentUnavailableView("Eliminada", systemImage: "trash")
        }
    }
}
