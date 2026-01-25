namespace MatrixShader.Core.Constants;

/// <summary>
/// Movie-accurate character set from The Matrix (1999).
/// Uses mirrored half-width Katakana mixed with Latin characters.
/// </summary>
public static class KatakanaChars
{
    /// <summary>
    /// Half-width Katakana characters as used in the original film.
    /// These appear mirrored/reversed on screen.
    /// </summary>
    public const string Katakana =
        "ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ";

    /// <summary>
    /// Digits used in the Matrix code.
    /// </summary>
    public const string Digits = "0123456789";

    /// <summary>
    /// Special symbols from the film.
    /// </summary>
    public const string Symbols = "=*+-<>|:\"";

    /// <summary>
    /// Complete character set for Matrix rain effect.
    /// </summary>
    public static readonly string AllCharacters = Katakana + Digits + Symbols;

    /// <summary>
    /// Character array for fast random access.
    /// </summary>
    public static readonly char[] CharArray = AllCharacters.ToCharArray();

    /// <summary>
    /// Total number of available characters.
    /// </summary>
    public static readonly int CharCount = CharArray.Length;

    /// <summary>
    /// Get a random character from the set.
    /// </summary>
    public static char GetRandom(Random random) =>
        CharArray[random.Next(CharCount)];

    /// <summary>
    /// Get character at specific index (wrapping).
    /// </summary>
    public static char GetAt(int index) =>
        CharArray[index % CharCount];
}
