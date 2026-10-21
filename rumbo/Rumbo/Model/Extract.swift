import SwiftUI
import PDFKit
import Vision
import VisionKit
import Compression
import UniformTypeIdentifiers

/// Saca el texto de PDFs y fotos (en el propio iPhone, sin internet)
enum Extract {
    static var filesDir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("files", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    static func url(_ name: String) -> URL { filesDir.appendingPathComponent(name) }

    static func store(_ data: Data, ext: String) -> String {
        let name = UUID().uuidString + "." + ext
        try? data.write(to: url(name), options: .atomic)
        return name
    }

    /// texto de un PDF; si es escaneado (sin texto), lo lee con OCR página a página
    static func pdfText(_ data: Data) async -> String {
        guard let doc = PDFDocument(data: data) else { return "" }
        var out = ""
        for i in 0..<doc.pageCount { out += (doc.page(at: i)?.string ?? "") + "\n" }
        if out.trimmingCharacters(in: .whitespacesAndNewlines).count > 40 { return out }
        var ocr = ""
        for i in 0..<min(doc.pageCount, 15) {
            guard let page = doc.page(at: i) else { continue }
            let box = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2
            let img = page.thumbnail(of: CGSize(width: box.width * scale, height: box.height * scale), for: .mediaBox)
            if let cg = img.cgImage { ocr += await text(in: cg) + "\n" }
        }
        return ocr
    }

    /// texto de una imagen con Vision (español e inglés)
    static func text(in image: CGImage) async -> String {
        await withCheckedContinuation { cont in
            let req = VNRecognizeTextRequest { r, _ in
                let lines = (r.results as? [VNRecognizedTextObservation])?.compactMap { $0.topCandidates(1).first?.string } ?? []
                cont.resume(returning: lines.joined(separator: "\n"))
            }
            req.recognitionLevel = .accurate
            req.recognitionLanguages = ["es-ES", "en-US"]
            req.usesLanguageCorrection = true
            do { try VNImageRequestHandler(cgImage: image).perform([req]) } catch { cont.resume(returning: "") }
        }
    }

    static func imageText(_ data: Data) async -> String {
        guard let ui = UIImage(data: data), let cg = ui.cgImage else { return "" }
        return await text(in: cg)
    }

    /// importe total de un ticket o factura (la línea con «total», o el número más alto con decimales)
    static func total(in text: String) -> Double? {
        let num = try! NSRegularExpression(pattern: "(\\d{1,3}(?:[.\\s]\\d{3})*|\\d+)[,.](\\d{2})(?!\\d)")
        func values(_ line: String) -> [Double] {
            num.matches(in: line, range: NSRange(line.startIndex..., in: line)).compactMap { m in
                guard let a = Range(m.range(at: 1), in: line), let b = Range(m.range(at: 2), in: line) else { return nil }
                return Double(line[a].filter(\.isNumber) + "." + line[b])
            }
        }
        let lines = text.components(separatedBy: .newlines)
        for (i, l) in lines.enumerated() {
            let low = l.lowercased()
            guard low.contains("total"), !low.contains("subtotal"), !low.contains("base") else { continue }
            if let v = values(l).last { return v }
            if i + 1 < lines.count, let v = values(lines[i + 1]).first { return v }
        }
        return lines.flatMap(values).max()
    }

    /// primera fecha dd/mm/aaaa (o dd-mm-aa) del texto, como yyyy-MM-dd
    static func date(in text: String) -> String? {
        let re = try! NSRegularExpression(pattern: "\\b(\\d{1,2})[/.-](\\d{1,2})[/.-](\\d{4}|\\d{2})\\b")
        for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let d = Range(m.range(at: 1), in: text).flatMap({ Int(text[$0]) }), let mo = Range(m.range(at: 2), in: text).flatMap({ Int(text[$0]) }),
                  var y = Range(m.range(at: 3), in: text).flatMap({ Int(text[$0]) }) else { continue }
            if y < 100 { y += 2000 }
            guard (1...31).contains(d), (1...12).contains(mo), (2000...2100).contains(y) else { continue }
            return String(format: "%04d-%02d-%02d", y, mo, d)
        }
        return nil
    }

    /// junta varias páginas escaneadas en un PDF
    static func pdf(from images: [UIImage]) -> Data {
        let doc = PDFDocument()
        for (i, img) in images.enumerated() { if let p = PDFPage(image: img) { doc.insert(p, at: i) } }
        return doc.dataRepresentation() ?? Data()
    }

    /// foto reducida para guardarla y mandarla (lado mayor 1600 px)
    static func jpeg(_ img: UIImage, maxSide: CGFloat = 1600) -> Data {
        let s = min(1, maxSide / max(img.size.width, img.size.height))
        let size = CGSize(width: img.size.width * s, height: img.size.height * s)
        return UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.8) { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

/// escáner de documentos de la cámara (el del sistema)
struct DocScanner: UIViewControllerRepresentable {
    var done: ([UIImage]) -> Void
    func makeCoordinator() -> Coord { Coord(done: done) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let v = VNDocumentCameraViewController(); v.delegate = context.coordinator; return v
    }
    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}
    final class Coord: NSObject, VNDocumentCameraViewControllerDelegate {
        let done: ([UIImage]) -> Void
        init(done: @escaping ([UIImage]) -> Void) { self.done = done }
        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            done((0..<scan.pageCount).map { scan.imageOfPage(at: $0) }); c.dismiss(animated: true)
        }
        func documentCameraViewControllerDidCancel(_ c: VNDocumentCameraViewController) { done([]); c.dismiss(animated: true) }
        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFailWithError error: Error) { done([]); c.dismiss(animated: true) }
    }
}

/// texto de un Word (.docx) u OpenDocument (.odt): son un zip con el texto en XML
enum OfficeText {
    static func read(_ data: Data) -> String {
        let b = [UInt8](data)
        func u16(_ i: Int) -> Int { i + 1 < b.count ? Int(b[i]) | Int(b[i + 1]) << 8 : 0 }
        func u32(_ i: Int) -> Int { u16(i) | u16(i + 2) << 16 }
        // fin del directorio del zip
        guard b.count > 22, let end = stride(from: b.count - 22, through: max(0, b.count - 65_557), by: -1).first(where: { u32($0) == 0x06054b50 }) else { return "" }
        var p = u32(end + 16)
        var out = ""
        for _ in 0..<u16(end + 10) {
            guard p + 46 <= b.count, u32(p) == 0x02014b50 else { break }
            let method = u16(p + 10), csize = u32(p + 20), usize = u32(p + 24)
            let nlen = u16(p + 28), elen = u16(p + 30), clen = u16(p + 32), local = u32(p + 42)
            let name = String(decoding: b[(p + 46)..<min(b.count, p + 46 + nlen)], as: UTF8.self)
            p += 46 + nlen + elen + clen
            guard name == "word/document.xml" || name == "content.xml" else { continue }
            let start = local + 30 + u16(local + 26) + u16(local + 28)
            guard start + csize <= b.count else { break }
            let raw = Data(b[start..<(start + csize)])
            let xml: Data
            if method == 0 { xml = raw }
            else if method == 8, let d = inflate(raw, size: usize) { xml = d }
            else { break }
            out = strip(String(decoding: xml, as: UTF8.self))
            break
        }
        return out
    }

    private static func inflate(_ src: Data, size: Int) -> Data? {
        guard size > 0, size < 200_000_000 else { return nil }
        var dst = Data(count: size)
        let n = dst.withUnsafeMutableBytes { d in
            src.withUnsafeBytes { s in
                compression_decode_buffer(d.bindMemory(to: UInt8.self).baseAddress!, size,
                                          s.bindMemory(to: UInt8.self).baseAddress!, src.count, nil, COMPRESSION_ZLIB)
            }
        }
        return n > 0 ? dst.prefix(n) : nil
    }

    private static func strip(_ xml: String) -> String {
        var s = xml
        for (a, b) in [("</w:p>", "\n"), ("</text:p>", "\n"), ("</text:h>", "\n"), ("<w:tab/>", "\t"), ("<w:br/>", "\n"), ("<text:line-break/>", "\n")] {
            s = s.replacingOccurrences(of: a, with: b)
        }
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (a, b) in [("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&apos;", "'"), ("&amp;", "&")] {
            s = s.replacingOccurrences(of: a, with: b)
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// selector de archivos de iOS que copia el archivo dentro de la app (funciona con iCloud, Drive, etc.)
struct DocPicker: UIViewControllerRepresentable {
    var onPick: ([(name: String, ext: String, data: Data)]?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .image, .plainText, .text, .rtf, .rtfd, .item]
            + ["docx", "doc", "odt", "pages"].compactMap { UTType(filenameExtension: $0) }
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        vc.allowsMultipleSelection = true
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([(name: String, ext: String, data: Data)]?) -> Void
        init(onPick: @escaping ([(name: String, ext: String, data: Data)]?) -> Void) { self.onPick = onPick }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { onPick(nil) }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // se lee ya, antes de que iOS borre la copia temporal
            let files = urls.compactMap { u -> (name: String, ext: String, data: Data)? in
                let ok = u.startAccessingSecurityScopedResource()
                defer { if ok { u.stopAccessingSecurityScopedResource() } }
                guard let d = try? Data(contentsOf: u) else { return nil }
                return (u.deletingPathExtension().lastPathComponent, u.pathExtension.lowercased(), d)
            }
            onPick(files)
        }
    }
}
