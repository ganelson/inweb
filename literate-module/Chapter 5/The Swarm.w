[Swarm::] The Swarm.

To feed multiple output requests to the weaver, and to present
weaver results, and update indexes or contents pages.

@h How weaves are performed.
Weaves are highly comfigurable, so they depend on several factors:
(a) Which format is used, as represented by a //weave_format// object. For
example, HTML, ePub and PDF are all formats.
(b) Which pattern is used, as represented by a //ls_pattern// object. A
pattern is a choice of format together with some naming conventions and
auxiliary files. For example, |GitHubPages| is a pattern which imposes HTML
format but also throws in, for example, the GitHub logo icon.
(c) Whether a filter to particular tags is used.
(d) What subset of the web the user wants to weave -- by default the whole
thing, but sometimes just one chapter, or just one section, and sometimes
a special setting for "do all chapters one at a time" or "do all sections
one at a time", a procedure called a "swarm".

@ We provide two entry points to make weaves happen: the caller should choose
either //Swarm::weave_subset// for a single subset of the web, going into a
single output file, or //Swarm::weave_swarm// for a collection of subsets. (And
//Swarm::weave_swarm// then calls //Swarm::weave_subset// multiple times to do this.)

//Swarm::weave_swarm// also causes an "index" to be made, though "index" here is
Inweb jargon for something which is more likely a contents page listing the
sections and linking to them.[1]

Either way, each single weaving operation arrives at //Swarm::weave_subset//,
which consolidates all the settings needed into a //weave_order// object:
it says, in effect, "weave content X into file Y using pattern Z".

[1] No index is made if the user asked for only a single section or chapter
to be woven; only if there was a swarm.

@ As we will see, //Swarm::weave_subset// then creates a "weave order" and
hands it out to the function //Weaver::weave//.[1] This in turn produces a
"weave tree" which amounts to a format-neutral list of rendering instructions:
which tree is passed to //WeavingFormats::render// for the actual writing of
output. In this way, specifics of individual output formats are kept at arm's
length from the actual weaving algorithm.

The weave tree is a simple business, built in a single pass of a depth-first
traverse of the web. The weaver keeps track of a modicum of "state" as it works,
and these running details are stored in a //weaver_state// object, but this is
thrown away as soon as the weaver finishes.

The trickiest point of building the weave tree is done by //The Weaver of Text//,
which breaks up lines of commentary or code to identify uses of mathematical
notation, footnote cues, function calls, and so on.

This is a "heterogeneous tree", in that its nodes are annotated
by data structures of different types. For example, a node for a section
heading is annotated with a //weave_section_header_node// structure. The
necessary types and object constructors are laid tediously out in
//Weave Tree//, a section which intentionally contains no non-trivial code.

[1] "Weaver, weave" really ought to be a folk song, but if so, I can't find
it on Spotify.

@ Syntax-colouring is worth further mention. Just as the Weaver tries not to
get itself into fiddly details of formats, it also avoids specifics of
programming languages. It does this by calling //LanguageMethods::syntax_colour//,
which in turn calls the |SYNTAX_COLOUR_WEA_MTID| method for the relevant
instance of //programming_language//. In effect the weaver sends a snippet
of code and asks to be told how it's to be coloured: not in terms of green
vs blue, but in terms of |IDENTIFIER_COLOUR| vs |RESERVED_COLOUR| and so on.

Thus, the object representing "the C programming language" can in principle
choose any semantic colouring that it likes. In practice, if (as is usual) it
assigns no particular code to this, what instead happens is that the generic
handler function in //ACME Support// takes on the task.[1] This runs the
colouring program in the language's definition file. Colouring programs are,
in effect, a mini-language of their own, which is compiled by
//Programming Languages// and then run in a low-level interpreter by
//The Painter//.

[1] "ACME" is used here in the sense of "generic".

@ So, then, the weave tree is now made. Just as each programming language
has an object representing it, so does each format, and at render time the
method call |RENDER_FOR_MTID| is sent to it. This has to turn the tree into
HTML, plain text, TeX source, or whatever may be. It's understood that not
every rendering instruction in the weave tree can be fully followed in every
format: for example, there's not much that plain text can do to render an
image carousel.

Inweb currently contains four renderers:
(a) //Debugging Format// renders the weave tree as a plain text display, and
is solely for testing.
(b) //TeX Format// renders the weave tree as TeX markup code -- in the early
days of literate programming, this was the sole weave format used; now it
has been eclipsed by...
(c) ...//HTML Formats//, which renders to HTML and also handles ePub ebooks.
(d) There is also //Plain Text Format//, a comically minimal approach.

Renderers should make requests for weave plugins or colour schemes if, and
only if, the need arises: for example, the HTML renderer requests the plugin
|Carousel| only if an image carousel is actually called for. Requests are
made by calling //Swarm::ensure_plugin// or //Swarm::ensure_colour_scheme//,
and see also the underlying code at //Assets, Plugins and Colour Schemes//.
(We want our HTML to run as little JavaScript as necessary at load time, which
is why we don't just give every weave every possible facility.)

The most complex issue for HTML rendering is working out the URLs for links:
for example, when weaving the text you are currently reading, Inweb has to
decide where to send //weave_order//. This is handled by a suite of useful
functions in //Colonies// which coordinate URLs across websites so
that one web's weave can safely link to another's. In particular, cross-references
written in |//this notation//| are "resolved" by //Colonies::resolve_reference_in_weave//,
and the function //Colonies::reference_URL// turns them into relative URLs
from any given file. Within the main web being woven, //Colonies::paragraph_URL//
can make a link to any paragraph of your choice.[1]

[1] Inweb anchors at paragraphs; it does not anchor at individual lines.
This is intentional, as it's intended to take the reader to just enough
context and explanation to understand what is being linked to.

@ Finally on weaving, special mention should go to //The Collater//, a
subsystem which amounts to a stream editor. Its role is to work through a
"template" and substitute in material from outside -- from the weave rendering,
from the bibliographic data for a web, and so on -- to produce a final file.
For example, a simple use of the collater is to work through the template:
= (text)
	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
	<html>
		<head>
			<title>[[Booklet Title]]</title>
			[[Plugins]]
		</head>
		<body>
	[[Weave Content]]
		</body>
	</html>
=
and to collate material already generated by other parts of Inweb to fill the
double-squared placeholders, such as |[[Plugins]]|. The Collater, in fact,
is ultimately what generates all of the files made in a weave, even though
other parts of Inweb did all of the real work.

With that said, it's not a trivial algorithm, because it can also loop through
chapters and sections, as it does when it generates an index page to accompany
a swarm of individual section weaves. The contents pages for typical webs
presented online are made this way. The Collater is also recursive, in that
some collation commands call for further acts of collation to happen inside
the original. See //Collater::collate// for the machinery.

@h Weave reporting.
This is more fiddly than it first appears to be: it's a challenge to produce
the right amount of output here. Small webs and large webs have different needs.

=
typedef struct weave_reporting {
	struct text_stream *OUT;
	struct ls_web *W;
	int verbose;
	struct pathname *last_reported_weave_path;
	int file_weaving_reports_made;
	struct linked_list *files_copied; /* of |weave_copy_record| */
	struct linked_list *plugins_copied; /* of |weave_plugin| */
} weave_reporting;

typedef struct weave_copy_record {
	struct text_stream *filename_text;
	struct text_stream *pathname_text;
	int noted;
	CLASS_DEFINITION
} weave_copy_record;

weave_reporting Swarm::new_reportage(OUTPUT_STREAM, ls_web *W, int verbose_mode) {
	weave_reporting R;
	R.OUT = OUT;
	R.W = W;
	R.verbose = verbose_mode;
	R.last_reported_weave_path = NULL;
	R.file_weaving_reports_made = 0;
	R.files_copied = NEW_LINKED_LIST(weave_copy_record);
	R.plugins_copied = NEW_LINKED_LIST(weave_plugin);
	return R;
}

void Swarm::begin_report_run(weave_reporting *R) {
	if (R) {
		R->last_reported_weave_path = NULL;
		R->file_weaving_reports_made = 0;
	} else internal_error("no weave reporting");
}

int Swarm::report_copy(weave_reporting *R, filename *F, pathname *P, int creating) {
	int copy_needed = TRUE;
	if (R) {
		TEMPORARY_TEXT(file_text)
		TEMPORARY_TEXT(path_text)
		WRITE_TO(file_text, "%f", F);
		WRITE_TO(path_text, "%p", P);
		
		weave_copy_record *wcr;
		LOOP_OVER_LINKED_LIST(wcr, weave_copy_record, R->files_copied)
			if ((Str::eq(file_text, wcr->filename_text)) &&
				(Str::eq(path_text, wcr->pathname_text))) {
				copy_needed = FALSE;
				break;
			}
		if (copy_needed) {
			wcr = CREATE(weave_copy_record);
			wcr->filename_text = Str::duplicate(file_text);
			wcr->pathname_text = Str::duplicate(path_text);
			wcr->noted = FALSE;
			ADD_TO_LINKED_LIST(wcr, weave_copy_record, R->files_copied);
		}
		DISCARD_TEXT(file_text)
		DISCARD_TEXT(path_text)
		
		if (copy_needed) {
			text_stream *OUT = R->OUT;
			if (R->verbose) {
				if (creating) WRITE("Creating %p\n", P);
				WRITE("Copy asset %f -> %p\n", F, P);
			} else {
				if (creating) WRITE("created: %p\n", P);
			}
		}
	} else internal_error("no weave reporting");
	return copy_needed;
}

void Swarm::report_embedding(weave_reporting *R, filename *F) {
	if (R) {
		text_stream *OUT = R->OUT;
		if (R->verbose) WRITE("Embed asset %f\n", F);
	} else internal_error("no weave reporting");
}

void Swarm::report_collation(weave_reporting *R, filename *F) {
	if (R) {
		text_stream *OUT = R->OUT;
		if (R->verbose) WRITE("Collate asset %f\n", F);
	} else internal_error("no weave reporting");
}

void Swarm::report_woven_file(weave_reporting *R, filename *F, weave_order *wv) {
	if (R) {
		text_stream *OUT = R->OUT;
		if (R->verbose) {
			if (wv) WRITE("    [%S -> ", wv->booklet_title);
			else WRITE("    [");
			pathname *P = Filenames::up(F);
			if (Pathnames::resemble(P, R->last_reported_weave_path) == FALSE) WRITE("%f", F);
			else WRITE("... %S", Filenames::get_leafname(F));
			R->last_reported_weave_path = P;
			if (wv) WeavingFormats::report_on_post_processing(wv);
			WRITE("]\n");
		} else {
			if (R->W->single_file) {
				WRITE("    generated: %f\n", F);
			} else {
				if (R->file_weaving_reports_made == 0) WRITE("    ");
				WRITE("[");
				pathname *P = Filenames::up(F);
				if (Pathnames::resemble(P, R->last_reported_weave_path) == FALSE) WRITE("%f", F);
				else Filenames::write_unextended_leafname(OUT, F);
				R->last_reported_weave_path = P;
				if (wv) WeavingFormats::report_on_post_processing(wv);
				WRITE("] ");
				R->file_weaving_reports_made++;
			}
		}
	} else internal_error("no weave reporting");
}

void Swarm::report_plugin(weave_reporting *R, weave_plugin *wp) {
	if (R) {
		weave_plugin *wp2;
		LOOP_OVER_LINKED_LIST(wp2, weave_plugin, R->plugins_copied)
			if (wp2 == wp)
				return;
		ADD_TO_LINKED_LIST(wp, weave_plugin, R->plugins_copied);
		text_stream *OUT = R->OUT;
		if (R->verbose) WRITE("Include plugin '%S'\n", wp->plugin_name);
	} else internal_error("no weave reporting");
}

void Swarm::report_colour_scheme(weave_reporting *R, colour_scheme *cs) {
	if (R) {
		text_stream *OUT = R->OUT;
		if (R->verbose) WRITE("Include colour scheme '%S'\n", cs->scheme_name);
	} else internal_error("no weave reporting");
}

void Swarm::report_empty_warning(weave_reporting *R, text_stream *tag) {
	if (R) {
		text_stream *OUT = R->OUT;
		WRITE("    warning: no paragraphs were tagged '%S', so weave was empty\n", tag);
	} else internal_error("no weave reporting");
}

void Swarm::end_report_run(weave_reporting *R) {
	if (R) {
		if (R->file_weaving_reports_made > 0) {
			WRITE_TO(R->OUT, "\n");
			R->file_weaving_reports_made = 0;
		}
	} else internal_error("no weave reporting");
}

void Swarm::end_report(weave_reporting *R) {
	if (R) {
		text_stream *OUT = R->OUT;
		int NC = LinkedLists::len(R->files_copied);
		int NP = LinkedLists::len(R->plugins_copied);
		Swarm::end_report_run(R);
		if (NC > 0) {
			weave_copy_record *wcr;
			LOOP_OVER_LINKED_LIST(wcr, weave_copy_record, R->files_copied)
				if (wcr->noted == FALSE) {
					int n = 0;
					weave_copy_record *wcr2;
					LOOP_OVER_LINKED_LIST(wcr2, weave_copy_record, R->files_copied)
						if ((wcr2->noted == FALSE) &&
							(Str::eq(wcr->pathname_text, wcr2->pathname_text))) {
							n++; wcr2->noted = TRUE;
						}
					WRITE("    %d file%s copied to: %S\n", n, (n != 1)?"s":"", wcr->pathname_text);
				}
		}
		if ((R->verbose) && (NP > 0)) {
			WRITE("    used plugin%s: ", (NP != 1)?"s":"");
			weave_plugin *wp;
			int c = 0;
			LOOP_OVER_LINKED_LIST(wp, weave_plugin, R->plugins_copied) {
				if (c++ > 0) WRITE(", ");
				WRITE("%S", wp->plugin_name);
			}
			WRITE("\n");
		}
	} else internal_error("no weave reporting");
}

@h Front end.
This function performs a general weave of a web, or part of a web, swarming
as necessary.

=
void Swarm::weave(ls_colony *context, ls_colony_member *CM, ls_web *W, filename *to, pathname *into,
	ls_pattern *pattern, int swarm_mode, text_stream *range, text_stream *tag,
	int verbose_mode, int silent_mode) {
	weave_reporting R = Swarm::new_reportage(silent_mode?NULL:STDOUT, W, verbose_mode);
	if (context) Colonies::fully_load(context);
	W->conventions = Conventions::applicable(W, context);
	if (into == NULL) {
		if (CM) into = Colonies::weave_path(CM);
		else if (W->single_file) into = Filenames::up(W->single_file);
		else into = WebStructure::woven_folder(W, 6);
	}
	WeavingDetails::set_redirect_weaves_to(W, into);
	int r = WeavingFormats::begin_weaving(W, pattern);
	if (r != SWARM_OFF_SWM) swarm_mode = r;
	if (Str::len(tag) > 0) swarm_mode = SWARM_OFF_SWM;
	if ((W) && (CM == NULL)) CM = Colonies::find_ls_colony_member(W);
	if (swarm_mode == SWARM_OFF_SWM) {
		Swarm::weave_subset(context, CM, W, range, tag, pattern, to, into, &R);
	} else {
		Swarm::weave_swarm(context, CM, W, range, swarm_mode, tag, pattern, to, into, &R);
	}
	WeavingFormats::end_weaving(W, pattern);
	Swarm::end_report(&R);
}

@h Swarming.
A "weave" occurs when we take a portion of a literate web -- one section, one
chapter, or the whole thing -- and write it out in a human-readable form (or
in some intermediate state which can be made into one, like a TeX file).
There can be many weaves in a single run, in which case we call the resulting
flurry a "swarm", like the glittering cloud of locusts in the title of Chapter
25 of "On the Banks of Plum Creek".

When weaving a swarm, then, it's no longer a matter of weaving a particular
section or chapter: we can weave all of the sections or chapters, one after
another. |swarm_mode|, then, is one of these:

@e SWARM_OFF_SWM from 0
@e SWARM_INDEX_SWM    /* make index(es) as if swarming, but don't actually swarm */
@e SWARM_CHAPTERS_SWM /* swarm the chapters */
@e SWARM_SECTIONS_SWM /* swarm the individual sections */

=
weave_order *swarm_leader = NULL; /* the most inclusive one we weave */

void Swarm::weave_swarm(ls_colony *context, ls_colony_member *CM, ls_web *W,
	text_stream *range, int swarm_mode, text_stream *tag,
	ls_pattern *pattern, filename *to, pathname *into, weave_reporting *R) {
	swarm_leader = NULL;
	Swarm::begin_report_run(R);
	ls_chapter *C;
	ls_section *S;
	int pc = 0;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters) {
		if (C->imported == FALSE) {
			if (swarm_mode == SWARM_CHAPTERS_SWM)
				if ((W->chaptered == TRUE) && (WebRanges::is_within(C->ch_range, range))) {
					weave_order *wv = Swarm::weave_subset_inner(context, CM, W, C->ch_range, FALSE,
						tag, pattern, to, into, R);
					if (wv) {
						pc += wv->paragraphs_woven;
						WeavingDetails::set_ch_weave(C, wv);
						if (Str::len(range) > 0) swarm_leader = wv;
					}
				}	
			if (swarm_mode == SWARM_SECTIONS_SWM)
				LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
					if (WebRanges::is_within(WebRanges::of(S), range)) {
						weave_order *wv = 
							Swarm::weave_subset_inner(context, CM, W,
								WebRanges::of(S), FALSE, tag, pattern, to, into, R);
						if (wv) {
							pc += wv->paragraphs_woven;
							WeavingDetails::set_sect_weave(S, wv);
						}
					}
			Swarm::end_report_run(R);
		}
	}
	Swarm::weave_index_templates(context, CM, W, range, pattern, into, R);
	if ((Str::len(tag) > 0) && (pc == 0)) Swarm::report_empty_warning(R, tag);
}

weave_order *Swarm::weave_subset(ls_colony *context, ls_colony_member *CM, ls_web *W, text_stream *range,
	text_stream *tag, ls_pattern *pattern, filename *to, pathname *into,
	weave_reporting *R) {
	weave_order *wv = Swarm::weave_subset_inner(context, CM, W, range, FALSE,
		tag, pattern, to, into, R);
	Swarm::end_report_run(R);
	if ((Str::len(tag) > 0) && (wv->paragraphs_woven == 0)) Swarm::report_empty_warning(R, tag);
	return wv;
}

@ The following is where an individual weave task begins, whether it comes
from the swarm, or has been specified at the command line (in which case
the call comes from Program Control).

=
weave_order *Swarm::weave_subset_inner(ls_colony *context, ls_colony_member *CM, ls_web *W,
	text_stream *range, int open_afterwards, text_stream *tag,
	ls_pattern *pattern, filename *to, pathname *into, weave_reporting *R) {
	weave_order *wv = NULL;
	if (WebStructure::has_errors(W) == FALSE) {
		CodeAnalysis::analyse_code(W);
		@<Compile a set of instructions for the weaver@>;
		Weaver::weave(wv);
		Patterns::post_process(wv->pattern, wv);
		WeavingFormats::post_process_weave(wv, open_afterwards);
		Swarm::report_woven_file(R, wv->weave_to, wv);
	}
	return wv;
}

@ Each individual weave generates one of the following sets of instructions:

=
typedef struct weave_order {
	struct ls_colony *weave_colony; /* wider context for the weave, relevant to cross-links */
	struct ls_web *weave_web; /* which web we weave */
	struct text_stream *weave_range; /* which parts of the web in this weave */
	struct text_stream *theme_match; /* pick out only paragraphs with this theme */
	struct text_stream *booklet_title;
	struct ls_pattern *pattern; /* which pattern is to be followed */
	struct filename *weave_to; /* where to put it */
	struct text_stream *home_leaf; /* leafname of home page for web in this weave */
	struct weave_format *format; /* plain text, say, or HTML */
	void *post_processing_results; /* optional typesetting diagnostics after running through */
	int self_contained; /* make a self-contained file if possible */
	struct linked_list *breadcrumbs; /* non-standard breadcrumb trail, if any */
	struct wcl_declaration *navigation; /* navigation links, or |NULL| if not supplied */
	struct linked_list *plugins; /* of |weave_plugin|: these are for HTML extensions */
	struct linked_list *colour_schemes; /* of |colour_scheme|: these are for HTML */
	struct weave_reporting *reportage; /* how to report what has been done */
	int paragraphs_woven;

	/* used for workspace during an actual weave: */
	struct ls_line *current_weave_line;
	CLASS_DEFINITION
} weave_order;

@<Compile a set of instructions for the weaver@> =
	wv = CREATE(weave_order);
	wv->weave_colony = context;
	wv->weave_web = W;
	wv->weave_range = Str::duplicate(range);
	wv->pattern = pattern;
	wv->theme_match = Str::duplicate(tag);
	wv->booklet_title = Str::new();
	wv->format = Patterns::get_format(W, pattern);
	wv->post_processing_results = NULL;
	wv->self_contained = FALSE;
	if (CM) {
		wv->navigation = CM->navigation;
		wv->breadcrumbs = CM->breadcrumb_tail;
		wv->home_leaf = CM->home_leaf;
	} else {
		wv->navigation = NULL;
		wv->breadcrumbs = NEW_LINKED_LIST(breadcrumb_request);
		wv->home_leaf = I"index.html";
	}
	wv->plugins = NEW_LINKED_LIST(weave_plugin);
	wv->colour_schemes = NEW_LINKED_LIST(colour_scheme);
	if (WebStructure::has_only_one_section(W)) wv->self_contained = TRUE;
	wv->reportage = R;
	wv->paragraphs_woven = 0;
	
	wv->current_weave_line = NULL;

	int has_content = FALSE;
	ls_chapter *C;
	ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			if (WebRanges::is_within(WebRanges::of(S), wv->weave_range))
				has_content = TRUE;
	if (has_content == FALSE)
		Errors::fatal("no sections match that range");

	TEMPORARY_TEXT(leafname)
	@<Translate the subweb range into details of what to weave@>;
	pathname *H = WeavingDetails::get_redirect_weaves_to(W);
	if (H == NULL) H = into;
	if (H == NULL) {
		if (W->single_file == NULL)
	 		H = WebStructure::woven_folder(W, 3);
	 	else
	 		H = Filenames::up(W->single_file);
	}
	if (to) {
		wv->weave_to = to;
		wv->self_contained = TRUE;
	} else {
		wv->weave_to = Filenames::in(H, leafname);
	}
	if (Str::len(pattern->initial_extension) > 0)
		wv->weave_to = Filenames::set_extension(wv->weave_to, pattern->initial_extension);
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			if (WebRanges::is_within(WebRanges::of(S), wv->weave_range))
				WeavingDetails::set_section_weave_to(S, wv->weave_to);
	DISCARD_TEXT(leafname)

@ From the range and the theme, we work out the weave title, the leafname,
and details of any cover-sheet to use.

@<Translate the subweb range into details of what to weave@> =
	int extend = TRUE;
	match_results mr = Regexp::create_mr();
	if (W->single_file) {
		wv->booklet_title = Str::duplicate(Bibliographic::get_datum(W, I"Title"));
		if (CM) { WRITE_TO(leafname, "%S", wv->home_leaf); extend = FALSE; }
		else Filenames::write_unextended_leafname(leafname, W->single_file);
		if (Str::len(wv->theme_match) > 0)
			@<Change the titling and leafname to match the tagged theme@>;
	} else if (W->is_page) {
		wv->booklet_title = Str::duplicate(Bibliographic::get_datum(W, I"Title"));
		if (CM) { WRITE_TO(leafname, "%S", wv->home_leaf); extend = FALSE; }
		else WRITE_TO(leafname, "%S", W->declaration->name);
		if (Str::len(wv->theme_match) > 0)
			@<Change the titling and leafname to match the tagged theme@>;
	} else if (Str::eq_wide_string(range, U"0")) {
		wv->booklet_title = Str::new_from_wide_string(U"Complete Program");
		WRITE_TO(leafname, "Complete");
		if (Str::len(wv->theme_match) > 0)
			@<Change the titling and leafname to match the tagged theme@>;
	} else if (Regexp::match(&mr, range, U"%d+")) {
		Str::clear(wv->booklet_title);
		WRITE_TO(wv->booklet_title, "Chapter %S", range);
		Str::copy(leafname, wv->booklet_title);
	} else if (Regexp::match(&mr, range, U"%[A-O]")) {
		Str::clear(wv->booklet_title);
		WRITE_TO(wv->booklet_title, "Appendix %S", range);
		Str::copy(leafname, wv->booklet_title);
	} else if (Str::eq_wide_string(range, U"P")) {
		wv->booklet_title = Str::new_from_wide_string(U"Preliminaries");
		Str::copy(leafname, wv->booklet_title);
	} else if (Str::eq_wide_string(range, U"M")) {
		wv->booklet_title = Str::new_from_wide_string(U"Manual");
		Str::copy(leafname, wv->booklet_title);
	} else {
		ls_section *S = WebRanges::to_section(W, range);
		if (S) Str::copy(wv->booklet_title, S->sect_title);
		else Str::copy(wv->booklet_title, range);
		Str::copy(leafname, range);
	}
	Bibliographic::set_datum(W, I"Booklet Title", wv->booklet_title);
	LOOP_THROUGH_TEXT(P, leafname)
		if ((Str::get(P) == '/') || (Str::get(P) == ' '))
			Str::put(P, '-');
	if (extend) WRITE_TO(leafname, "%S", WeavingFormats::file_extension(wv->format));
	Regexp::dispose_of(&mr);

@<Change the titling and leafname to match the tagged theme@> =
	Str::clear(wv->booklet_title);
	WRITE_TO(wv->booklet_title, "Extracts: %S", wv->theme_match);
	Str::copy(leafname, wv->theme_match);

@ =
void Swarm::ensure_plugin(weave_order *wv, text_stream *name) {
	weave_plugin *existing;
	LOOP_OVER_LINKED_LIST(existing, weave_plugin, wv->plugins)
		if (Str::eq_insensitive(name, existing->plugin_name))
			return;
	weave_plugin *wp = Assets::new(name);
	ADD_TO_LINKED_LIST(wp, weave_plugin, wv->plugins);
}

colour_scheme *Swarm::ensure_colour_scheme(weave_order *wv, text_stream *name,
	text_stream *pre) {
	colour_scheme *existing;
	LOOP_OVER_LINKED_LIST(existing, colour_scheme, wv->colour_schemes)
		if (Str::eq_insensitive(name, existing->scheme_name))
			return existing;
	colour_scheme *cs = Assets::find_colour_scheme(wv->weave_web, wv->pattern, name, pre);
	if (cs == NULL) {
		if (Str::eq(name, I"Colours")) {
			TEMPORARY_TEXT(err)
			WRITE_TO(err, "No CSS file for the colour scheme '%S' can be found", name);
			WebErrors::issue_at(err, NULL);
		} else {
			return Swarm::ensure_colour_scheme(wv, I"Colours", I"");
		}
	}
	if (cs) ADD_TO_LINKED_LIST(cs, colour_scheme, wv->colour_schemes);
	return cs;
}

void Swarm::include_plugins(OUTPUT_STREAM, ls_web *W, weave_order *wv, filename *from) {
	weave_plugin *wp;
	LOOP_OVER_LINKED_LIST(wp, weave_plugin, wv->plugins)
		Assets::include_plugin(OUT, W, wp, wv->pattern, from, wv->reportage, wv->weave_colony);
	colour_scheme *cs;
	LOOP_OVER_LINKED_LIST(cs, colour_scheme, wv->colour_schemes)
		Assets::include_colour_scheme(OUT, W, cs, wv->pattern, from, wv->reportage, wv->weave_colony);
}

@ After every swarm, we rebuild the index:

=
void Swarm::weave_index_templates(ls_colony *context, ls_colony_member *CM, ls_web *W,
	text_stream *range, ls_pattern *pattern, pathname *into, weave_reporting *R) {
	if (!(Bibliographic::data_exists(W, I"Version Number")))
		Bibliographic::set_datum(W, I"Version Number", I" ");
	filename *INF = Patterns::find_template(W, pattern, I"template-index.html");
	if (INF) {
		pathname *H = WeavingDetails::get_redirect_weaves_to(W);
		if ((H == NULL) && (W->single_file == FALSE)) H = WebStructure::woven_folder(W, 4);
		filename *Contents = Filenames::in(H, (CM)?(CM->home_leaf):I"index.html");
		text_stream TO_struct; text_stream *OUT = &TO_struct;
		if (STREAM_OPEN_TO_FILE(OUT, Contents, ISO_ENC) == FALSE)
			Errors::fatal_with_file("unable to write contents file", Contents);
		if (WeavingDetails::get_as_ebook(W))
			Epub::note_page(WeavingDetails::get_as_ebook(W), Contents, I"Index", I"index");
		Swarm::report_woven_file(R, Contents, NULL);

		wcl_declaration *nav;
		linked_list *crumbs;
		if (CM) {
			nav = CM->navigation;
			crumbs = CM->breadcrumb_tail;
		} else {
			nav = NULL;
			crumbs = NEW_LINKED_LIST(breadcrumb_request);
		}

		Collater::collate(OUT, W, range, INF, NULL, pattern, nav, crumbs, NULL, Contents, context, R);
		STREAM_CLOSE(OUT);
	}
}
