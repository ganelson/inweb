# Recognising Functions and Types

It seems an appealing idea to recognise which identifiers in a program are
names of functions, and which are names of types. But this is not always a
good thing. Some languages have very tricky syntax in writing these definitions;
in others, it's not entirely clear what counts as a function, or for that matter
a type; and in any case Inweb can only recognise the functions and types
declared in the code it scans. For example, in some imaginary language which
imports a library:

	import trigonometry
	
	print sqrt(1.3245)

...Inweb has no direct way to know that `sqrt` is the name of a function, because
the definition is inside the `trigonometry` library, which isn't part of the web.

With that caveat made, here's how functions and types can be recognised, at
least in the code which Inweb does scan.

-- -- --

To continue with Rust, we can add some lines to the `properties` block in
the definition begun in //Creating Languages//:

		Function Declaration:	/fn (\S+?)\s*\(.*/
		Type Declaration:  		/enum (\S+?)\s+.*/
		Type Declaration:  		/struct (\S+?)\s+.*/
		Type Declaration:  		/type (\S+?)\s+.*/
		Type Declaration:  		/trait (\S+?)\s+.*/
		Type Declaration:  		/union (\S+?)\s+.*/

Once again these are regular expressions. Note the multiple values given
for `Type Declaration`: these are alternatives. (Alternatives can
be given for `Function Declaration`, too.) These expressions must
each contain just one bracketed subexpression — the name in question.
(For more on regexps, see /Syntax Colouring Programs/.)

So, for example, these lines of source code all match against our function
definition notation:

	fn main() {

	fn is_divisible_by(lhs: u32, rhs: u32) -> bool {

	fn notify(&mut self) {

The regular expression picks out the function names here, `main`, `is_divisible_by`,
and `notify`, as the part matching the bracketed part of the expression. Inweb
automatically makes these keywords of colour `!function`, and the colouring
program can then pick up on this:

	colouring
		runs of unquoted {
			runs of !identifier {
				keyword of !reserved => !reserved
				keyword of !constant => !constant
				keyword of !function => !function
				keyword of !type => !type
				suffix "!" => !macro on both
			}
			...
		}
	end

And similarly for `!type`, which will be applied to any type names found
through the `Type Declaration` regexp(s).

Any typed language will almost certainly have some built-in types (or types
defined in an essentially mandatory library), and we might want those to
pick up syntax-colouring, too, even though they are _not_ defined in the
code scanned by Inweb. That can be done in the language definition; for
Rust the bare bones might be —

	keywords of !type
		i8 i16 i32 i64 i128 u8 u16 u32 u64 u128 f16 f32 f64 f128 bool char str
	end

Lastly, note that a language declared as `C-like` will not need these
two properties to be set, because Inweb handles matters directly. See
//Special C Features// for more on this.
