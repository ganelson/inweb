[WeavingDetails::] Weaving Details.

Annotations to a LP tree to accommodate weaving.

@ We won't do any work in this section, only set up some additional fields in
LP source trees to enable weaving.

=
typedef struct ls_web_weaving_details {
	struct ebook *as_ebook; /* when being woven to an ebook */
	struct pathname *redirect_weaves_to; /* ditto */
	CLASS_DEFINITION
} ls_web_weaving_details;

typedef struct ls_chapter_weaving_details {
	struct weave_order *ch_weave; /* |NULL| unless this chapter produces a weave of its own */
	CLASS_DEFINITION
} ls_chapter_weaving_details;

typedef struct ls_section_weaving_details {
	struct weave_order *sect_weave; /* |NULL| unless this section produces a weave of its own */
	struct filename *sect_weave_to; /* |NULL| unless some special choice has been made */
	CLASS_DEFINITION
} ls_section_weaving_details;

@

=
void WeavingDetails::initialise(ls_web *W) {
	@<Give the web weaving details@>;
	ls_chapter *C;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters) {
		@<Give the chapter weaving details@>;
		ls_section *S;
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			@<Give the section weaving details@>;
	}
}

@<Give the web weaving details@> =
	ls_web_weaving_details *weave_details = CREATE(ls_web_weaving_details);
	W->weaving_ref = (void *) weave_details;
	weave_details->as_ebook = NULL;
	weave_details->redirect_weaves_to = NULL;

@<Give the chapter weaving details@> =
	ls_chapter_weaving_details *weave_details = CREATE(ls_chapter_weaving_details);
	C->weaving_ref = (void *) weave_details;
	weave_details->ch_weave = NULL;

@<Give the section weaving details@> =
	ls_section_weaving_details *weave_details = CREATE(ls_section_weaving_details);
	S->weaving_ref = (void *) weave_details;
	weave_details->sect_weave = NULL;
	weave_details->sect_weave_to = NULL;

@ Here are the semantics for a web:

=
ebook *WeavingDetails::get_as_ebook(ls_web *W) {
	return ((ls_web_weaving_details *) (W->weaving_ref))->as_ebook;
}

void WeavingDetails::set_as_ebook(ls_web *W, ebook *val) {
	((ls_web_weaving_details *) (W->weaving_ref))->as_ebook = val;
}

pathname *WeavingDetails::get_redirect_weaves_to(ls_web *W) {
	return ((ls_web_weaving_details *) (W->weaving_ref))->redirect_weaves_to;
}

void WeavingDetails::set_redirect_weaves_to(ls_web *W, pathname *val) {
	((ls_web_weaving_details *) (W->weaving_ref))->redirect_weaves_to = val;
}

@ And for a chapter:

=
weave_order *WeavingDetails::get_ch_weave(ls_chapter *C) {
	return ((ls_chapter_weaving_details *) (C->weaving_ref))->ch_weave;
}

void WeavingDetails::set_ch_weave(ls_chapter *C, weave_order *O) {
	((ls_chapter_weaving_details *) (C->weaving_ref))->ch_weave = O;
}

@ And lastly for a section.

=
weave_order *WeavingDetails::get_sect_weave(ls_section *S) {
	return ((ls_section_weaving_details *) (S->weaving_ref))->sect_weave;
}

void WeavingDetails::set_sect_weave(ls_section *S, weave_order *val) {
	((ls_section_weaving_details *) (S->weaving_ref))->sect_weave = val;
}

filename *WeavingDetails::get_section_weave_to(ls_section *S) {
	if (S->weaving_ref == NULL) return NULL;
	return ((ls_section_weaving_details *) (S->weaving_ref))->sect_weave_to;
}

void WeavingDetails::set_section_weave_to(ls_section *S, filename *val) {
	((ls_section_weaving_details *) (S->weaving_ref))->sect_weave_to = val;
}
