import SwiftUI

/// tu cuenta: entrar, crear cuenta, recuperar o cambiar la contraseña y salir
struct CuentaView: View {
    @Environment(Tienda.self) private var t
    @Environment(\.dismiss) private var cerrar
    @State private var nueva = ""
    @State private var cambiando = false
    @State private var salir = false
    @AppStorage("tema") private var tema = "auto"

    private var aspecto: some View {
        Picker("Aspecto", selection: $tema) {
            Label("Como el móvil", systemImage: "circle.lefthalf.filled").tag("auto")
            Label("Claro", systemImage: "sun.max").tag("claro")
            Label("Oscuro", systemImage: "moon").tag("oscuro")
        }
        .pickerStyle(.segmented)
        .labelStyle(.titleOnly)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let s = t.sesion {
                    Form {
                        Section {
                            HStack(spacing: 14) {
                                Avatar(nombre: s.nombre, size: 54)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.nombre).font(.title3.weight(.bold))
                                    Text(s.email).font(.subheadline).foregroundStyle(.secondary)
                                    if t.admin { Etiqueta(texto: "Taller", color: .hot, icono: "wrench.and.screwdriver.fill").padding(.top, 4) }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        Section("Cambiar contraseña") {
                            CampoClave(titulo: "Contraseña nueva", texto: $nueva, nueva: true)
                            Button {
                                Task {
                                    cambiando = true
                                    defer { cambiando = false }
                                    guard let tk = await t.token() else { return }
                                    do { try await Supa.cambiarClave(nueva, token: tk); nueva = ""; t.avisar("Contraseña cambiada") }
                                    catch { t.avisar(error.localizedDescription, error: true) }
                                }
                            } label: { if cambiando { ProgressView() } else { Text("Guardar contraseña") } }
                            .disabled(nueva.count < 6 || cambiando)
                        }
                        Section("Aspecto") { aspecto }
                        Section {
                            Button("Salir de la cuenta", role: .destructive) { salir = true }
                                .confirmationDialog("¿Salir de la cuenta?", isPresented: $salir, titleVisibility: .visible) {
                                    Button("Salir", role: .destructive) { Task { await t.salir(); cerrar() } }
                                }
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            FormCuenta(entrarPrimero: true, alEntrar: { cerrar() })
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ASPECTO").font(.caption.weight(.bold)).foregroundStyle(.secondary).tracking(0.6)
                                aspecto
                            }
                        }
                        .padding(16)
                    }
                        .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle(t.sesion == nil ? "Entrar" : "Tu cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { cerrar() } } }
        }
    }
}

/// entrar / crear cuenta / he olvidado la contraseña
struct FormCuenta: View {
    @Environment(Tienda.self) private var t
    enum Modo { case entrar, crear, olvido }
    @State private var modo: Modo
    @State private var nombre = ""
    @State private var email = ""
    @State private var clave = ""
    @State private var ocupado = false
    @State private var fallo: String? = nil
    @State private var mensaje: String? = nil
    var alEntrar: (() -> Void)? = nil

    init(entrarPrimero: Bool, alEntrar: (() -> Void)? = nil) {
        _modo = State(initialValue: entrarPrimero ? .entrar : .crear)
        self.alEntrar = alEntrar
    }

    private var valido: Bool {
        let e = email.contains("@") && email.contains(".")
        switch modo {
        case .entrar: return e && clave.count >= 6
        case .crear: return e && clave.count >= 6 && !nombre.trimmingCharacters(in: .whitespaces).isEmpty
        case .olvido: return e
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                Image(systemName: modo == .olvido ? "key.fill" : "person.crop.circle.fill")
                    .font(.system(size: 48)).foregroundStyle(Color.hot.gradient)
                    .contentTransition(.symbolEffect(.replace))
                Text(modo == .entrar ? "Entra para pedir" : modo == .crear ? "Crea tu cuenta" : "Recuperar contraseña")
                    .font(.title2.weight(.bold))
            }
            .padding(.top, 8)

            if modo != .olvido {
                Picker("", selection: $modo.animation(.snappy)) {
                    Text("Entrar").tag(Modo.entrar)
                    Text("Crear cuenta").tag(Modo.crear)
                }
                .pickerStyle(.segmented)
            }

            VStack(spacing: 0) {
                if modo == .crear {
                    TextField("Tu nombre", text: $nombre).textContentType(.name).padding(14)
                    Divider().padding(.leading, 14)
                }
                TextField("Correo", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().padding(14)
                if modo != .olvido {
                    Divider().padding(.leading, 14)
                    CampoClave(titulo: "Contraseña", texto: $clave, nueva: modo == .crear).padding(.leading, 14).padding(.trailing, 8).padding(.vertical, 7)
                }
            }
            .tarjeta()

            if let fallo { Label(fallo, systemImage: "exclamationmark.circle.fill").font(.subheadline.weight(.semibold)).foregroundStyle(.red).transition(.opacity) }
            if let mensaje { Label(mensaje, systemImage: "envelope.fill").font(.subheadline.weight(.semibold)).foregroundStyle(.green).multilineTextAlignment(.center).transition(.opacity) }

            Button { Task { await enviar() } } label: {
                Group {
                    if ocupado { ProgressView().tint(.white) }
                    else { Text(modo == .entrar ? "Entrar" : modo == .crear ? "Crear cuenta" : "Enviar correo") }
                }
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(valido ? AnyShapeStyle(Color.hot.gradient) : AnyShapeStyle(Color.gray.opacity(0.35)), in: Capsule())
                .foregroundStyle(.white)
            }
            .buttonStyle(Encoger())
            .disabled(!valido || ocupado)

            Button(modo == .olvido ? "Volver" : "He olvidado la contraseña") {
                withAnimation(.snappy) { modo = modo == .olvido ? .entrar : .olvido; fallo = nil; mensaje = nil }
            }
            .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: modo)
        .animation(.snappy, value: fallo)
        .onChange(of: modo) { _, _ in fallo = nil }
    }

    private func enviar() async {
        ocupado = true
        defer { ocupado = false }
        withAnimation { fallo = nil; mensaje = nil }
        do {
            switch modo {
            case .entrar:
                try await t.entrar(email: email, clave: clave)
                await t.cargar()
                alEntrar?()
            case .crear:
                if try await t.registrar(nombre: nombre, email: email, clave: clave) { alEntrar?() }
                else { withAnimation { mensaje = "Te hemos mandado un correo. Ábrelo para confirmar la cuenta y luego entra aquí."; modo = .entrar } }
            case .olvido:
                try await Supa.recuperar(email: email.trimmingCharacters(in: .whitespaces).lowercased())
                withAnimation { mensaje = "Te hemos mandado un correo para poner una contraseña nueva." }
            }
        } catch {
            withAnimation { fallo = error.localizedDescription }
        }
    }
}
