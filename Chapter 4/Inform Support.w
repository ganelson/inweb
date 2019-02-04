[InformSupport::] Inform Support.

To support webs written in Inform 6 or 7.

@h Inform 6.

=
programming_language *InformSupport::create_I6(void) {
	programming_language *pl = Languages::new_language(I"Inform 6", I".i6");
	pl->source_file_extension = I".i6t";
	METHOD_ADD(pl, COMMENT_TAN_MTID, InformSupport::I6_comment);
	METHOD_ADD(pl, OPEN_IFDEF_TAN_MTID, InformSupport::I6_open_ifdef);
	METHOD_ADD(pl, CLOSE_IFDEF_TAN_MTID, InformSupport::I6_close_ifdef);
	return pl;
}

void InformSupport::I6_comment(programming_language *pl, text_stream *OUT, text_stream *comm) {
	WRITE("! %S\n", comm);
}

void InformSupport::I6_open_ifdef(programming_language *self, text_stream *OUT, text_stream *symbol, int sense) {
	if (sense) WRITE("#ifdef %S;\n", symbol);
	else WRITE("#ifndef %S;\n", symbol);
}

void InformSupport::I6_close_ifdef(programming_language *self, text_stream *OUT, text_stream *symbol, int sense) {
	WRITE("#endif; /* %S */\n", symbol);
}

@h Inform 7.

=
programming_language *InformSupport::create_I7(void) {
	programming_language *pl = Languages::new_language(I"Inform 7", I".i7x");
	METHOD_ADD(pl, COMMENT_TAN_MTID, InformSupport::I7_comment);
	METHOD_ADD(pl, SUPPRESS_DISCLAIMER_TAN_MTID, InformSupport::suppress_disclaimer);
	return pl;
}

void InformSupport::I7_comment(programming_language *pl, text_stream *OUT, text_stream *comm) {
	WRITE("[%S]\n", comm);
}

@ This is here so that tangling the Standard Rules extension doesn't insert
a spurious comment betraying Inweb's involvement in the process.

=
int InformSupport::suppress_disclaimer(programming_language *pl) {
	return TRUE;
}
