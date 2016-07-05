// Copyright © 2013, Jakob Bornecrantz.
// Copyright © 2013, Bernard Helyer.
// See copyright notice in src/watt/licence.volt (BOOST ver 1.0).
module watt.process.spawn;

version (Windows || Posix):

import core.exception;
import core.stdc.stdlib : csystem = system, exit;
import core.stdc.string : strlen;
import core.stdc.stdio;

version (Windows) {
	import core.windows.windows;
} else version (Posix) {
	import core.posix.sys.types : pid_t;
}

import watt.process.environment;
import watt.text.string : split;
import watt.io.file : exists;
import watt.path : dirSeparator, pathSeparator;
import watt.conv;


class Pid
{
public:
	version (Windows) {
		alias NativeID = HANDLE;
		alias _handle = nativeID;
	} else version (Posix) {
		alias NativeID = pid_t;
		alias _pid = nativeID;
	} else {
		alias NativeID = int;
	}

	NativeID nativeID;

public:
	this(NativeID nativeID)
	{
		this.nativeID = nativeID;
	}

	int wait()
	{
		version (Posix) {
			return waitPosix(nativeID);
		} else version (Windows) {
			return waitWindows(nativeID);
		} else {
			return -1;
		}
	}
}

int wait(Pid p)
{
	return p.wait();
}

class ProcessException : Exception
{
	this(string msg)
	{
		super(msg);
	}
}

Pid spawnProcess(string name, string[] args)
{
	return spawnProcess(name, args, stdin, stdout, stderr, null);
}

Pid spawnProcess(string name, string[] args,
                 FILE* _stdin,
                 FILE* _stdout,
                 FILE* _stderr,
                 Environment env = null)
{
	if (name is null) {
		throw new ProcessException("Name can not be null");
	}

	cmd : string;
	if (exists(name)) {
		cmd = name;
	} else {
		cmd = searchPath(name);
	}

	if (cmd is null) {
		throw new ProcessException("Can not find command " ~ name);
	}

	version (Posix) {
		stdinfd := _stdin is null ? fileno(stdin) : fileno(_stdin);
		stdoutfd := _stdout is null ? fileno(stdout) : fileno(_stdout);
		stderrfd := _stderr is null ? fileno(stderr) : fileno(_stderr);
		auto pid = spawnProcessPosix(cmd, args, stdinfd, stdoutfd, stderrfd, env);
	} else version (Windows) {
		auto pid = spawnProcessWindows(cmd, args, _stdin, _stdout, _stderr, env);
	} else {
		int pid;
	}

	return new Pid(pid);
}

private {
	extern(C) char* getenv(in char*);
}

string searchPath(string cmd, string path = null)
{
	if (path is null) {
		path = getEnv("PATH");
	}
	if (path is null) {
		return null;
	}

	assert(pathSeparator.length == 1);

	foreach (p; split(path, pathSeparator[0])) {
		t := p ~ dirSeparator ~ cmd;
		if (exists(t)) {
			return t;
		}
	}

	return null;
}

string getEnv(string env)
{
	auto ptr = getenv(env.ptr);
	if (ptr is null) {
		return null;
	} else {
		return cast(string)ptr[0 .. strlen(ptr)];
	}
}

int system(string name)
{
	return csystem(toStringz(name));
}

version (Posix) private {

	extern(C) int execv(const(char)* file, const(char)** argv);
	extern(C) int execve(const(char)* file, const(char)** argv, const(char)** env);
	extern(C) pid_t fork();
	extern(C) int dup(int);
	extern(C) int dup2(int, int);
	extern(C) void close(int);
	extern(C) pid_t waitpid(pid_t, int*, int);

	int spawnProcessPosix(string name,
	                      string[] args,
	                      int stdinFD,
	                      int stdoutFD,
	                      int stderrFD,
	                      Environment env)
	{
		char[] argStack = new char[](16384);
		char[] envStack = new char[](16384);
		char*[] argz = new char*[](4096);
		char*[] envz = new char*[](4096);
		if (env !is null) {
			toEnvz(envStack, envz, env);
		}

		// Remove these when enums work.
		int STDIN_FILENO = 0;
		int STDOUT_FILENO = 1;
		int STDERR_FILENO = 2;

		toArgz(argStack, argz, name, args);

		auto pid = fork();
		if (pid != 0)
			return pid;

		// Child process

		// Redirect streams and close the old file descriptors.
		// In the case that stderr is redirected to stdout, we need
		// to backup the file descriptor since stdout may be redirected
		// as well.
		if (stderrFD == STDOUT_FILENO)
			stderrFD = dup(stderrFD);
		dup2(stdinFD,  STDIN_FILENO);
		dup2(stdoutFD, STDOUT_FILENO);
		dup2(stderrFD, STDERR_FILENO);

		// Close the old file descriptors, unless they are
		// either of the standard streams.
		if (stdinFD  > STDERR_FILENO)
			close(stdinFD);
		if (stdoutFD > STDERR_FILENO)
			close(stdoutFD);
		if (stderrFD > STDERR_FILENO)
			close(stderrFD);

		if (env is null) {
			execv(argz[0], argz.ptr);
		} else {
			execve(argz[0], argz.ptr, envz.ptr);
		}
		exit(-1);
		assert(false);
	}

	void toArgz(char[] stack, char*[] result, string name, string[] args)
	{
		size_t resultPos;

		result[resultPos++] = stack.ptr;
		stack[0 .. name.length] = name;
		stack[name.length] = cast(char)0;

		stack = stack[name.length + 1u .. stack.length];

		for (uint i; i < args.length; i++) {
			result[resultPos++] = stack.ptr;

			auto arg = args[i];
			stack[0 .. arg.length] = arg;
			stack[arg.length] = cast(char)0;

			stack = stack[arg.length + 1u .. stack.length];
		}

		// Zero the last argument.
		result[resultPos] = null;
	}

	void toEnvz(char[] stack, char*[] result, Environment env)
	{
		start, end, resultPos : size_t;

		foreach (k, v; env.store) {
			start = end;
			end = start + k.length;
			stack[start .. end] = k;
			stack[end++] = '=';

			result[resultPos++] = &stack[start];

			if (v.length) {
				start = end;
				end = start + v.length;
				stack[start .. end] = v;
			}
			stack[end++] = '\0';
		}
		result[resultPos] = null;
	}

	int waitPosix(pid_t pid)
	{
		int status;

		// Because stopped processes doesn't count.
		while(true) {
			pid = waitpid(pid, &status, 0);

			if (exited(status)) {
				return exitstatus(status);
			} else if (signaled(status)) {
				return -termsig(status);
			} else if (stopped(status)) {
				continue;
			} else {
				return -1;//errno();
			}
		}
		assert(false);
	}

	int waitManyPosix(out pid_t pid)
	{
		int status, result;

		// Because stopped processes doesn't count.
		while(true) {
			pid = waitpid(-1, &status, 0);

			if (exited(status)) {
				result = exitstatus(status);
			} else if (signaled(status)) {
				result = -termsig(status);
			} else if (stopped(status)) {
				continue;
			} else {
				result = -1; // TODO errno
			}

			return result;
		}
		assert(false);
	}

	bool stopped(int status)  { return (status & 0xff) == 0x7f; }
	bool signaled(int status) { return ((((status & 0x7f) + 1) & 0xff) >> 1) > 0; }
	bool exited(int status)   { return (status & 0x7f) == 0; }

	int termsig(int status)    { return status & 0x7f; }
	int exitstatus(int status) { return (status & 0xff00) >> 8; }

} else version (Windows) {

	extern (C) int _fileno(FILE* stream);
	extern (C) HANDLE _get_osfhandle(int fd);
	extern (Windows) HANDLE GetStdHandle(const DWORD noStdHandle);
	
	LPSTR toArgz(string moduleName, string[] args)
	{
		char[] buffer;
		buffer ~= '"';
		for (size_t i = 0; i < args.length; i++) {
			buffer ~= "\" \"";
			buffer ~= cast(char[]) args[i];
		}
		buffer ~= "\"\0";
		return buffer.ptr;
	}

	HANDLE spawnProcessWindows(string name, string[] args,
	                           FILE* stdinFP,
	                           FILE* stdoutFP,
	                           FILE* stderrFP,
	                           Environment env)
	{
		HANDLE stdHandle(FILE* file, DWORD stdNo) {
			if (file !is null) {
				h := _get_osfhandle(_fileno(file));
				if (h !is cast(HANDLE)INVALID_HANDLE_VALUE) {
					return h;
				}
			}
			h := GetStdHandle(stdNo);
			if (h is cast(HANDLE)INVALID_HANDLE_VALUE) {
				throw new ProcessException("Couldn't get standard handle.");
			}
			return h;
		}

		hStdInput  := stdHandle(stdinFP,  STD_INPUT_HANDLE);
		hStdOutput := stdHandle(stdoutFP, STD_OUTPUT_HANDLE);
		hStdError  := stdHandle(stderrFP, STD_ERROR_HANDLE);

		return spawnProcessWindows(name, args, hStdInput, hStdOutput, hStdError, env);
	}

	HANDLE spawnProcessWindows(string name, string[] args,
	                           HANDLE hStdIn,
	                           HANDLE hStdOut,
	                           HANDLE hStdErr,
	                           Environment env)
	{
		STARTUPINFOA si;
		si.cb = cast(DWORD) typeid(si).size;
		si.hStdInput  = hStdIn;
		si.hStdOutput = hStdOut;
		si.hStdError  = hStdErr;
		if ((si.hStdInput  !is null && si.hStdInput  !is cast(HANDLE)INVALID_HANDLE_VALUE) ||
		    (si.hStdOutput !is null && si.hStdOutput !is cast(HANDLE)INVALID_HANDLE_VALUE) ||
		    (si.hStdError  !is null && si.hStdError  !is cast(HANDLE)INVALID_HANDLE_VALUE)) {
			si.dwFlags = STARTF_USESTDHANDLES;
		}

		PROCESS_INFORMATION pi;

		auto moduleName = name ~ '\0';
		BOOL bRet = CreateProcessA(moduleName.ptr, toArgz(moduleName, args), null, null, TRUE, 0, null, null, &si, &pi);
		if (bRet == 0) {
			throw new ProcessException("CreateProcess failed with error code " ~ toString(cast(int)GetLastError()));
		}
		CloseHandle(pi.hThread);
		return pi.hProcess;
	}

	int waitWindows(HANDLE handle)
	{
		DWORD waitResult = WaitForSingleObject(handle, cast(uint) 0xFFFFFFFF);
		if (waitResult == cast(uint) 0xFFFFFFFF) {
			throw new ProcessException("WaitForSingleObject failed with error code " ~ toString(cast(int)GetLastError()));
		}
		DWORD retval;
		BOOL result = GetExitCodeProcess(handle, &retval);
		if (result == 0) {
			throw new ProcessException("GetExitCodeProcess failed with error code " ~ toString(cast(int)GetLastError()));
		}

		CloseHandle(handle);
		return cast(int) retval;
	}
}
