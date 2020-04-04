Title: inweb
Author: Graham Nelson
Purpose: A modern system for literate programming.
Language: InC
Web Syntax Version: 2
Licence: This is a free, open-source program published under the Artistic License 2.0.
Version Name: Escape to Danger
Version Number: 7

Import: foundation

Manual
	Introduction to Inweb
	Webs, Tangling and Weaving
	How to Write a Web
	The InC Dialect
	Advanced Weaving with Patterns
	Reference Card

Chapter 1: Top Level
"Dealing with the user, and deciding what is to be done."
	Basics
	Program Control
	Configuration
	Patterns

Chapter 2: Parsing a Web
"Reading in the entire text of the web, parsing its structure and looking for
identifier names within it."
	The Reader
	Line Categories
	The Parser
	Paragraph Macros
	Tags
	Enumerated Constants
	Paragraph Numbering

Chapter 3: Outputs
"Either weaving part or all of the web into a typeset form for human eyes
(or a swarm of many such parts), or tangling the web into an executable program,
or analysing the web to provide diagnostics on it."
	The Analyser
	The Swarm
	The Indexer
	The Weaver
	The Tangler

Chapter 4: Languages
"Providing support for syntax-colouring and for better organisation of code
in different programming languages."
	Programming Languages
	C-Like Languages
	InC Support
	Inform Support
	ACME Support

Chapter 5: Formats
"Weaving to a variety of different human-readable formats."
	Weave Formats
	Plain Text Format
	TeX Format
	HTML Formats
	Running Through TeX

Chapter 6: Extras
"Additional features for turning webs into open-source projects."
	Makefiles
	Git Support
	Readme Writeme
