namespace MatrixShader.Core.Constants;

/// <summary>
/// Random Matrix movie quotes for CLI aesthetics.
/// Displayed on CLI startup for theatrical effect.
/// </summary>
public static class MatrixQuotes
{
    private static readonly string[] Quotes =
    {
        "The Matrix has you...",
        "Follow the white rabbit.",
        "There is no spoon.",
        "Free your mind.",
        "I know kung fu.",
        "Welcome to the real world.",
        "What is the Matrix?",
        "You've been living in a dream world, Neo.",
        "Unfortunately, no one can be told what the Matrix is.",
        "The body cannot live without the mind.",
        "Dodge this.",
        "I can only show you the door.",
        "Everything begins with choice.",
        "There's a difference between knowing the path and walking the path."
    };

    /// <summary>
    /// Gets a random Matrix quote.
    /// </summary>
    public static string GetRandom()
    {
        return Quotes[Random.Shared.Next(Quotes.Length)];
    }

    /// <summary>
    /// Gets all available quotes.
    /// </summary>
    public static IReadOnlyList<string> All => Quotes;
}
