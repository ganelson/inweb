[LineLabels::] Line Labels.

Lines in a web can, optionally, give themselves identifying labels.

@h Labels.
A label is just a name, attached to a line of the web. Although it can
only be attached to a line of code, not of commentary, definition, titling,
and such, the implementation below doesn't rely on that.

=
classdef ls_line_label {
	struct text_stream *name;
	struct ls_line *attached_to;
}

@ Some basic properties:

=
int LineLabels::labelled(ls_line *lst) {
	if ((lst) && (lst->label)) return TRUE;
	return FALSE;
}

int LineLabels::label_width(ls_line *lst) {
	return Str::len(LineLabels::label_text(lst));
}

text_stream *LineLabels::label_text(ls_line *lst) {
	if ((lst) && (lst->label)) return lst->label->name;
	return NULL;
}

ls_line *LineLabels::destination(ls_line_label *label) {
	if (label) return label->attached_to;
	return NULL;
}

@h Attachment.
Two policy points here: (i) a label cannot exist in a not-yet-attached
state, but is instead joined to its line at the moment of creation; and
(ii) a line can only have a single label.

=
ls_line_label *LineLabels::label_line(ls_line *lst, text_stream *name) {
	@<Vet the label name itself@>;
	ls_line_label *label = CREATE(ls_line_label);
	label->name = Str::duplicate(name);
	label->attached_to = lst;
	if (lst->label) @<Throw an error for multiple labels on a line@>;
	lst->label = label;
	@<Enter the name into the appropriate dictionaries@>;
	return label;
}

@ Since label names arise from regular expression matching, it's prudent to
assume there will sometimes be accidents, where the user captures the wrong
text; so we had better check that the text is reasonable.

We are going to need to use label names in HTML anchors, so it also seems wise
to conform to the rules on those. HTML 5 is more generous, but HTML 4 requires:

> ID and NAME tokens must begin with a letter ([A-Za-z]) and may be followed
> by any number of letters, digits ([0-9]), hyphens ("-"), underscores ("_"),
> colons (":"), and periods (".").
	
The initial letter is not a problem here (see below), but the rest we do
need to enforce:

@<Vet the label name itself@> =
	if (Str::len(name) == 0) @<Throw an error for an empty label name@>;
	for (int i=0; i<Str::len(name); i++) {
		inchar32_t c = Str::get_at(name, i);
		if (!((Characters::isalnum(c)) ||
				(c == '-') || (c == '_') || (c == '.') || (c == ':'))) {
			@<Throw an error for a bad character@>;
			break;
		}
	}

@ There are three levels of namespace: the paragraph containing a label;
the section containing that paragraph; and the web containing that section.
The label is required to be unique only at the paragraph level.

@<Enter the name into the appropriate dictionaries@> =
	ls_paragraph *par = LiterateSource::par_of_line(lst);
	if (par) {
		if (par->paragraph_label_namespace == NULL)
			par->paragraph_label_namespace = LineLabels::new_namespace();
		dict_entry *de = Dictionaries::find(par->paragraph_label_namespace->names, name);
		if (de) @<Throw an error for duplicate labels in the same paragraph@>
		LineLabels::add_to_namespace(label, par->paragraph_label_namespace);
	}
	ls_unit *unit = LiterateSource::unit_of_line(lst);
	if (unit)
		LineLabels::add_to_namespace(label, unit->local_label_namespace);
	if ((unit) && (unit->context))
		LineLabels::add_to_namespace(label, unit->context->global_label_namespace);
	return label;

@<Throw an error for an empty label name@> =
	WebErrors::record_at(I"there must be at least one character in a label name", lst);

@<Throw an error for a bad character@> =
	text_stream *err = Str::new();
	WRITE_TO(err, "the label name '%S' can't be used: ", name);
	WRITE_TO(err, "labels can contain only letters, digits, :, ., _, and -");
	WebErrors::record_at(err, lst);

@<Throw an error for multiple labels on a line@> =
	text_stream *err = Str::new();
	WRITE_TO(err, "label '%S' is being applied to a line already labelled '%S'",
		name, lst->label->name);
	WebErrors::record_at(err, lst);

@<Throw an error for duplicate labels in the same paragraph@> =
	text_stream *err = Str::new();
	WRITE_TO(err, "label '%S' occurs twice in the same paragraph", name);
	WebErrors::record_at(err, lst);

@h Namespaces.
A label namespace is really just a dictionary, that is, an associative hash
of the label names. These are initially fairly small (just 8 entries) because
a typical paragraph is unlikely to contain many labels; and if it does, we
can afford the small speed hit when expanding the dictionary.

=
classdef ls_label_namespace {
	struct dictionary *names;
}

ls_label_namespace *LineLabels::new_namespace(void) {
	ls_label_namespace *ns = CREATE(ls_label_namespace);
	ns->names = Dictionaries::new(8, FALSE);
	return ns;
}

void LineLabels::add_to_namespace(ls_line_label *label, ls_label_namespace *ns) {
	Dictionaries::create(ns->names, label->name);
	Dictionaries::write_value(ns->names, label->name, label);
}

@ Searching for a name involves going up the hierarchy of the three levels:
paragraph, then section, then web:

=
ls_line_label *LineLabels::find(ls_web *W, ls_line *lst, text_stream *name) {
	if (lst) {
		ls_paragraph *par = LiterateSource::par_of_line(lst);
		if ((par) && (par->paragraph_label_namespace)) {
			ls_label_namespace *ns = par->paragraph_label_namespace;
			@<Search namespace for name@>;
		}
		ls_unit *unit = LiterateSource::unit_of_line(lst);
		if (unit) {
			ls_label_namespace *ns = unit->local_label_namespace;
			@<Search namespace for name@>;
		}
	}
	if (W) {
		ls_label_namespace *ns = W->global_label_namespace;
		@<Search namespace for name@>;
	}
	return NULL;
}

@<Search namespace for name@> =
	dict_entry *de = Dictionaries::find(ns->names, name);
	if (de) return (ls_line_label *) Dictionaries::value_for_entry(de);

@h HTML anchors.
When a web with labels is rendered to HTML, anchor elements are placed at
the start of each line with a label. These anchors need to have unique names,
and as noted above, label names are only guaranteed unique within a paragraph.
So the anchor name for a label is a concatenation of the paragraph anchor
and the label itself.

For example, label `magic` in paragraph 2.3 might have anchor `SP2_3LLmagic`.

=
void LineLabels::anchor(OUTPUT_STREAM, ls_line *lst) {
	if (lst) {
		ls_paragraph *par = LiterateSource::par_of_line(lst);
		if (par) Colonies::paragraph_anchor(OUT, par);
		WRITE("LL%S", lst->label->name);
	}
}
