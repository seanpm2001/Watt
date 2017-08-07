// Copyright © 2016-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/watt/licence.volt (BOOST ver 1.0).
//! Parse markdown.
module watt.markdown;

import watt.text.sink : Sink;

import watt.markdown.parser;
import watt.markdown.html;


/*!
 * Given a markdown string, return a string of HTML.
 */
fn filterMarkdown(src: string) string
{
	doc := parse(src);
	return printHtml(doc);
}

/*!
 * Given a markdown string, put a string of HTML in `sink`.
 */
fn filterMarkdown(sink: Sink, src: string)
{
	doc := parse(src);
	printHtml(doc, sink);
}