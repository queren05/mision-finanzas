package es.david.caudal.data.export

import es.david.caudal.core.Money
import es.david.caudal.domain.model.FinanceData
import es.david.caudal.domain.model.TxType
import java.io.ByteArrayOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** una fila de movimiento para exportar */
data class ExportRow(
    val date: String,
    val time: String,
    val type: String,
    /** con signo: negativo los gastos */
    val amount: Double,
    val account: String,
    val category: String,
    val concept: String,
    val note: String,
    val tags: String,
)

/** Exportar movimientos a CSV y a Excel (.xlsx escrito a mano, sin librerías) */
object Exports {
    /** nombres de columnas y de tipos (vienen traducidos de strings) */
    data class Labels(
        val headers: List<String>,
        val expense: String,
        val income: String,
        val transfer: String,
        val adjust: String,
    )

    fun rows(d: FinanceData, l: Labels): List<ExportRow> {
        val acc = d.accounts.associateBy { it.id }
        val cat = d.categories.associateBy { it.id }
        return d.txs.sortedWith(compareByDescending<es.david.caudal.domain.model.Tx> { it.date }.thenByDescending { it.time }).map { t ->
            val a = Money.fromCents(t.amount)
            ExportRow(
                date = t.date, time = t.time,
                type = when (t.type) { TxType.EXPENSE -> l.expense; TxType.INCOME -> l.income; TxType.TRANSFER -> l.transfer; TxType.ADJUST -> l.adjust },
                amount = when (t.type) { TxType.EXPENSE -> -a; TxType.TRANSFER -> -a; else -> a },
                account = acc[t.accountId]?.name.orEmpty() + (t.toAccountId?.let { " → " + acc[it]?.name.orEmpty() } ?: ""),
                category = cat[t.categoryId]?.name.orEmpty(),
                concept = t.title, note = t.note, tags = t.tags.joinToString(" ") { "#$it" },
            )
        }
    }

    /** CSV con punto y coma (lo que abre bien Excel en español) y BOM UTF-8; importes con coma decimal */
    fun csv(rows: List<ExportRow>, headers: List<String>): ByteArray {
        val sb = StringBuilder("﻿")
        fun cell(v: String) = if (v.any { it == ';' || it == '"' || it == '\n' || it == '\r' }) "\"" + v.replace("\"", "\"\"") + "\"" else v
        sb.append(headers.joinToString(";") { cell(it) }).append("\r\n")
        for (r in rows) {
            sb.append(listOf(r.date, r.time, r.type, "%.2f".format(java.util.Locale.ROOT, r.amount).replace('.', ','), r.account, r.category, r.concept, r.note, r.tags)
                .joinToString(";") { cell(it) }).append("\r\n")
        }
        return sb.toString().toByteArray(Charsets.UTF_8)
    }

    private fun xml(v: String) = v.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")
        .filter { it == '\t' || it == '\n' || it == '\r' || it >= ' ' }

    private fun col(i: Int): String { var n = i + 1; val sb = StringBuilder(); while (n > 0) { val m = (n - 1) % 26; sb.insert(0, ('A' + m)); n = (n - 1) / 26 }; return sb.toString() }

    /** libro de Excel mínimo: una hoja «Movimientos», cabecera en negrita, importes como número con 2 decimales */
    fun xlsx(rows: List<ExportRow>, headers: List<String>, sheetName: String = "Movimientos"): ByteArray {
        val out = ByteArrayOutputStream()
        ZipOutputStream(out).use { z ->
            fun put(name: String, body: String) { z.putNextEntry(ZipEntry(name)); z.write(body.toByteArray(Charsets.UTF_8)); z.closeEntry() }
            put("[Content_Types].xml", """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>""")
            put("_rels/.rels", """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>""")
            put("xl/_rels/workbook.xml.rels", """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>""")
            put("xl/workbook.xml", """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="${xml(sheetName.take(31))}" sheetId="1" r:id="rId1"/></sheets></workbook>""")
            // estilos: 0 normal, 1 negrita (cabecera), 2 número con 2 decimales
            put("xl/styles.xml", """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="1"><numFmt numFmtId="164" formatCode="#,##0.00"/></numFmts><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/><xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs></styleSheet>""")
            val sb = StringBuilder("""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><cols><col min="1" max="1" width="12" customWidth="1"/><col min="4" max="4" width="12" customWidth="1"/><col min="5" max="9" width="22" customWidth="1"/></cols><sheetData>""")
            fun str(ref: String, v: String, style: Int = 0) = "<c r=\"$ref\" t=\"inlineStr\"${if (style > 0) " s=\"$style\"" else ""}><is><t xml:space=\"preserve\">${xml(v)}</t></is></c>"
            sb.append("<row r=\"1\">")
            headers.forEachIndexed { i, h -> sb.append(str("${col(i)}1", h, 1)) }
            sb.append("</row>")
            rows.forEachIndexed { k, r ->
                val n = k + 2
                sb.append("<row r=\"$n\">")
                listOf(r.date, r.time, r.type).forEachIndexed { i, v -> sb.append(str("${col(i)}$n", v)) }
                sb.append("<c r=\"D$n\" s=\"2\"><v>${"%.2f".format(java.util.Locale.ROOT, r.amount)}</v></c>")
                listOf(r.account, r.category, r.concept, r.note, r.tags).forEachIndexed { i, v -> sb.append(str("${col(i + 4)}$n", v)) }
                sb.append("</row>")
            }
            sb.append("</sheetData></worksheet>")
            put("xl/worksheets/sheet1.xml", sb.toString())
        }
        return out.toByteArray()
    }
}
