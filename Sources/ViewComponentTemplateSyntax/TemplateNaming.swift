/// Conversions between a component type name and its sidecar template stem.
public enum TemplateNaming {
    /// Initialisms kept whole in both directions, longest first so that a
    /// prefix never wins over the word that contains it.
    public static let initialisms = [
        "HTTPS", "HTML", "HTTP", "JSON", "UUID", "SVG", "XML", "CSS", "PDF",
        "SQL", "URL", "URI", "API", "CLI", "UI", "ID", "IO", "JS",
    ]

    /// `ButtonComponent` -> `button_component`,
    /// `HTMLBlockComponent` -> `html_block_component`.
    public static func snakeCase(from identifier: String) -> String {
        let characters = Array(identifier)
        var snake = ""

        for (index, character) in characters.enumerated() {
            guard character.isUppercase else {
                snake.append(character)
                continue
            }

            let followsLowerOrDigit = index > 0 && !characters[index - 1].isUppercase
            let startsWord = index > 0 && index + 1 < characters.count
                && characters[index - 1].isUppercase && characters[index + 1].isLowercase

            if followsLowerOrDigit || startsWord {
                snake.append("_")
            }

            snake.append(contentsOf: character.lowercased())
        }

        return snake
    }

    /// `button_component` -> `ButtonComponent`,
    /// `html_block_component` -> `HTMLBlockComponent`.
    ///
    /// The inverse is only ambiguous around initialisms, which is what the
    /// `initialisms` table settles. A component whose name it gets wrong
    /// declares the right one with `<%# component: HTMLBlockComponent %>`.
    public static func typeName(fromStem stem: String) -> String {
        stem.split(separator: "_").map { word -> String in
            let uppercased = word.uppercased()

            if initialisms.contains(uppercased) {
                return uppercased
            }

            return word.prefix(1).uppercased() + word.dropFirst()
        }.joined()
    }
}
