#!/usr/bin/env node
/**
 * Genera los .docx institucionales (formato UPT) a partir de los .md fuente
 * en docs/. Correr con: `node md-to-word.js` (sin argumentos: procesa
 * FD01-Informe-Factibilidad.md y FD02-Informe-Vision.md) o
 * `node md-to-word.js <archivo.md> [salida.docx]` para uno solo.
 *
 * No depende de pandoc ni de Word instalado: usa la librería `docx` para
 * construir el .docx byte a byte, y mermaid.ink (servicio público, sin
 * API key) para rasterizar los bloques ```mermaid``` a imagen antes de
 * insertarlos. Las imágenes se cachean en .cache/ para no re-descargarlas
 * en cada corrida.
 */

"use strict";

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const {
  Document,
  Packer,
  Paragraph,
  TextRun,
  ImageRun,
  Table,
  TableRow,
  TableCell,
  Header,
  Footer,
  PageBreak,
  AlignmentType,
  HeadingLevel,
  BorderStyle,
  WidthType,
  VerticalAlign,
  PageNumber,
  ShadingType,
} = require("docx");

const DOCS_DIR = path.resolve(__dirname, "..");
const CACHE_DIR = path.join(__dirname, ".cache");
const LOGO_PATH = path.join(DOCS_DIR, "media", "logo-upt.png");

// Nombre que va en el pie de página de todas las hojas interiores, en vez
// del nombre de ejemplo de la plantilla original ("Mag. Alberto Johantan
// Flor Rodríguez"). Solo el nombre, sin grado ni cargo.
const FOOTER_NAME = "Patricio Cuadros";
const HEADER_TITLE = "Escuela Profesional de Ingeniería de Sistemas";

const NAVY = "1F4E79";
const RULE = "808080";

// ---------------------------------------------------------------------
// Utilidades de formato en línea (bold/italic/code) -> TextRun[]
// ---------------------------------------------------------------------

function parseInline(text, baseOpts = {}) {
  // Normaliza escapes tipo "1\.0" -> "1.0", entidades y tabs usados en el md.
  text = text
    .replace(/\\\./g, ".")
    .replace(/&nbsp;/g, " ")
    .replace(/\t/g, " ")
    .replace(/<span[^>]*>\s*<\/span>/g, "");

  const runs = [];
  // Tokeniza por **bold**, ***bolditalic***, *italic*, `code`, dejando el
  // resto como texto plano. Orden de precedencia: *** antes que ** y *.
  const tokenRe = /(\*\*\*([^*]+)\*\*\*)|(\*\*([^*]+)\*\*)|(\*([^*]+)\*)|(`([^`]+)`)/g;
  let last = 0;
  let m;
  while ((m = tokenRe.exec(text)) !== null) {
    if (m.index > last) pushPlain(runs, text.slice(last, m.index), baseOpts);
    if (m[1] !== undefined) {
      runs.push(new TextRun({ text: m[2], bold: true, italics: true, ...baseOpts }));
    } else if (m[3] !== undefined) {
      runs.push(new TextRun({ text: m[4], bold: true, ...baseOpts }));
    } else if (m[5] !== undefined) {
      runs.push(new TextRun({ text: m[6], italics: true, ...baseOpts }));
    } else if (m[7] !== undefined) {
      runs.push(
        new TextRun({ text: m[8], font: "Consolas", ...baseOpts })
      );
    }
    last = tokenRe.lastIndex;
  }
  if (last < text.length) pushPlain(runs, text.slice(last), baseOpts);
  if (runs.length === 0) runs.push(new TextRun({ text: "", ...baseOpts }));
  return runs;
}

function pushPlain(runs, text, baseOpts) {
  if (text === "") return;
  runs.push(new TextRun({ text, ...baseOpts }));
}

function stripInlineToPlainText(text) {
  return text
    .replace(/\\\./g, ".")
    .replace(/&nbsp;/g, " ")
    .replace(/\t/g, " ")
    .replace(/<span[^>]*>\s*<\/span>/g, "") // anclas <span id="..."></span> sueltas
    .replace(/\*\*\*([^*]+)\*\*\*/g, "$1")
    .replace(/\*\*([^*]+)\*\*/g, "$1")
    .replace(/\*([^*]+)\*/g, "$1")
    .replace(/`([^`]+)`/g, "$1");
}

// ---------------------------------------------------------------------
// Mermaid -> imagen (via mermaid.ink), con caché local en disco
// ---------------------------------------------------------------------

async function renderMermaidToImage(code) {
  if (!fs.existsSync(CACHE_DIR)) fs.mkdirSync(CACHE_DIR, { recursive: true });
  const hash = crypto.createHash("sha256").update(code).digest("hex").slice(0, 24);
  const cachePath = path.join(CACHE_DIR, `${hash}.png`);
  if (fs.existsSync(cachePath)) {
    return fs.readFileSync(cachePath);
  }
  const b64 = Buffer.from(code, "utf8").toString("base64url");
  const url = `https://mermaid.ink/img/${b64}?type=png&width=1400&bgColor=white`;
  console.log(`  descargando diagrama mermaid (${hash})...`);
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`mermaid.ink respondió ${res.status} para el diagrama ${hash}`);
  }
  const buf = Buffer.from(await res.arrayBuffer());
  fs.writeFileSync(cachePath, buf);
  return buf;
}

function pngDimensions(buf) {
  // PNG: ancho/alto en big-endian en los bytes 16-23 del IHDR.
  if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) {
    const width = buf.readUInt32BE(16);
    const height = buf.readUInt32BE(20);
    return { width, height };
  }
  return { width: 800, height: 450 };
}

// ---------------------------------------------------------------------
// Tablas GFM (pipe tables)
// ---------------------------------------------------------------------

function parseTableRow(line) {
  let s = line.trim();
  if (s.startsWith("|")) s = s.slice(1);
  if (s.endsWith("|")) s = s.slice(0, -1);
  // Respeta \| escapado dentro de una celda (no se usa hoy, pero por si acaso).
  return s.split(/(?<!\\)\|/).map((c) => c.trim());
}

function isSeparatorRow(cells) {
  return cells.every((c) => /^:?-{1,}:?$/.test(c.replace(/\s/g, "")));
}

function buildTable(lines) {
  const rows = lines.map(parseTableRow);
  // La fila 1 es encabezado; si la fila 2 es separador GFM, se descarta.
  const header = rows[0];
  let dataRows = rows.slice(1);
  if (dataRows.length && isSeparatorRow(dataRows[0])) dataRows = dataRows.slice(1);

  const colCount = header.length;
  const colWidth = Math.floor(9000 / colCount);

  function cell(text, { isHeader = false } = {}) {
    const plain = stripInlineToPlainText(text);
    const isEmpty = plain.trim() === "" || plain.trim() === " ";
    return new TableCell({
      width: { size: colWidth, type: WidthType.DXA },
      verticalAlign: VerticalAlign.CENTER,
      shading: isHeader
        ? { fill: "D9E2F3", type: ShadingType.CLEAR, color: "auto" }
        : undefined,
      margins: { top: 60, bottom: 60, left: 100, right: 100 },
      children: [
        new Paragraph({
          alignment: AlignmentType.LEFT,
          children: isEmpty
            ? [new TextRun({ text: "", size: 20 })]
            : parseInline(text, { bold: isHeader, size: 20, font: "Times New Roman" }),
        }),
      ],
    });
  }

  const tableRows = [
    new TableRow({
      tableHeader: true,
      children: header.map((h) => cell(h, { isHeader: true })),
    }),
    ...dataRows
      .filter((r) => r.length > 0 && !(r.length === 1 && r[0] === ""))
      .map(
        (r) =>
          new TableRow({
            children: header.map((_, i) => cell(r[i] !== undefined ? r[i] : "")),
          })
      ),
  ];

  return new Table({
    width: { size: 9000, type: WidthType.DXA },
    rows: tableRows,
    borders: {
      top: { style: BorderStyle.SINGLE, size: 4, color: "999999" },
      bottom: { style: BorderStyle.SINGLE, size: 4, color: "999999" },
      left: { style: BorderStyle.SINGLE, size: 4, color: "999999" },
      right: { style: BorderStyle.SINGLE, size: 4, color: "999999" },
      insideHorizontal: { style: BorderStyle.SINGLE, size: 4, color: "CCCCCC" },
      insideVertical: { style: BorderStyle.SINGLE, size: 4, color: "CCCCCC" },
    },
  });
}

// ---------------------------------------------------------------------
// Encabezado / pie de página institucionales
// ---------------------------------------------------------------------

function buildHeader(logoBuffer) {
  return new Header({
    children: [
      new Paragraph({
        tabStops: [{ type: "right", position: 9026 }],
        // lineRule "atLeast" evita que LibreOffice recorte el logo contra la
        // altura de línea por defecto del documento (1.5, heredada de los
        // estilos APA del cuerpo) — ver buildDocx() / imageParagraph().
        spacing: { line: 700, lineRule: "atLeast" },
        border: {
          bottom: { style: BorderStyle.SINGLE, size: 6, color: NAVY, space: 4 },
        },
        children: [
          new ImageRun({
            data: logoBuffer,
            transformation: { width: 34, height: 43 },
            type: "png",
          }),
          new TextRun({ text: "\t" }),
          new TextRun({
            text: HEADER_TITLE,
            color: NAVY,
            size: 20,
            font: "Calibri",
          }),
        ],
      }),
    ],
  });
}

function buildFooter() {
  return new Footer({
    children: [
      new Paragraph({
        tabStops: [{ type: "right", position: 9026 }],
        border: {
          top: { style: BorderStyle.SINGLE, size: 6, color: RULE, space: 4 },
        },
        children: [
          new TextRun({ text: FOOTER_NAME, size: 18, font: "Calibri", color: "404040" }),
          new TextRun({ text: "\t" }),
          new TextRun({ text: "- ", size: 18, font: "Calibri", color: "404040" }),
          new TextRun({ children: [PageNumber.CURRENT], size: 18, font: "Calibri", color: "404040" }),
          new TextRun({ text: " -", size: 18, font: "Calibri", color: "404040" }),
        ],
      }),
    ],
  });
}

function emptyHeaderFooter() {
  return { header: new Header({ children: [new Paragraph({ children: [] })] }), footer: new Footer({ children: [new Paragraph({ children: [] })] }) };
}

// ---------------------------------------------------------------------
// Estilos de párrafo (APA: Times New Roman 12, interlineado 1.5, justificado)
// ---------------------------------------------------------------------

const BODY_FONT = "Times New Roman";
const BODY_SIZE = 24; // 12pt (en half-points)

function bodyParagraph(line) {
  const indented = /^(?:&nbsp;)+/.test(line);
  // Quita TODOS los grupos de &nbsp; iniciales del texto: la sangría visual
  // la da `indent.firstLine`, no espacios literales (si no, queda doble
  // sangría cuando hay más de un grupo de &nbsp;).
  const text = line.replace(/^(?:&nbsp;)+/, "").trim();
  return new Paragraph({
    alignment: AlignmentType.JUSTIFIED,
    spacing: { line: 360, after: 160 },
    indent: indented ? { firstLine: 567 } : undefined,
    children: parseInline(text, { font: BODY_FONT, size: BODY_SIZE }),
  });
}

function h1Paragraph(text, { pageBreakBefore = false } = {}) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    alignment: AlignmentType.CENTER,
    pageBreakBefore,
    spacing: { before: 120, after: 240 },
    children: [
      new TextRun({
        text: stripInlineToPlainText(text),
        bold: true,
        underline: {},
        size: 30,
        font: BODY_FONT,
        color: "000000",
      }),
    ],
  });
}

function subHeadingParagraph(text, depth) {
  const sizeByDepth = { 1: 26, 2: 24, 3: 24, 4: 22 };
  return new Paragraph({
    heading: depth === 1 ? HeadingLevel.HEADING_2 : HeadingLevel.HEADING_3,
    alignment: AlignmentType.LEFT,
    spacing: { before: 200, after: 120 },
    children: [
      new TextRun({
        text: stripInlineToPlainText(text),
        bold: true,
        italics: depth >= 3,
        size: sizeByDepth[depth] || 22,
        font: BODY_FONT,
        color: "000000",
      }),
    ],
  });
}

function centerParagraph(text, opts = {}) {
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { after: 120 },
    children: parseInline(text, { font: BODY_FONT, size: BODY_SIZE, ...opts }),
  });
}

function bulletParagraph(text) {
  return new Paragraph({
    bullet: { level: 0 },
    alignment: AlignmentType.JUSTIFIED,
    spacing: { after: 80 },
    children: parseInline(text, { font: BODY_FONT, size: BODY_SIZE }),
  });
}

function plainParagraph(text, opts = {}) {
  return new Paragraph({
    alignment: AlignmentType.LEFT,
    spacing: { after: 100 },
    children: parseInline(text, { font: BODY_FONT, size: BODY_SIZE, ...opts }),
  });
}

async function imageParagraph(buf, caption) {
  const { width, height } = pngDimensions(buf);
  const maxWidthPx = 560; // ~5.8in a 96dpi, cabe en el área de texto A4/Carta
  const maxHeightPx = 760; // ~7.9in a 96dpi, cabe en una sola página A4 con margen
  const scale = Math.min(
    width > maxWidthPx ? maxWidthPx / width : 1,
    height > maxHeightPx ? maxHeightPx / height : 1
  );
  const finalHeight = Math.round(height * scale);
  const children = [];

  // Estilo APA 7 para figuras: número de figura (negrita) + título
  // descriptivo (cursiva) ANTES de la imagen, no después.
  if (caption) {
    const m = caption.match(/^(Figura\s+\d+)\.?\s*(.*)$/i);
    children.push(
      new Paragraph({
        alignment: AlignmentType.LEFT,
        spacing: { before: 160, after: 40 },
        children: [
          new TextRun({ text: m ? m[1] : "Figura", bold: true, size: 22, font: BODY_FONT }),
        ],
      })
    );
    if (m && m[2]) {
      children.push(
        new Paragraph({
          alignment: AlignmentType.LEFT,
          spacing: { after: 80 },
          children: [new TextRun({ text: m[2], italics: true, size: 22, font: BODY_FONT })],
        })
      );
    }
  }

  children.push(
    new Paragraph({
      alignment: AlignmentType.CENTER,
      // lineRule "atLeast" evita que LibreOffice/Word recorten la imagen
      // contra la altura de línea heredada del estilo de párrafo (1.5).
      spacing: { before: 80, after: 200, line: finalHeight * 15 + 60, lineRule: "atLeast" },
      children: [
        new ImageRun({
          data: buf,
          transformation: { width: Math.round(width * scale), height: finalHeight },
          type: "png",
        }),
      ],
    })
  );
  return children;
}

// ---------------------------------------------------------------------
// Parser principal: .md (nuestro dialecto controlado) -> children[] de docx
// ---------------------------------------------------------------------

const HEADING_NUM_RE = /^(\d+(?:\.\d+){0,3})\.?\s+(\S.{0,68})$/;
const HEADING_LETTER_RE = /^([a-d])\)\s+(\S.{0,68})$/;
const TOP_SECTION_RE = /^(\d+)\.\s*<span[^>]*anchor[^>]*><\/span>\s*\*\*(.+)\*\*$/;
const NAMED_SECTION_RE = /^<span[^>]*anchor[^>]*><\/span>\s*\*\*(.+)\*\*$/;
const SUBTITLE_U_RE = /^\*\*<u>(.+)<\/u>\*\*$/;
const TOC_LINK_RE = /^\[(.+?)\]\(#.*\)$/;

async function parseMarkdown(mdText) {
  const rawLines = mdText.split(/\r?\n/);
  const children = [];
  let i = 0;
  let inCenter = false;
  // El salto de página se DIFIERE en vez de insertarse de inmediato: un
  // párrafo que contiene solo un <w:br type="page"/> puede, si el contenido
  // anterior ya llenó la página de forma natural, generar una página en
  // blanco extra en LibreOffice/Word (el salto "dispara" igual aunque el
  // párrafo ya haya caído al tope de una página nueva). La forma segura es
  // aplicar `pageBreakBefore` directamente sobre el siguiente párrafo real.
  let pendingBreak = false;
  const flushBreak = () => {
    if (pendingBreak) {
      children.push(new Paragraph({ children: [new PageBreak()] }));
      pendingBreak = false;
    }
  };

  while (i < rawLines.length) {
    const raw = rawLines[i];
    const line = raw.trim();

    // --- bloque <center> (portada) ---
    if (line === "<center>") {
      inCenter = true;
      i++;
      continue;
    }
    if (line === "</center>") {
      inCenter = false;
      i++;
      continue;
    }

    // --- salto de página (diferido, ver flushBreak) ---
    if (/page-break-after/.test(line)) {
      pendingBreak = true;
      i++;
      continue;
    }

    // --- líneas vacías o cruft ("#" suelto, [comment]:) ---
    if (line === "" || line === "#" || line.startsWith("[comment]:")) {
      i++;
      continue;
    }

    // --- bloque mermaid ---
    if (line.startsWith("```mermaid")) {
      const codeLines = [];
      i++;
      while (i < rawLines.length && rawLines[i].trim() !== "```") {
        codeLines.push(rawLines[i]);
        i++;
      }
      i++; // salta el ``` de cierre
      const code = codeLines.join("\n");
      // Prioridad: comentario explícito "%% caption: ..." (funciona en
      // cualquier tipo de diagrama); si no hay, cae a la directiva nativa
      // "title ..." de mermaid (solo la soportan gantt/pie/etc.).
      const captionMatch = code.match(/%%\s*caption:\s*(.+)/);
      const titleMatch = captionMatch || code.match(/title\s+(.+)/);
      const buf = await renderMermaidToImage(code);
      const imgChildren = await imageParagraph(buf, titleMatch ? titleMatch[1].trim() : "");
      flushBreak();
      children.push(...imgChildren);
      continue;
    }

    // --- imagen de portada (logo) ---
    const imgMatch = line.match(/^!\[.*?\]\((.+?)\)$/);
    if (imgMatch) {
      flushBreak();
      const imgPath = path.resolve(DOCS_DIR, imgMatch[1]);
      if (fs.existsSync(imgPath)) {
        const buf = fs.readFileSync(imgPath);
        const imgHeight = 109;
        children.push(
          new Paragraph({
            alignment: AlignmentType.CENTER,
            spacing: { after: 160, line: imgHeight * 15 + 60, lineRule: "atLeast" },
            children: [
              new ImageRun({ data: buf, transformation: { width: 85, height: imgHeight }, type: "png" }),
            ],
          })
        );
      }
      i++;
      continue;
    }

    // --- tabla GFM ---
    if (line.startsWith("|")) {
      flushBreak();
      const tableLines = [];
      while (i < rawLines.length && rawLines[i].trim().startsWith("|")) {
        tableLines.push(rawLines[i].trim());
        i++;
      }
      children.push(buildTable(tableLines));
      children.push(new Paragraph({ spacing: { after: 160 }, children: [] }));
      continue;
    }

    // --- portada: cada línea es un párrafo centrado ---
    if (inCenter) {
      const plain = line.replace(/\*/g, "").replace(/&nbsp;/g, "").trim();
      if (plain !== "") {
        flushBreak();
        const big = /UNIVERSIDAD|FACULTAD|Escuela Profesional/.test(line);
        children.push(centerParagraph(line, big ? { bold: true, size: 22 } : {}));
      }
      i++;
      continue;
    }

    // --- subtítulo con <u> ("Informe de Factibilidad" / "Informe de Visión") ---
    const subtitleMatch = line.match(SUBTITLE_U_RE);
    if (subtitleMatch) {
      children.push(h1Paragraph(subtitleMatch[1], { pageBreakBefore: pendingBreak }));
      pendingBreak = false;
      i++;
      continue;
    }

    // --- "# **INDICE GENERAL**" o "**INDICE GENERAL**" ---
    const hashHeading = line.match(/^#\s*\*\*(.+)\*\*$/);
    if (hashHeading) {
      children.push(h1Paragraph(hashHeading[1], { pageBreakBefore: pendingBreak }));
      pendingBreak = false;
      i++;
      continue;
    }
    const boldOnlyHeading = line.match(/^\*\*(INDICE GENERAL|[A-ZÁÉÍÓÚÑ ]{5,})\*\*$/);
    if (boldOnlyHeading && !TOP_SECTION_RE.test(line)) {
      children.push(h1Paragraph(boldOnlyHeading[1], { pageBreakBefore: pendingBreak }));
      pendingBreak = false;
      i++;
      continue;
    }

    // --- líneas de portada secundaria marcadas con "> " ---
    if (line.startsWith(">")) {
      flushBreak();
      const text = line.replace(/^>\s*/, "");
      children.push(centerParagraph(text, { bold: true }));
      i++;
      continue;
    }

    // --- sección numerada principal (con ancla) ---
    const topMatch = line.match(TOP_SECTION_RE);
    if (topMatch) {
      const [, num, title] = topMatch;
      children.push(h1Paragraph(`${num}. ${title}`, { pageBreakBefore: pendingBreak }));
      pendingBreak = false;
      i++;
      continue;
    }

    // --- sección nombrada sin número (CONCLUSIONES, RECOMENDACIONES, ...) ---
    const namedMatch = line.match(NAMED_SECTION_RE);
    if (namedMatch) {
      children.push(h1Paragraph(namedMatch[1], { pageBreakBefore: pendingBreak }));
      pendingBreak = false;
      i++;
      continue;
    }

    // --- enlace de índice: [Texto](#ancla) ---
    const tocMatch = line.match(TOC_LINK_RE);
    if (tocMatch) {
      flushBreak();
      children.push(plainParagraph(tocMatch[1]));
      i++;
      continue;
    }

    // --- listas con viñetas ---
    if (/^-\s+\S/.test(line)) {
      flushBreak();
      children.push(bulletParagraph(line.replace(/^-\s+/, "")));
      i++;
      continue;
    }

    // --- subtítulos numerados / con letra (a-d) ---
    const numHeading = line.match(HEADING_NUM_RE);
    const letterHeading = line.match(HEADING_LETTER_RE);
    if (numHeading && !/[.:]\s+\S.*\s\S.*\s\S.*\s\S/.test(numHeading[2])) {
      flushBreak();
      const depth = numHeading[1].split(".").length;
      children.push(subHeadingParagraph(`${numHeading[1]}. ${numHeading[2]}`, depth));
      i++;
      continue;
    }
    if (letterHeading) {
      flushBreak();
      children.push(subHeadingParagraph(`${letterHeading[1]}) ${letterHeading[2]}`, 2));
      i++;
      continue;
    }

    // --- párrafo normal ---
    flushBreak();
    children.push(bodyParagraph(line));
    i++;
  }

  return children;
}

// ---------------------------------------------------------------------
// Ensamblado final del documento
// ---------------------------------------------------------------------

async function buildDocx(mdPath, outPath) {
  const mdText = fs.readFileSync(mdPath, "utf8");
  console.log(`Procesando ${path.basename(mdPath)}...`);
  const body = await parseMarkdown(mdText);

  const logoBuffer = fs.readFileSync(LOGO_PATH);
  const { header: emptyHeader, footer: emptyFooter } = emptyHeaderFooter();

  const doc = new Document({
    styles: {
      default: {
        document: {
          run: { font: BODY_FONT, size: BODY_SIZE },
          paragraph: { spacing: { line: 360 } },
        },
      },
    },
    sections: [
      {
        properties: {
          titlePage: true,
          page: {
            size: { width: 11906, height: 16838 }, // A4
            margin: { top: 1418, bottom: 1418, left: 1701, right: 1134 }, // ~2.5/2.5/3/2 cm
          },
        },
        headers: { default: buildHeader(logoBuffer), first: emptyHeader },
        footers: { default: buildFooter(), first: emptyFooter },
        children: body,
      },
    ],
  });

  const buffer = await Packer.toBuffer(doc);
  fs.writeFileSync(outPath, buffer);
  console.log(`  -> ${path.relative(DOCS_DIR, outPath)} (${(buffer.length / 1024).toFixed(0)} KB)`);
}

async function main() {
  const args = process.argv.slice(2);
  let targets;
  if (args.length === 0) {
    targets = [
      ["FD01-Informe-Factibilidad.md", "FD01-EPIS-Informe de Factibilidad.docx"],
      ["FD02-Informe-Vision.md", "FD02-EPIS-Informe Vision.docx"],
    ].map(([md, docx]) => [path.join(DOCS_DIR, md), path.join(DOCS_DIR, docx)]);
  } else {
    const mdPath = path.resolve(args[0]);
    const outPath = args[1]
      ? path.resolve(args[1])
      : mdPath.replace(/\.md$/i, ".docx");
    targets = [[mdPath, outPath]];
  }

  for (const [mdPath, outPath] of targets) {
    await buildDocx(mdPath, outPath);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
