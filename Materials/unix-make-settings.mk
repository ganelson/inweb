# First, the locations to which resources must be copied, inside the
# application. These pathnames mustn't contain spaces:

BUILTINCOMPS = i7/Compilers
INTERNAL = i7/Internal
BUILTINHTML = i7/Documentation
BUILTINHTMLINNER = i7/Documentation/Sections

# The I6 compiler is one of the tools living in the BUILTINCOMPS folder, but
# its name customarily differs between platforms.

I6COMPILERNAME = inform6

# The I6 source code needs a constant defined to tell it what platform it'll
# be used on, so:

INFORM6OS = LINUX

# The following should contain "--rewrite-standard-rules" only for Mac OS X,
# and then probably only for Graham Nelson's master copy. (The rewriting in
# question reconciles the documentation cross-references in the application,
# by changing the "Document X at Y" sentences in the Standard Rules.)
# For instance, for Windows this should be simply be "windows_app".

INDOCOPTS = linux_app

# For reasons to do with CSS, the following should be "-nofont" for Windows:

INRTPSOPTS = -font

# -multi in the following runs "make check" with processes divided among what
# are expected to be four processors, for a substantial speed gain, but doesn't
# change the outcome:

INTESTOPTS = -platform linux -threads=1

# We will use Apple's superior clang, rather than gcc itself; they're
# very close to being identical, but clang is faster and gives better errors.

GCC = clang

GCCOPTS = -Wno-unused -DPLATFORM_UNIX -DUNIX64 -DCPU_WORDSIZE_MULTIPLIER=2 -O2

# To excuse these warning waivers:

#     -Wno-pointer-arith: we use the gcc extension allowing (void *) pointers to increment
#     -Wno-variadic-macros: we use the gcc extension for variadic macros

#     -Wno-cast-align, -Wno-padded: we don't care about address alignments of structure elements

#     -Wno-missing-noreturn: a few fatal-error functions could be marked with
#          __attribute__((noreturn)) to prevent this, but gcc doesn't accept
#          this except in a predeclaration, which is inconvenient for us
#     -Wno-shadow: we don't care if an inner block defines a variable of the same name
#     -Wno-unused-macros: a few constants are defined to document external formats rather than for use here
#     -Wno-unused-parameter: we don't much care if a function argument isn't used
#     -Wno-missing-prototypes: because Preform-defined routines aren't predeclared with prototypes
#     -Wno-missing-variable-declarations: these are not for linking, so don't care about extern/static
#     -Wno-unreachable-code-break: these derive from Preform-compiled switches, and are harmless
#	 -Wno-class-varargs: for some reason clang thinks structs shouldn't be passed to variable-argument functions
#     -Wno-format-nonliteral: similarly, it thinks all format strings in |printf| should be literals
#     -Wno-cast-qual: in OS X 10.11, clang became bothered by casts from (void *) if it thought they were const

GCCWARNINGS = -Weverything -Wno-pointer-arith -Wno-unused-macros -Wno-shadow -Wno-cast-align -Wno-variadic-macros -Wno-missing-noreturn -Wno-missing-prototypes -Wno-unused-parameter -Wno-padded -Wno-missing-variable-declarations -Wno-unreachable-code-break -Wno-class-varargs -Wno-format-nonliteral -Wno-cast-qual

# (For cblorb, where we make a lot of use of sscanf, it's a nuisance to be warned
# about entirely legal format strings passed as variables.)

CBLORBWARNINGS = -Wno-format-nonliteral

# The following is needed when compiling glulxe, as part of dumb-glulx, which
# is used in testing. For Mac OS X and probably all Unix-based systems, it
# wants to be OS_UNIX; for Windows it probably wants to be WIN32. See the file
# osdepend.c in the glulxe distribution.

GLULXEOS = OS_UNIX

# On Mac OS X, no special options are needed for linking, but on some Unix
# builds we need to use ld rather than gcc and to apply various options.

LINK = $(GCC) $(LINKEROPTS)
LINKEROPTS = -lm -lpthread -static

# On most systems, the following will be the traditional archiver "ar -r", but
# for modern Mac OS X use we need to use Apple's replacement "libtool", which
# is able to cope with fat (i.e., multiple-architecture) binaries.

ARTOOL = ar -r
