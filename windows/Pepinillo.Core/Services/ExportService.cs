using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

/// <summary>
/// Pure export builders (no I/O). Callers gate with <see cref="IEntitlementService.CanExport"/>.
/// </summary>
public sealed class ExportService : IExportService
{
    private static readonly UTF8Encoding Utf8Bom = new(encoderShouldEmitUTF8Identifier: true);

    public string BuildSessionsCsv(IReadOnlyList<FocusSession> sessions)
    {
        ArgumentNullException.ThrowIfNull(sessions);

        var sb = new StringBuilder();
        // BOM so Excel opens UTF-8 correctly on Windows.
        sb.Append('\uFEFF');
        sb.AppendLine("Id,Mode,StartedAtUtc,CompletedAtUtc,ElapsedSeconds,TargetDurationSeconds,JournalNote,EnergyRating,TaskItemId");

        foreach (var s in sessions)
        {
            sb.Append(Escape(s.Id.ToString()));
            sb.Append(',');
            sb.Append(Escape(s.Mode.ToString()));
            sb.Append(',');
            sb.Append(Escape(FormatUtc(s.StartedAt)));
            sb.Append(',');
            sb.Append(Escape(s.CompletedAt is { } c ? FormatUtc(c) : string.Empty));
            sb.Append(',');
            sb.Append(s.ElapsedSeconds.ToString(CultureInfo.InvariantCulture));
            sb.Append(',');
            sb.Append(s.TargetDurationSeconds.ToString(CultureInfo.InvariantCulture));
            sb.Append(',');
            sb.Append(Escape(s.JournalNote ?? string.Empty));
            sb.Append(',');
            sb.Append(s.EnergyRating?.ToString(CultureInfo.InvariantCulture) ?? string.Empty);
            sb.Append(',');
            sb.Append(Escape(s.TaskItemId?.ToString() ?? string.Empty));
            sb.AppendLine();
        }

        return sb.ToString();
    }

    public byte[] BuildSessionsPdfSimple(IReadOnlyList<FocusSession> sessions, string title = "Pepinillo Focus Sessions")
    {
        ArgumentNullException.ThrowIfNull(sessions);

        var lines = new List<string>
        {
            title,
            $"Generated (UTC): {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss}",
            $"Sessions: {sessions.Count}",
            string.Empty
        };

        foreach (var s in sessions)
        {
            var completed = s.CompletedAt is { } c ? FormatUtc(c) : "—";
            var note = string.IsNullOrWhiteSpace(s.JournalNote)
                ? string.Empty
                : " | " + Truncate(s.JournalNote!.Replace('\n', ' ').Replace('\r', ' '), 80);
            lines.Add(
                $"{FormatUtc(s.StartedAt)}  {s.Mode,-12}  {s.ElapsedSeconds,5}s / {s.TargetDurationSeconds}s  done={completed}{note}");
        }

        if (sessions.Count == 0)
            lines.Add("(no sessions in range)");

        return SimplePdfWriter.WriteTextDocument(lines, title);
    }

    /// <summary>UTF-8 bytes including BOM for file save (Excel-friendly).</summary>
    public static byte[] GetCsvBytes(string csv)
    {
        var body = Encoding.UTF8.GetBytes(csv.TrimStart('\uFEFF'));
        var preamble = Utf8Bom.GetPreamble();
        if (preamble.Length == 0)
            preamble = new byte[] { 0xEF, 0xBB, 0xBF };

        var result = new byte[preamble.Length + body.Length];
        Buffer.BlockCopy(preamble, 0, result, 0, preamble.Length);
        Buffer.BlockCopy(body, 0, result, preamble.Length, body.Length);
        return result;
    }

    private static string FormatUtc(DateTime dt)
    {
        var utc = dt.Kind == DateTimeKind.Utc ? dt : DateTime.SpecifyKind(dt, DateTimeKind.Utc);
        return utc.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", CultureInfo.InvariantCulture);
    }

    private static string Escape(string value)
    {
        if (value.Contains('"') || value.Contains(',') || value.Contains('\n') || value.Contains('\r'))
            return "\"" + value.Replace("\"", "\"\"") + "\"";
        return value;
    }

    private static string Truncate(string value, int max) =>
        value.Length <= max ? value : value[..(max - 1)] + "…";
}

/// <summary>
/// Minimal multipage PDF 1.4 text writer (Helvetica, fixed layout). No NuGet dependencies.
/// </summary>
internal static class SimplePdfWriter
{
    private const int LinesPerPage = 48;
    private const double Left = 40;
    private const double Top = 780;
    private const double LineHeight = 12;
    private const int FontSize = 9;

    public static byte[] WriteTextDocument(IReadOnlyList<string> lines, string title)
    {
        var pages = new List<List<string>>();
        for (var i = 0; i < lines.Count; i += LinesPerPage)
        {
            var chunk = new List<string>();
            for (var j = i; j < Math.Min(i + LinesPerPage, lines.Count); j++)
                chunk.Add(SanitizePdfText(lines[j]));
            pages.Add(chunk);
        }

        if (pages.Count == 0)
            pages.Add(new List<string> { SanitizePdfText(title), "(empty)" });

        var objects = new List<byte[]>();
        // Object 1: Catalog
        // Object 2: Pages
        // Then per page: Page + Content stream
        // Font object at end

        var pageObjectNumbers = new List<int>();
        var contentObjectNumbers = new List<int>();

        // We'll assign numbers after building body pieces.
        // Layout:
        // 1 catalog
        // 2 pages
        // 3 font
        // 4.. page, content pairs

        const int catalogObj = 1;
        const int pagesObj = 2;
        const int fontObj = 3;
        var nextObj = 4;

        foreach (var _ in pages)
        {
            pageObjectNumbers.Add(nextObj++);
            contentObjectNumbers.Add(nextObj++);
        }

        var bodyParts = new List<(int Num, string Content)>();

        var kids = string.Join(" ", pageObjectNumbers.ConvertAll(n => $"{n} 0 R"));
        bodyParts.Add((catalogObj, $"<< /Type /Catalog /Pages {pagesObj} 0 R >>"));
        bodyParts.Add((pagesObj, $"<< /Type /Pages /Kids [ {kids} ] /Count {pages.Count} >>"));
        bodyParts.Add((fontObj, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"));

        for (var i = 0; i < pages.Count; i++)
        {
            var pageObj = pageObjectNumbers[i];
            var contentObj = contentObjectNumbers[i];
            var stream = BuildPageContent(pages[i]);
            bodyParts.Add((pageObj,
                $"<< /Type /Page /Parent {pagesObj} 0 R /MediaBox [0 0 612 792] " +
                $"/Contents {contentObj} 0 R /Resources << /Font << /F1 {fontObj} 0 R >> >> >>"));
            bodyParts.Add((contentObj,
                $"<< /Length {Encoding.ASCII.GetByteCount(stream)} >>\nstream\n{stream}\nendstream"));
        }

        // Assemble PDF with xref
        var sb = new StringBuilder();
        sb.Append("%PDF-1.4\n");
        var offsets = new Dictionary<int, long>();
        long pos = Encoding.ASCII.GetByteCount(sb.ToString());

        foreach (var (num, content) in bodyParts.OrderBy(p => p.Num))
        {
            offsets[num] = pos;
            var objText = $"{num} 0 obj\n{content}\nendobj\n";
            sb.Append(objText);
            pos += Encoding.ASCII.GetByteCount(objText);
        }

        var xrefPos = pos;
        var maxObj = nextObj - 1;
        sb.Append($"xref\n0 {maxObj + 1}\n");
        sb.Append("0000000000 65535 f \n");
        for (var i = 1; i <= maxObj; i++)
        {
            var off = offsets[i];
            sb.Append(off.ToString("D10", CultureInfo.InvariantCulture));
            sb.Append(" 00000 n \n");
        }

        sb.Append("trailer\n");
        sb.Append($"<< /Size {maxObj + 1} /Root {catalogObj} 0 R >>\n");
        sb.Append("startxref\n");
        sb.Append(xrefPos.ToString(CultureInfo.InvariantCulture));
        sb.Append("\n%%EOF\n");

        return Encoding.ASCII.GetBytes(sb.ToString());
    }

    private static string BuildPageContent(IReadOnlyList<string> pageLines)
    {
        var sb = new StringBuilder();
        sb.Append("BT\n");
        sb.Append($"/F1 {FontSize} Tf\n");
        var y = Top;
        for (var i = 0; i < pageLines.Count; i++)
        {
            if (i == 0)
                sb.Append($"{Left.ToString(CultureInfo.InvariantCulture)} {y.ToString(CultureInfo.InvariantCulture)} Td\n");
            else
                sb.Append($"0 {(-LineHeight).ToString(CultureInfo.InvariantCulture)} Td\n");
            sb.Append('(');
            sb.Append(pageLines[i]);
            sb.Append(") Tj\n");
        }

        sb.Append("ET\n");
        return sb.ToString();
    }

    /// <summary>Escape PDF literal string and strip non-Latin1 for Helvetica.</summary>
    private static string SanitizePdfText(string text)
    {
        if (string.IsNullOrEmpty(text))
            return string.Empty;

        var sb = new StringBuilder(text.Length);
        foreach (var ch in text)
        {
            if (ch is '(' or ')' or '\\')
            {
                sb.Append('\\');
                sb.Append(ch);
            }
            else if (ch is '\r' or '\n' or '\t')
            {
                sb.Append(' ');
            }
            else if (ch >= 32 && ch <= 126)
            {
                sb.Append(ch);
            }
            else if (ch > 126 && ch <= 255)
            {
                // Latin-1 passthrough as octal
                sb.Append('\\');
                sb.Append(Convert.ToString(ch, 8).PadLeft(3, '0'));
            }
            else
            {
                sb.Append('?');
            }
        }

        // Keep line length reasonable for content stream
        if (sb.Length > 110)
        {
            sb.Length = 107;
            sb.Append("...");
        }

        return sb.ToString();
    }
}
