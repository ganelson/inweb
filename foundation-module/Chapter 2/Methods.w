[Methods::] Methods.

General support for something approximating method calls.

@h Method sets.
This section provides a very rudimentary implementation of method calls,
ordinarily not available in C, but doesn't pretend to offer the full
functionality of an object-oriented language.

Instead, it's really intended for protocol-based coding patterns. Suppose that
we have objects of several different structure types, but all of them can
serve a given purpose -- say, all of them contribute an adjective to the
Inform language. What we want is the ability to take a pointer, which might be
to an object of any of these types, and to tell the object to do something, or
ask it a question.

Alternatively, we may have a situation where there are multiple objects of the
same type which each represent a different way of doing something: for
example, in the Inweb source code, each different supported programming
language is represented by an object. These objects need to encapsulate all
the ways that one language differs from another, and they can do that by
providing "methods".

@ The model is this. If a |typedef struct| definition includes the line
|METHOD_CALLS|, then any instance of that structure can have a queue of
tagged functions attached to it dynamically: those, we'll call "methods".

@d METHOD_CALLS
	struct method_set *methods;
@d ENABLE_METHOD_CALLS(obj)
	obj->methods = Methods::new_set();

@ A "method set" is simply a linked list of methods:

=
typedef struct method_set {
	struct method *first_method;
	MEMORY_MANAGEMENT
} method_set;

method_set *Methods::new_set(void) {
	method_set *S = CREATE(method_set);
	S->first_method = NULL;
	return S;
}

@h Declaring methods.
Each method is a function, though we don't know its type -- which is why we
resort to the desperate measure of storing it as a |void *| -- with an ID
number attached to it. IDs should be from the |*_MTID| enumeration set.

@e UNUSED_METHOD_ID_MTID from 1

@ The type of a method must neverthess be specified, and we do it with one
of two macros: one for methods returning an integer, one for void methods,
i.e., those returning no value.

What these do is to use typedef to give the name |X_type| to the type of all
functions sharing the method ID |X|.

@d IMETHOD_TYPE(id, args...)
	typedef int (*id##_type)(args);
@d VMETHOD_TYPE(id, args...)
	typedef void (*id##_type)(args);

=
IMETHOD_TYPE(UNUSED_METHOD_ID_MTID, text_stream *example, int wont_be_used)

@h Adding methods.
Provided a function has the right type for the ID we're using, we can now
attach it to an object with a method set, using the |METHOD_ADD| macro.
(If the type is wrong, the C compiler will throw errors here.)

@d METHOD_ADD(upon, id, func)
	Methods::add(upon->methods, id, (void *) &func);

=
typedef struct method {
	int method_id;
	void *method_function;
	struct method *next_method;
	MEMORY_MANAGEMENT
} method;

void Methods::add(method_set *S, int ID, void *function) {
	method *M = CREATE(method);
	M->method_id = ID;
	M->method_function = function;
	M->next_method = NULL;
	
	if (S->first_method == NULL) S->first_method = M;
	else {
		method *existing = S->first_method;
		while ((existing) && (existing->next_method)) existing = existing->next_method;
		existing->next_method = M;
	}
}

@h Calling methods.
Method calls are also done with a macro, but it has to come in four variants:

(a) |IMETHOD_CALL| for a method taking arguments and returning an |int|,
(b) |IMETHOD_CALLV| for a method without arguments which returns an |int|,
(c) |VMETHOD_CALL| for a method taking arguments and returning nothing,
(d) |VMETHOD_CALLV| for a method without arguments which returns nothing.

For example:

	|IMETHOD_CALL(some_object, UNUSED_METHOD_ID_MTID, I"Hello", 17)|

Note that it's entirely possible for the |upon| object to have multiple methods
added for the same ID -- or none. In the |V| (void) cases, what we then do is
to call each of them in turn. In the |I| (int) cases, we call each in turn, but
stop the moment any of them returns something other than |FALSE|, and then
we put that value into the specified result variable |rval|.

If |some_object| has no methods for the given ID, then nothing happens, and
in the |I| case, the return value is |FALSE|.

It will, however, produce a compilation error if |some_object| is not a pointer
to a structure which has |METHOD_CALLS| as part of its definition.

@d IMETHOD_CALL(rval, upon, id, args...) {
	rval = FALSE;
	for (method *M = upon?(upon->methods->first_method):NULL; M; M = M->next_method)
		if (M->method_id == id) {
			int method_rval_ = (*((id##_type) (M->method_function)))(upon, args);
			if (method_rval_) {
				rval = method_rval_;
				break;
			}
		}
}
@d IMETHOD_CALLV(rval, upon, id) {
	rval = FALSE;
	for (method *M = upon?(upon->methods->first_method):NULL; M; M = M->next_method)
		if (M->method_id == id) {
			int rv = (*((id##_type) (M->method_function)))(upon);
			if (rv) {
				rval = rv;
				break;
			}
		}
}
@d VMETHOD_CALL(upon, id, args...)
	for (method *M = upon?(upon->methods->first_method):NULL; M; M = M->next_method)
		if (M->method_id == id)
			(*((id##_type) (M->method_function)))(upon, args);
@d VMETHOD_CALLV(upon, id)
	for (method *M = upon?(upon->methods->first_method):NULL; M; M = M->next_method)
		if (M->method_id == id)
			(*((id##_type) (M->method_function)))(upon);
