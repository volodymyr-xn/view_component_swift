/// FNV-1a over the template source.
///
/// The generated code carries the hash of the template it was built from, so
/// the hot-reload runtime can tell an edited template from an untouched one
/// without comparing whole files.
public enum TemplateSourceHash {
    public static func of(_ source: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325

        for byte in source.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }

        return hash
    }
}
