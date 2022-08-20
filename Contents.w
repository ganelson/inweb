Title: inweb
Author: Graham Nelson
Purpose: A modern system for literate programming.
Language: InC
Web Syntax Version: 2
Licence: This is a free, open-source program published under the Artistic License 2.0.
Version Name: Escape to Danger
Version Number: 7.1.1

Import: foundation

Manual
	Introduction to Inweb
	Webs, Tangling and Weaving
	How to Write a Web
	Making Weaves into Websites
	Advanced Weaving with Patterns
	Supporting Programming Languages
	The InC Dialect
	Reference Card

Preliminaries
	How This Program Works

Chapter 1: Top Level
"Dealing with the user, and deciding what is to be done."
	Basics
	Program Control
	Configuration
	The Swarm
	Patterns
	Assets, Plugins and Colour Schemes

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
	The Collater
	The Weaver
	The Weaver of Text
	The Tangler

Chapter 4: Languages
"Providing support for syntax-colouring and for better organisation of code
in different programming languages."
	Programming Languages
	Types and Functions
	Language Methods
	ACME Support
	The Painter
	C-Like Languages
	InC Support

Chapter 5: Formats
"Weaving to a variety of different human-readable formats."
	Weave Tree
	Format Methods
	Plain Text Format
	TeX Format
	HTML Formats
	Debugging Format
	TeX Utilities

Chapter 6: Extras
"Additional features for turning webs into open-source projects."
	Makefiles
	Git Support
	Ctags Support
	Readme Writeme
	Colonies

