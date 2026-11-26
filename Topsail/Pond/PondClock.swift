import SwiftUI

/// The time and the date over the pond, each line white pixel type on its own dark, see-through
/// box, in the style the pond was drawn after.
struct PondClock: View {
    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let time = Self.time(timeline.date), date = Self.date(timeline.date)
            VStack(spacing: 8) {
                PixelLine(text: time, pixel: 4, padding: CGSize(width: 10, height: 7))
                PixelLine(text: date, pixel: 2, padding: CGSize(width: 7, height: 4))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "\(time), \(date)"))
        }
        .allowsHitTesting(false)
    }

    /// "10:42", or "10:42 pm" where the clock is 12-hour.
    static func time(_ date: Date) -> String {
        tidy(date.formatted(date: .omitted, time: .shortened))
    }

    /// "thursday 27 november", in the user's language and order.
    static func date(_ date: Date) -> String {
        tidy(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
    }

    /// Lowercase, as the pond's type is, with the narrow spaces some formats use made plain.
    private static func tidy(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }
}

/// One line of pixel type on a dark box. Text the pixel font can't draw is set in the system's
/// monospaced font instead, at the same size.
private struct PixelLine: View {
    let text: String
    /// One pixel of a glyph, in points.
    let pixel: CGFloat
    let padding: CGSize

    var body: some View {
        Group {
            if PixelFont.canDraw(text) {
                let size = PixelFont.size(of: text, pixel: pixel)
                Canvas { context, _ in
                    context.fill(PixelFont.path(for: text, pixel: pixel), with: .color(PixelFont.ink))
                }
                .frame(width: size.width, height: size.height)
            } else {
                Text(verbatim: text)
                    .font(.system(size: pixel * 7, weight: .medium, design: .monospaced))
                    .foregroundStyle(PixelFont.ink)
            }
        }
        .padding(.horizontal, padding.width)
        .padding(.vertical, padding.height)
        .background(Color.black.opacity(0.55))
    }
}

/// A 5 × 8 pixel font: lowercase, digits, the punctuation a time and date need, and the accented
/// letters of French and Spanish dates. Rows 2–6 are the x-height, row 7 the descender.
enum PixelFont {
    static let ink = Color(red: 0.953, green: 0.949, blue: 0.906)

    static func canDraw(_ text: String) -> Bool {
        text.allSatisfy { glyphs[$0] != nil }
    }

    /// Glyphs are five pixels wide with one between them; lines are eight pixels tall.
    static func size(of text: String, pixel: CGFloat) -> CGSize {
        CGSize(width: CGFloat(max(0, text.count * 6 - 1)) * pixel, height: 8 * pixel)
    }

    static func path(for text: String, pixel: CGFloat) -> Path {
        var path = Path()
        for (n, character) in text.enumerated() {
            guard let rows = glyphs[character] else { continue }
            for (y, row) in rows.enumerated() {
                for (x, bit) in row.enumerated() where bit == "#" {
                    path.addRect(CGRect(x: CGFloat(n * 6 + x) * pixel, y: CGFloat(y) * pixel, width: pixel, height: pixel))
                }
            }
        }
        return path
    }

    private static let base: [Character: [String]] = [
        "a": ["", "", " ### ", "    #", " ####", "#   #", " ####", ""],
        "b": ["#", "#", "#### ", "#   #", "#   #", "#   #", "#### ", ""],
        "c": ["", "", " ####", "#", "#", "#", " ####", ""],
        "d": ["    #", "    #", " ####", "#   #", "#   #", "#   #", " ####", ""],
        "e": ["", "", " ### ", "#   #", "#####", "#", " ####", ""],
        "f": ["  ## ", " #", "#### ", " #", " #", " #", " #", ""],
        "g": ["", "", " ####", "#   #", "#   #", " ####", "    #", " ### "],
        "h": ["#", "#", "#### ", "#   #", "#   #", "#   #", "#   #", ""],
        "i": ["  #", "", " ##", "  #", "  #", "  #", " ###", ""],
        "j": ["   #", "", "  ##", "   #", "   #", "   #", "#  #", " ## "],
        "k": ["#", "#", "#  #", "# #", "##", "# #", "#  #", ""],
        "l": [" ##", "  #", "  #", "  #", "  #", "  #", " ###", ""],
        "m": ["", "", "## # ", "# # #", "# # #", "# # #", "#   #", ""],
        "n": ["", "", "#### ", "#   #", "#   #", "#   #", "#   #", ""],
        "o": ["", "", " ### ", "#   #", "#   #", "#   #", " ### ", ""],
        "p": ["", "", "#### ", "#   #", "#   #", "#### ", "#", "#"],
        "q": ["", "", " ####", "#   #", "#   #", " ####", "    #", "    #"],
        "r": ["", "", "# ## ", "##  #", "#", "#", "#", ""],
        "s": ["", "", " ####", "#", " ### ", "    #", "#### ", ""],
        "t": [" #", " #", "#### ", " #", " #", " #  #", "  ## ", ""],
        "u": ["", "", "#   #", "#   #", "#   #", "#   #", " ####", ""],
        "v": ["", "", "#   #", "#   #", "#   #", " # # ", "  #", ""],
        "w": ["", "", "#   #", "#   #", "# # #", "# # #", " # # ", ""],
        "x": ["", "", "#   #", " # # ", "  #", " # # ", "#   #", ""],
        "y": ["", "", "#   #", "#   #", "#   #", " ####", "    #", " ### "],
        "z": ["", "", "#####", "   #", "  #", " #", "#####", ""],
        "0": [" ### ", "#   #", "#  ##", "# # #", "##  #", "#   #", " ### ", ""],
        "1": ["  #", " ##", "  #", "  #", "  #", "  #", " ###", ""],
        "2": [" ### ", "#   #", "    #", "   #", "  #", " #", "#####", ""],
        "3": [" ### ", "#   #", "    #", "  ## ", "    #", "#   #", " ### ", ""],
        "4": ["   #", "  ##", " # #", "#  #", "#####", "   #", "   #", ""],
        "5": ["#####", "#", "#### ", "    #", "    #", "#   #", " ### ", ""],
        "6": ["  ## ", " #", "#", "#### ", "#   #", "#   #", " ### ", ""],
        "7": ["#####", "    #", "   #", "  #", " #", " #", " #", ""],
        "8": [" ### ", "#   #", "#   #", " ### ", "#   #", "#   #", " ### ", ""],
        "9": [" ### ", "#   #", "#   #", " ####", "    #", "   #", " ##", ""],
        ":": ["", "", "  #", "", "", "  #", "", ""],
        ".": ["", "", "", "", "", "", "  #", ""],
        ",": ["", "", "", "", "", "  #", "  #", " #"],
        "-": ["", "", "", "", "#####", "", "", ""],
        "/": ["    #", "    #", "   #", "  #", " #", "#", "#", ""],
        " ": ["", "", "", "", "", "", "", ""],
    ]

    /// Accents sit in the two rows above the x-height.
    private static let marks: [String: [String]] = [
        "acute": ["   #", "  #"], "grave": [" #", "  #"], "circumflex": ["  #", " # #"],
        "diaeresis": ["", " # #"], "tilde": [" ## #", "#  #"],
    ]

    private static let accented: [Character: (Character, String)] = [
        "á": ("a", "acute"), "à": ("a", "grave"), "â": ("a", "circumflex"), "ä": ("a", "diaeresis"),
        "é": ("e", "acute"), "è": ("e", "grave"), "ê": ("e", "circumflex"), "ë": ("e", "diaeresis"),
        "í": ("ı", "acute"), "ì": ("ı", "grave"), "î": ("ı", "circumflex"), "ï": ("ı", "diaeresis"),
        "ó": ("o", "acute"), "ò": ("o", "grave"), "ô": ("o", "circumflex"), "ö": ("o", "diaeresis"),
        "ú": ("u", "acute"), "ù": ("u", "grave"), "û": ("u", "circumflex"), "ü": ("u", "diaeresis"),
        "ñ": ("n", "tilde"),
    ]

    private static let glyphs: [Character: [String]] = {
        var all = base
        // A dotless i to carry its own accent.
        all["ı"] = ["", "", " ##", "  #", "  #", "  #", " ###", ""]
        for (letter, (plain, mark)) in accented {
            guard var rows = all[plain], let accent = marks[mark] else { continue }
            rows[0] = accent[0]
            rows[1] = accent[1]
            all[letter] = rows
        }
        // ç: c with a cedilla in the descender row.
        if var c = all["c"] {
            c[7] = "  ## "
            all["ç"] = c
        }
        return all
    }()
}
