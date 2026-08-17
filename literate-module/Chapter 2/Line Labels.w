[LineLabels::] Line Labels.

Lines in a web can, optionally, give themselves identifying labels.

@h Labels.
A line classifier is really just a list of rules:

=
classdef ls_line_label {
	struct text_stream *name;
	struct ls_line *attached_to;
}

ls_line_label *LineLabels::label_line(ls_line *lst, text_stream *name) {
	ls_line_label *label = CREATE(ls_line_label);
	label->name = Str::duplicate(name);
	label->attached_to = lst;
	lst->label = label;
	ls_unit *unit = LiterateSource::unit_of_line(lst);
	if (unit) {
		LineLabels::add_to_namespace(label, unit->local_label_namespace);
		if (unit->context)
			LineLabels::add_to_namespace(label, unit->context->global_label_namespace);
	}
	return label;
}

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

void LineLabels::anchor(OUTPUT_STREAM, ls_line *lst) {
	if (lst) WRITE("LL%S", lst->label->name);
}

ls_line *LineLabels::destination(ls_line_label *label) {
	if (label) return label->attached_to;
	return NULL;
}

classdef ls_label_namespace {
	struct ls_web *owning_web;  /* or `NULL` for code isolated from any web */
	struct ls_unit *owner;      /* or `NULL` for global scope, but they're not both `NULL` */
	struct dictionary *names;
}

ls_label_namespace *LineLabels::new_namespace(ls_web *W, ls_unit *owner) {
	ls_label_namespace *ns = CREATE(ls_label_namespace);
	ns->owning_web = W;
	ns->owner = owner;
	if ((W == NULL) && (owner == NULL)) internal_error("lost label namespace");
	ns->names = Dictionaries::new(128, FALSE);
	return ns;
}

void LineLabels::add_to_namespace(ls_line_label *label, ls_label_namespace *ns) {
	Dictionaries::create(ns->names, label->name);
	Dictionaries::write_value(ns->names, label->name, label);
}

ls_line_label *LineLabels::find(ls_web *W, ls_line *lst, text_stream *name) {
	if (lst) {
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
