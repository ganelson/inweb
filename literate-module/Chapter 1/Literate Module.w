[LiterateModule::] Literate Module.

Setting up the use of this module.

@ This section simply sets up the module in ways expected by //foundation//, and
contains no code of interest. The following constant exists only in tools
which use this module:

@d LITERATE_MODULE TRUE

@ Like all modules, this one must define a `start` and `end` function:

=
void LiterateModule::start(void) {
}

void LiterateModule::end(void) {
}
