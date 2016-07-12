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
	import core.posix.unistd;
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

	nativeID : NativeID;

public:
	this(NativeID nativeID)
	{
		this.nativeID = nativeID;
	}

	fn wait() int
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

fn wait(p : Pid) int
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

fn spawnProcess(name : string, args : string[]) Pid
{
	return spawnProcess(name, args, stdin, stdout, stderr, null);
}

fn spawnProcess(name : string, args : string[],
                _stdin : FILE*,
                _stdout : FILE*,
                _stderr : FILE*,
                env : Environment = null) Pid
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
		pid := spawnProcessPosix(cmd, args, stdinfd, stdoutfd, stderrfd, env);
	} else version (Windows) {
		pid := spawnProcessWindows(cmd, args, _stdin, _stdout, _stderr, env);
	}

	return new Pid(pid);
}

private {
	extern(C) fn getenv(ident : scope const(char)*) char*;
}

fn searchPath(cmd : string, path : string = null) string
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

fn getEnv(env : string) string
{
	ptr := getenv(env.ptr);
	if (ptr is null) {
		return null;
	} else {
		return cast(string)ptr[0 .. strlen(ptr)];
	}
}

fn system(name : string) int
{
	return csystem(toStringz(name));
}

version (Posix) private {

	extern(C) fn execv(const(char)*, const(char)**) int;
	extern(C) fn execve(const(char)*, const(char)**, const(char)**) int;
	extern(C) fn fork() pid_t;
	extern(C) fn dup(int) int;
	extern(C) fn dup2(int, int) int;
	extern(C) fn close(int) void;
	extern(C) fn waitpid(pid_t, int*, int) pid_t;

	fn spawnProcessPosix(name : string,
	                     args : string[],
	                     stdinFD : int,
	                     stdoutFD : int,
	                     stderrFD : int,
	                     env : Environment) int
	{
		argStack := new char[](16384);
		envStack := new char[](16384);
		argz := new char*[](4096);
		envz := new char*[](4096);
		if (env !is null) {
			toEnvz(envStack, envz, env);
		}

		toArgz(argStack, argz, name, args);

		pid := fork();
		if (pid != 0) {
			return pid;
		}

		// Child process

		// Redirect streams and close the old file descriptors.
		// In the case that stderr is redirected to stdout, we need
		// to backup the file descriptor since stdout may be redirected
		// as well.
		if (stderrFD == STDOUT_FILENO) {
			stderrFD = dup(stderrFD);
		}
		dup2(stdinFD,  STDIN_FILENO);
		dup2(stdoutFD, STDOUT_FILENO);
		dup2(stderrFD, STDERR_FILENO);

		// Close the old file descriptors, unless they are
		// either of the standard streams.
		if (stdinFD  > STDERR_FILENO) {
			close(stdinFD);
		}
		if (stdoutFD > STDERR_FILENO) {
			close(stdoutFD);
		}
		if (stderrFD > STDERR_FILENO) {
			close(stderrFD);
		}

		if (env is null) {
			execv(argz[0], argz.ptr);
		} else {
			execve(argz[0], argz.ptr, envz.ptr);
		}
		exit(-1);
		assert(false);
	}

	fn toArgz(stack : char[], result : char*[], name : string, args : string[]) void
	{
		resultPos : size_t;

		result[resultPos++] = stack.ptr;
		stack[0 .. name.length] = name;
		stack[name.length] = cast(char)0;

		stack = stack[name.length + 1u .. stack.length];

		foreach (arg; args) {
			result[resultPos++] = stack.ptr;

			stack[0 .. arg.length] = arg;
			stack[arg.length] = cast(char)0;

			stack = stack[arg.length + 1u .. stack.length];
		}

		// Zero the last argument.
		result[resultPos] = null;
	}

	fn toEnvz(stack : char[], result : char*[], env : Environment) void
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

	fn waitPosix(pid : pid_t) int
	{
		status : int;

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

	fn waitManyPosix(out pid : pid_t) int
	{
		status, result : int;

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

	fn stopped(status : int) bool { return (status & 0xff) == 0x7f; }
	fn signaled(status : int) bool { return ((((status & 0x7f) + 1) & 0xff) >> 1) > 0; }
	fn exited(status : int) bool { return (status & 0x7f) == 0; }

	fn termsig(status : int) int { return status & 0x7f; }
	fn exitstatus(status : int) int { return (status & 0xff00) >> 8; }

} else version (Windows) {

	extern (C) fn _fileno(FILE*) int;
	extern (C) fn _get_osfhandle(int) HANDLE;
	extern (Windows) fn GetStdHandle(const DWORD) HANDLE;
	
	fn toArgz(moduleName : string, args : string[]) LPSTR
	{
		buffer : char[];
		buffer ~= '"';
		foreach (arg; args) {
			buffer ~= "\" \"";
			buffer ~= cast(char[]) arg;
		}
		buffer ~= "\"\0";
		return buffer.ptr;
	}

	fn spawnProcessWindows(name : string, args : string[],
	                       stdinFP : FILE*,
	                       stdoutFP : FILE*,
	                       stderrFP : FILE*,
	                       env : Environment) HANDLE
	{
		fn stdHandle(file : FILE*, stdNo : DWORD) HANDLE {
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

	fn spawnProcessWindows(name : string, args : string[],
	                           hStdIn : HANDLE,
	                           hStdOut : HANDLE,
	                           hStdErr : HANDLE,
	                           env : Environment) HANDLE
	{
		si : STARTUPINFOA;
		si.cb = cast(DWORD) typeid(si).size;
		si.hStdInput  = hStdIn;
		si.hStdOutput = hStdOut;
		si.hStdError  = hStdErr;
		if ((si.hStdInput  !is null && si.hStdInput  !is cast(HANDLE)INVALID_HANDLE_VALUE) ||
		    (si.hStdOutput !is null && si.hStdOutput !is cast(HANDLE)INVALID_HANDLE_VALUE) ||
		    (si.hStdError  !is null && si.hStdError  !is cast(HANDLE)INVALID_HANDLE_VALUE)) {
			si.dwFlags = STARTF_USESTDHANDLES;
		}

		pi : PROCESS_INFORMATION;

		moduleName := name ~ '\0';
		bRet := CreateProcessA(moduleName.ptr, toArgz(moduleName, args), null, null, TRUE, 0, null, null, &si, &pi);
		if (bRet == 0) {
			throw new ProcessException("CreateProcess failed with error code " ~ toString(cast(int)GetLastError()));
		}
		CloseHandle(pi.hThread);
		return pi.hProcess;
	}

	fn waitWindows(handle : HANDLE) int
	{
		waitResult := WaitForSingleObject(handle, cast(uint) 0xFFFFFFFF);
		if (waitResult == cast(uint) 0xFFFFFFFF) {
			throw new ProcessException("WaitForSingleObject failed with error code " ~ toString(cast(int)GetLastError()));
		}
		retval : DWORD;
		result := GetExitCodeProcess(handle, &retval);
		if (result == 0) {
			throw new ProcessException("GetExitCodeProcess failed with error code " ~ toString(cast(int)GetLastError()));
		}

		CloseHandle(handle);
		return cast(int) retval;
	}
}