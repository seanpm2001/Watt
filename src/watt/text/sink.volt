// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/watt/licence.volt (BOOST ver 1.0).
//! A sink that deals with strings.
module watt.text.sink;

static import core.rt.format;


//! The one true sink definition.
alias Sink = core.rt.format.Sink;

//! The argument to the one true sink.
alias SinkArg = core.rt.format.SinkArg;

//! A sink to create long strings.
struct StringSink
{
private:
	mStore: char[1024];
	mArr: char[];
	mLength: size_t;

	enum size_t minSize = 16;
	enum size_t maxSize = 2048;

public:
	//! Add @p str to this sink.
	fn sink(str: SinkArg) void
	{
		newSize := str.length + mLength;
		if (mArr.length == 0) {
			mArr = mStore[..];
		}

		if (newSize <= mArr.length) {
			mArr[mLength .. newSize] = str[..];
			mLength = newSize;
			return;
		}

		allocSize := mArr.length;
		while (allocSize < newSize) {
			if (allocSize < minSize) {
				allocSize = minSize;
			} else if (allocSize >= maxSize) {
				allocSize += maxSize;
			} else {
				allocSize = allocSize * 2;
			}
		}

		n := new char[](newSize + 256);
		n[0 .. mLength] = mArr[0 .. mLength];
		n[mLength .. newSize] = str[..];
		mLength = newSize;
		mArr = n;
	}

	//! Get the contents of this sink as a string.
	fn toString() string
	{
		return new string(mArr[0 .. mLength]);
	}

	//! Get the contents of this sink as a mutable array of characters.
	fn toChar() char[]
	{
		return new char[](mArr[0 .. mLength]);
	}

	/*!
	 * Safely get the backing storage from the sink without coping.
	 */
	fn toSink(sink: Sink) void
	{
		return sink(mArr[0 .. mLength]);
	}

	//! Clear this sink.
	fn reset() void
	{
		mArr = null;
		mLength = 0;
	}
}
