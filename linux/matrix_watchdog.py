#!/usr/bin/env python3
"""matrix-watchdog: monitors matrix-keys.py and restarts on crash.

Runs as a background daemon, checking the hotkey listener PID every
CHECK_INTERVAL seconds. If the process is dead, restarts it.
Implements exponential backoff on repeated rapid failures.

Launched by: bluepill.sh, wakeupneo.sh
Logs to: $MATRIX_TMP/matrix-watchdog.log
"""

import os
import signal
import subprocess
import sys
import time

# Constants — per-user temp dir to avoid multi-user conflicts
MATRIX_TMP = f"/tmp/matrixshader-{os.getuid()}"
os.makedirs(MATRIX_TMP, exist_ok=True)
PIDFILE = f"{MATRIX_TMP}/matrix-keys.pid"
WATCHDOG_PIDFILE = f"{MATRIX_TMP}/matrix-watchdog.pid"
LOGFILE = f"{MATRIX_TMP}/matrix-watchdog.log"
MATRIX_KEYS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "matrix_keys.py")

CHECK_INTERVAL = 5      # seconds between health checks
MAX_RAPID_FAILURES = 3  # failures within RAPID_WINDOW trigger backoff
RAPID_WINDOW = 30       # seconds to count as "rapid"
BACKOFF_INTERVAL = 60   # seconds between checks after backoff


def log(msg):
    """Append a timestamped message to the log file."""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] {msg}\n"
    try:
        with open(LOGFILE, "a") as f:
            f.write(line)
    except OSError:
        pass


def is_process_alive(pid):
    """Check if process with given PID is running."""
    try:
        os.kill(pid, 0)
        return True
    except (OSError, ProcessLookupError):
        return False


def read_pid(path):
    """Read PID from pidfile, return None if invalid."""
    try:
        with open(path) as f:
            return int(f.read().strip())
    except (FileNotFoundError, ValueError):
        return None


def start_matrix_keys():
    """Start matrix_keys.py as a background process."""
    try:
        log_fh = open(f"{MATRIX_TMP}/matrix-keys.log", "a")
        env = os.environ.copy()
        env.setdefault("DBUS_SESSION_BUS_ADDRESS", f"unix:path=/run/user/{os.getuid()}/bus")
        subprocess.Popen(
            [sys.executable, MATRIX_KEYS],
            stdout=log_fh,
            stderr=subprocess.STDOUT,
            env=env,
        )
        log("Started matrix_keys.py")
        return True
    except (FileNotFoundError, OSError) as e:
        log(f"Failed to start matrix_keys.py: {e}")
        return False


def main():
    """Main watchdog loop: check PID, restart if dead, backoff on rapid failures."""
    import fcntl
    # Single-instance guard via flock (same pattern as matrix_keys.py)
    try:
        lock_fd = open(WATCHDOG_PIDFILE, "w")
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        lock_fd.write(str(os.getpid()))
        lock_fd.flush()
    except (IOError, OSError):
        # Another watchdog is running
        sys.exit(0)

    # Keep lock_fd open for lifetime (kernel releases on death)

    def cleanup(sig=None, frame=None):
        try:
            os.unlink(WATCHDOG_PIDFILE)
        except OSError:
            pass
        log("Watchdog stopped")
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    log("Watchdog started")

    failure_times = []
    interval = CHECK_INTERVAL

    while True:
        time.sleep(interval)

        pid = read_pid(PIDFILE)
        if pid is not None and is_process_alive(pid):
            # Process is alive -- reset backoff
            if interval != CHECK_INTERVAL:
                log("Process stable, resetting check interval")
                interval = CHECK_INTERVAL
            now = time.time()
            failure_times = [t for t in failure_times if now - t < RAPID_WINDOW]
            continue

        # Process is dead or PID file missing
        log(f"Process not running (pid={pid}), restarting...")

        now = time.time()
        failure_times.append(now)
        failure_times = [t for t in failure_times if now - t < RAPID_WINDOW]

        if len(failure_times) >= MAX_RAPID_FAILURES:
            log(f"Too many rapid failures ({len(failure_times)} in {RAPID_WINDOW}s), backing off to {BACKOFF_INTERVAL}s")
            interval = BACKOFF_INTERVAL
        else:
            interval = CHECK_INTERVAL

        start_matrix_keys()


if __name__ == "__main__":
    main()
