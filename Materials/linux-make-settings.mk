# Make settings for integrating Inform's user interface and core software.

# This file contains only those settings likely to differ on different
# platforms, and the idea is that each user interface maintainer will keep
# his or her own version of this file.

# This is the Gnome version, by Philip Chimento

INTEST = intest/Tangled/intest
INWEB = inweb/Tangled/inweb

# First, the locations to which resources must be copied, inside the
# application. These pathnames mustn't contain spaces:

BUILTINCOMPS = gnome-inform7/src/ni
INTERNAL = gnome-inform7/data
BUILTINHTML = gnome-inform7/data/Resources
BUILTINHTMLINNER = gnome-inform7/data/Resources/en

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

INDOCOPTS = gnome_app

# -multi in the following runs "make check" with processes divided among what
# are expected to be four processors, for a substantial speed gain, but doesn't
# change the outcome:

INTESTOPTS = -platform=gnome

# On most Linux systems GCC is installed and not Clang.

GCC = gcc

GCCOPTS = -D_BSD_SOURCE -DPLATFORM_UNIX -fdiagnostics-color=auto

# To excuse these warning waivers:

#     -Wno-pointer-to-int-cast: we use the gcc extension allowing (void *) pointers to increment

#     -Wno-unused-parameter: we don't much care if a function argument isn't used
#     -Wno-unused-but-set-variable: we don't much care about this either
#     -Wno-unknown-pragmas: there is plenty of #pragma clang and we don't want a warning every time it is encountered

GCCWARNINGS = -Wall -Wextra -Wno-pointer-to-int-cast -Wno-unused-parameter -Wno-unused-but-set-variable -Wno-unknown-pragmas

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

LINK = $(GCC) $(GCCOPTS) -g
LINKEROPTS = -lm

# On most systems, the following will be the traditional archiver "ar -r", but
# for modern Mac OS X use we need to use Apple's replacement "libtool", which
# is able to cope with fat (i.e., multiple-architecture) binaries.

ARTOOL = ar -r
