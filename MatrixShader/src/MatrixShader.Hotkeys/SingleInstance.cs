namespace MatrixShader.Hotkeys;

/// <summary>
/// Enforces single-instance execution using a named mutex.
/// Uses Global\ prefix for system-wide scope across all sessions.
/// </summary>
public sealed class SingleInstance : IDisposable
{
    // Unique GUID for Matrix Hotkeys process
    // Global\ prefix ensures mutex is visible across all user sessions
    private const string MutexName = @"Global\{B8C3F9A2-7D4E-4A1B-9C6D-3E8F5A2B1C0D}-MatrixHotkeys";

    private Mutex? _mutex;
    private bool _hasHandle;
    private bool _disposed;

    /// <summary>
    /// Indicates whether this instance successfully acquired the mutex.
    /// </summary>
    public bool IsFirstInstance => _hasHandle;

    /// <summary>
    /// Attempts to acquire the single-instance mutex.
    /// </summary>
    /// <returns>True if this is the first instance, false if another instance is running.</returns>
    public bool TryAcquire()
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(SingleInstance));

        if (_mutex != null)
            return _hasHandle;

        try
        {
            // Create or open the named mutex
            // initiallyOwned = true attempts to acquire immediately
            _mutex = new Mutex(initiallyOwned: true, MutexName, out bool createdNew);

            if (createdNew)
            {
                // We created the mutex, so we own it
                _hasHandle = true;
                return true;
            }
            else
            {
                // Mutex already exists - another instance is running
                // Try to acquire it briefly in case the other instance is exiting
                try
                {
                    _hasHandle = _mutex.WaitOne(TimeSpan.FromMilliseconds(100), exitContext: false);
                }
                catch (AbandonedMutexException)
                {
                    // Previous instance crashed without releasing mutex
                    // We now own it
                    _hasHandle = true;
                }

                return _hasHandle;
            }
        }
        catch (UnauthorizedAccessException)
        {
            // Cannot access the mutex (could be created by elevated process)
            // Assume another instance is running
            return false;
        }
    }

    /// <summary>
    /// Releases the single-instance mutex.
    /// </summary>
    public void Release()
    {
        if (_hasHandle && _mutex != null)
        {
            try
            {
                _mutex.ReleaseMutex();
            }
            catch (ApplicationException)
            {
                // Mutex was not owned by this thread
            }
            _hasHandle = false;
        }
    }

    /// <summary>
    /// Disposes the mutex resource.
    /// </summary>
    public void Dispose()
    {
        if (_disposed)
            return;

        _disposed = true;
        Release();
        _mutex?.Dispose();
        _mutex = null;
    }
}
