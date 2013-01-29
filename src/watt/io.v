module watt.io;

import core.stdc.stdio;

/**
 * OutputStreams write data to some sink (a file, a console, etc)
 * in characters.
 */
class OutputStream
{
	/**
	 * Write a single character out to the sink.
	 */
	void put(dchar c)
	{
		return;
	}

	/**
	 * Write a series of characters to the sink.
	 */
	void write(const(char)[] s)
	{
		for (size_t i = 0u; i < s.length; i = i + 1u) {
			put(s[i]);
		}
		return;
	}

	/**
	 * Write a series of characters then a newline.
	 */
	void writeln(const(char)[] s)
	{
		write(s);
		put('\n');
		return;
	}

	/**
	 * After this call has completed, the state of this stream's
	 * sink should match the data committed to it.
	 */
	void flush()
	{
		return;
	}
}

/**
 * InputStreams read data from some source (a file, a device, etc)
 */
class InputStream
{
	/**
	 * Read a single character from the source.
	 */
	dchar get()
	{
		return cast(dchar) -1;
	}

	/**
	 * Returns true if the stream indicates that there is no more data.
	 * This may never be true, depending on the source.
	 */ 
	bool eof()
	{
		return true;
	}
}


/**
 * An OutputStream in which the sink is a file.
 */
class OutputFileStream : OutputStream
{
	FILE* handle;

	this(const(char)[] filename)
	{
		if (filename.length > 0u) {
			handle = fopen(filename.ptr, "w".ptr);
		}
		return;
	}

	void put(dchar c)
	{
		fputc(cast(int) c, handle);
		return;
	}

	/**
	 * Close the underlying file handle.
	 */
	void close()
	{
		fclose(handle);
		handle = null;
		return;
	}
}

/**
 * An InputStream in which the source is a file.
 */
class InputFileStream : InputStream
{
	FILE* handle;

	this(const(char)[] filename)
	{
		if (filename.length > 0u) {
			handle = fopen(filename.ptr, "r".ptr);
		}
		return;
	}

	bool eof()
	{
		return feof(handle) != 0;
	}

	dchar get()
	{
		return cast(dchar) fgetc(handle);
	}

	/**
	 * Close the underlying file handle.
	 */
	void close()
	{
		fclose(handle);
		handle = null;
		return;
	}
}

global OutputFileStream output;
global OutputFileStream error;
global InputFileStream input;

void init()
{
	output = new OutputFileStream(null);
	output.handle = stdout;
	error = new OutputFileStream(null);
	error.handle = stderr;
	input = new InputFileStream(null);
	input.handle = stdin;
	return;
}
