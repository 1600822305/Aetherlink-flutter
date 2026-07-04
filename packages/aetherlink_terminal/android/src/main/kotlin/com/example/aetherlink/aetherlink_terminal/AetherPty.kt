package com.example.aetherlink.aetherlink_terminal

/**
 * JNI bindings for the PTY bridge (src/main/cpp/aether_pty.c). Used by
 * [AetherlinkTerminalPlugin] to run the PRoot shell on a real PTY — Dart's
 * Process.start only offers pipes, which breaks interactive shells.
 */
object AetherPty {
    init {
        System.loadLibrary("aether_pty")
    }

    /**
     * Forks and execs [cmd] on a fresh PTY. Returns the master fd; the child
     * pid is written to `processId[0]`.
     */
    external fun createSubprocess(
        cmd: String,
        cwd: String?,
        args: Array<String>,
        env: Array<String>,
        rows: Int,
        columns: Int,
        processId: IntArray,
    ): Int

    external fun setPtyWindowSize(fd: Int, rows: Int, columns: Int)

    /** Blocks until [pid] exits; returns its exit code (−signal when killed). */
    external fun waitFor(pid: Int): Int

    external fun kill(pid: Int)
}
