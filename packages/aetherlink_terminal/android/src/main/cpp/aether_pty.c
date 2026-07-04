// Minimal PTY bridge for the built-in PRoot terminal (内置终端设计文档 §2.5).
// Dart's Process.start gives plain pipes only — an interactive shell needs a
// real PTY (prompt, line editing, TUI). This exposes exactly four calls to
// Kotlin (AetherPty.kt): createSubprocess / setPtyWindowSize / waitFor / kill.

#include <jni.h>

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

static jint throw_io(JNIEnv *env, const char *message) {
    jclass cls = (*env)->FindClass(env, "java/io/IOException");
    if (cls != NULL) (*env)->ThrowNew(env, cls, message);
    return -1;
}

// Opens a PTY pair, forks, and execs [cmd] with [args] / [envVars] inside the
// slave side. Returns the master fd; the child pid is written to processId[0].
JNIEXPORT jint JNICALL
Java_com_example_aetherlink_aetherlink_1terminal_AetherPty_createSubprocess(
    JNIEnv *env, jclass clazz, jstring cmd, jstring cwd, jobjectArray args,
    jobjectArray envVars, jint rows, jint columns, jintArray processId) {
    (void)clazz;

    int master = open("/dev/ptmx", O_RDWR | O_CLOEXEC);
    if (master < 0) return throw_io(env, "无法打开 /dev/ptmx");
    if (grantpt(master) != 0 || unlockpt(master) != 0) {
        close(master);
        return throw_io(env, "无法初始化 PTY");
    }
    char slave_name[64];
    if (ptsname_r(master, slave_name, sizeof(slave_name)) != 0) {
        close(master);
        return throw_io(env, "无法获取 PTY 从设备名");
    }

    struct winsize size = {.ws_row = (unsigned short)rows,
                           .ws_col = (unsigned short)columns};
    ioctl(master, TIOCSWINSZ, &size);

    const char *cmd_utf = (*env)->GetStringUTFChars(env, cmd, NULL);
    const char *cwd_utf =
        cwd == NULL ? NULL : (*env)->GetStringUTFChars(env, cwd, NULL);

    jsize arg_count = args == NULL ? 0 : (*env)->GetArrayLength(env, args);
    char **argv = calloc((size_t)arg_count + 2, sizeof(char *));
    argv[0] = strdup(cmd_utf);
    for (jsize i = 0; i < arg_count; i++) {
        jstring s = (jstring)(*env)->GetObjectArrayElement(env, args, i);
        const char *utf = (*env)->GetStringUTFChars(env, s, NULL);
        argv[i + 1] = strdup(utf);
        (*env)->ReleaseStringUTFChars(env, s, utf);
        (*env)->DeleteLocalRef(env, s);
    }

    jsize env_count = envVars == NULL ? 0 : (*env)->GetArrayLength(env, envVars);
    char **envp = calloc((size_t)env_count + 1, sizeof(char *));
    for (jsize i = 0; i < env_count; i++) {
        jstring s = (jstring)(*env)->GetObjectArrayElement(env, envVars, i);
        const char *utf = (*env)->GetStringUTFChars(env, s, NULL);
        envp[i] = strdup(utf);
        (*env)->ReleaseStringUTFChars(env, s, utf);
        (*env)->DeleteLocalRef(env, s);
    }

    pid_t pid = fork();
    if (pid < 0) {
        (*env)->ReleaseStringUTFChars(env, cmd, cmd_utf);
        if (cwd_utf != NULL) (*env)->ReleaseStringUTFChars(env, cwd, cwd_utf);
        close(master);
        return throw_io(env, "fork 失败");
    }
    if (pid == 0) {
        // Child: new session, slave PTY as controlling terminal + stdio.
        sigset_t signals;
        sigemptyset(&signals);
        sigprocmask(SIG_SETMASK, &signals, NULL);

        setsid();
        int slave = open(slave_name, O_RDWR);
        if (slave < 0) _exit(127);
        dup2(slave, STDIN_FILENO);
        dup2(slave, STDOUT_FILENO);
        dup2(slave, STDERR_FILENO);
        if (slave > STDERR_FILENO) close(slave);
        if (cwd_utf != NULL && chdir(cwd_utf) != 0) _exit(127);
        execve(argv[0], argv, envp);
        _exit(127);
    }

    // Parent.
    (*env)->ReleaseStringUTFChars(env, cmd, cmd_utf);
    if (cwd_utf != NULL) (*env)->ReleaseStringUTFChars(env, cwd, cwd_utf);
    for (char **p = argv; *p != NULL; p++) free(*p);
    free(argv);
    for (char **p = envp; *p != NULL; p++) free(*p);
    free(envp);

    jint pid_out = (jint)pid;
    (*env)->SetIntArrayRegion(env, processId, 0, 1, &pid_out);
    return master;
}

JNIEXPORT void JNICALL
Java_com_example_aetherlink_aetherlink_1terminal_AetherPty_setPtyWindowSize(
    JNIEnv *env, jclass clazz, jint fd, jint rows, jint columns) {
    (void)env;
    (void)clazz;
    struct winsize size = {.ws_row = (unsigned short)rows,
                           .ws_col = (unsigned short)columns};
    ioctl(fd, TIOCSWINSZ, &size);
}

// Blocks until [pid] exits; returns its exit code (or -signal when killed).
JNIEXPORT jint JNICALL
Java_com_example_aetherlink_aetherlink_1terminal_AetherPty_waitFor(JNIEnv *env,
                                                       jclass clazz,
                                                       jint pid) {
    (void)env;
    (void)clazz;
    int status;
    if (waitpid((pid_t)pid, &status, 0) < 0) return -errno;
    if (WIFEXITED(status)) return WEXITSTATUS(status);
    if (WIFSIGNALED(status)) return -WTERMSIG(status);
    return -1;
}

JNIEXPORT void JNICALL
Java_com_example_aetherlink_aetherlink_1terminal_AetherPty_kill(JNIEnv *env, jclass clazz,
                                                    jint pid) {
    (void)env;
    (void)clazz;
    // Negative pid = the whole process group (proot + its children).
    kill(-(pid_t)pid, SIGKILL);
    kill((pid_t)pid, SIGKILL);
}
