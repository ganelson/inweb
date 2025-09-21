Title: foundation
Author: Graham Nelson
Purpose: A library of utility functions for command-line tools.
Language: InC
Licence: Artistic License 2.0

Preliminaries
	A Brief Guide to Foundation

Chapter 1: Setting Up
"Absolute basics."
	Foundation Module
	POSIX Platforms ^"ifdef-PLATFORM_POSIX"
	Windows Platform ^"ifdef-PLATFORM_WINDOWS"

Chapter 2: Memory, Streams and Collections
"Creating objects in memory, and forming lists, hashes, and text streams."
	Debugging Log
	Memory
	Foundation Classes
	Locales
	Streams
	Writers and Loggers
	Methods
	Linked Lists and Stacks
	Dictionaries
	Trees

Chapter 3: The Operating System
"Dealing with the host operating system."
	Error Messages
	Command Line Arguments
	Pathnames
	Filenames
	Case-Insensitive Filenames
	Shell
	Directories
	Time

Chapter 4: Text Handling
"Reading, writing and parsing text."
	Characters
	C Strings
	Wide Strings
	String Manipulation
	Tab Stops
	Text Files
	Preprocessor
	Tries and Avinues
	Finite State Machines
	Pattern Matching
	JSON

Chapter 5: Generating Websites
"For making individual web pages, or gathering them into mini-sites or ebooks."
	HTML
	HTML Entities
	Markdown
	Markdown Phase I
	Markdown Phase II
	Markdown Rendering
	Markdown Variations
	Inform-Flavoured Markdown
	Epub Ebooks

Chapter 6: Media
"Examining image and sound files."
	Binary Files
	Image Dimensions
	Sound Durations

Chapter 7: Semantic Versioning
"For reading, storing and comparing standard semantic version numbers."
	Version Numbers
	Version Number Ranges
	Licence Data
	SPDX Licences

Chapter 8: Literate Programming
"Configuring LP syntax, parsing raw LP material, and tangling it."
	Web Structure
	Bibliographic Data for Webs
	Web Contents Pages
	Single-File Webs
	Web Modules
	Web Ranges
	Literate Source
	Line Classification
	Web Errors
	Web Syntax
	Holons
	Holon Syntax
	Tangle Targets
	The Tangler
	Build Files
	Web Control Language

Chapter 9: Programming
"Reading some basic syntax of different programming languages."
	Programming Languages
	Code Analysis
	Conditional Compilation
	Enumerated Constants
	Types and Functions
	Ctags Support
	Reserved Words
	The Painter
	Language Methods
	ACME Support
	C-Like Languages
	InC Support

Chapter 10: Weaving
"Weaving to a variety of different human-readable formats."
	Weaving Details
	The Swarm
	Patterns
	Assets, Plugins and Colour Schemes
	The Collater
	The Weaver
	The Weaver of Text
	Weave Tree
	Format Methods
	Plain Text Format
	TeX Format
	HTML Formats
	Debugging Format
	TeX Utilities

Chapter 11: Project Management
"Additional features for managing projects which may have multiple webs."
	Makefiles
	Git Support
	Readme Writeme
	Colonies
