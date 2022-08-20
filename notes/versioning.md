# Branching and versioning policy

## Version numbers for Inweb

Inweb is developed in public. Command-line users comfortable with git can always get the very latest state. But that potentially means endless different versions of Inweb out there in the wild. To clarify this situation, all versions are numbered, and we will distinguish between "release" versions, which are ready for public use, and "unstable" versions, which are not.

"Release" versions have simple version numbers in the shape `X.Y.Z`: for example, `7.1.0`.

"Unstable" versions are commits of the software between releases. These have much longer version numbers, containing an `-alpha` or `-beta` warning. For example, `7.1.0-beta+1B14`. (The `+1B14` is a daily build number, also only
present on version numbers of unstable versions.)

Note that `inweb -version` prints out the full version number of the core
source it was compiled from. This one is clearly unstable:

	$ inweb/Tangled/inweb -version
	inweb version 7.1.0-beta+1B14 'Escape to Danger' (9 August 2022)

(Since around 2011, major versions of Inweb have been given code-names according to the
episodes of the 1964 Doctor Who serial [The Web Planet](https://en.wikipedia.org/wiki/The_Web_Planet).
Major version 8 will be "Crater of Needles".)

Release notes for releases since 2022 can be found [here](version_history.md).

## Branching

In the core Inweb repository, active development is on the `master` branch, at least for now. That will always be a version which is unstable. All releases will be made from short branches off of `master`. For example, there will soon be a branch called `r7.1`. This will contain as few commits as possible, ideally just one, which would be the actual release version of 7.1.0. But if there are then point updates with bug fixes, say 7.1.1, 7.1.2, and so on, those would be further commits to the `r7.1` branch. Later, another short branch from `master` would be `r7.2`.

Releases will be tagged with their version numbers, so the commit representing 7.1.0 will be tagged `v7.1.0`. These will be presented under Releases in the usual Github way, from the column on the right-hand side of the home page. We expect to provide the app installers as associated binary files on those releases, though that won't be the only place they are available.
