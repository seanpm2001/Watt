// Copyright © 2014-2015, Bernard Helyer.  // See copyright notice in src/watt/licence.volt (BOOST ver 1.0)
// String utilities.
module watt.text.string;

import watt.text.utf;

/**
 * Split string s by a given delimiter.
 * Examples:
 *   split("a=b", '=') ["a", "b"]
 *   split("a = b", '=') ["a ", " b"]
 *   split("a=b", '@') []
 */
string[] split(string s, dchar delimiter)
{
	if (s.length == 0) {
		return null;
	}
	string[] strings;
	size_t base, i, oldi;
	while (i < s.length) {
		oldi = i;
		if (decode(s, ref i) == delimiter) {
			strings ~= s[base .. oldi];
			base = i;
		}
	}
	strings ~= s[base .. $];
	return strings;
}

/**
 * Returns the index of the first place c occurs in str,
 * or -1 if it doesn't occur.
 */
ptrdiff_t indexOf(string s, dchar c)
{
	size_t i, oldi;
	while (i < s.length) {
		oldi = i;
		if (decode(s, ref i) == c) {
			if (oldi >= ptrdiff_t.max) {
				throw new Exception("indexOf: string too big.");
			}
			return cast(ptrdiff_t) oldi;
		}
	}
	return -1;
}

/**
 * If the substring sub occurs in s, returns the index where it occurs.
 * Otherwise, it returns -1.
 */
ptrdiff_t indexOf(string s, string sub)
{
	if (sub.length == 0) {
		return -1;
	}
	size_t i;
	while (i < s.length) {
		auto remaining = s.length - i;
		if (remaining < sub.length) {
			return -1;
		}
		if (s[i .. i + sub.length] == sub) {
			if (i >= ptrdiff_t.max) {
				throw new Exception("indexOf: string to big.");
			}
			return cast(ptrdiff_t) i;
		}
		decode(s, ref i);
	}
	return -1;
}

