// Copyright © 2016-2017, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2010-2012, Jonathan M Davis.  All rights reserved.
// Copyright © 2010-2012, Kato Shoichi.  All rights reserved.
// See copyright notice in src/watt/license.volt (BOOST ver. 1.0).
/*!
 * Get precise timing information from the OS.
 */
module watt.io.monotonic;

import core.rt.misc : vrt_monotonic_ticks, vrt_monotonic_ticks_per_second;

/*!
 * How many ticks (from the `ticks` function) are in a second.
 */
global ticksPerSecond: i64;

/*!
 * Get the ticks from the OS in an `i64`.
 */
alias ticks = vrt_monotonic_ticks;

/*
 * Grabbed from druntime, good thing it's BOOST v1.0 as well.
 */

/*!
 * Convert a time from one frequency to another.
 * ### Example
 * ```volt
 * origin := ticks();
 * while (true) {
 *     now := ticks();
 *     delta := now - origin;
 *     ms := convClockFreq(delta, ticksPerSecond, 1000);
 *     writefln("%s milliseconds have passed.", ms);
 * }
 * ```
 * @Param ticks The ticks value to convert.
 * @Param srcTicksPerSecond The ticks per second of the @p ticks parameter.
 * @Param dstTicksPerSecond The ticks per second to convert @p ticks to.
 * @Returns The converted value.
 */
@safe pure nothrow
fn convClockFreq(ticks: i64, srcTicksPerSecond: i64, dstTicksPerSecond: i64) i64
{
	// This would be more straightforward with floating point arithmetic,
	// but we avoid it here in order to avoid the rounding errors that that
	// introduces. Also, by splitting out the units in this way, we're able
	// to deal with much larger values before running into problems with
	// integer overflow.
	return ticks / srcTicksPerSecond * dstTicksPerSecond +
		ticks % srcTicksPerSecond * dstTicksPerSecond / srcTicksPerSecond;
}

global this()
{
	ticksPerSecond = vrt_monotonic_ticks_per_second();
}
