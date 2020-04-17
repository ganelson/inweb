[Trees::] Trees.

To provide heterogeneous tree structures, where a node can be any structure
known to the Foundation memory manager.

@h Trees and nodes.
The tree itself is really just a root node, which is initially null, so that
a tree can be empty.

=
typedef struct heterogeneous_tree {
	struct tree_type *type;
	struct tree_node *root;
	MEMORY_MANAGEMENT
} heterogeneous_tree;

@ =
heterogeneous_tree *Trees::new(tree_type *type) {
	heterogeneous_tree *T = CREATE(heterogeneous_tree);
	T->type = type;
	T->root = NULL;
	return T;
}

@ =
typedef struct tree_node {
	struct heterogeneous_tree *owner;
	struct tree_node_type *type;
	struct general_pointer content;
	struct tree_node *next;
	struct tree_node *parent;
	struct tree_node *child;
	MEMORY_MANAGEMENT
} tree_node;

@ A node is created in limbo, removed from its tree, but it is still somehow
owned by it.

=
tree_node *Trees::new_node(heterogeneous_tree *T, tree_node_type *type, general_pointer wrapping) {
	if (T == NULL) internal_error("no tree");
	if (wrapping.run_time_type_code == -1)
		internal_error("no reference given");
	if (type->required_MT >= 0)
		if (wrapping.run_time_type_code != type->required_MT)
			internal_error("wrong reference type");

	tree_node *N = CREATE(tree_node);
	N->content = wrapping;
	N->owner = T;
	N->type = type;
	N->parent = NULL;
	N->child = NULL;
	N->next = NULL;
	return N;
}

@ A convenient abbreviation for a common manoeuvre:

=
tree_node *Trees::new_child(tree_node *of, tree_node_type *type, general_pointer wrapping) {
	tree_node *N = Trees::new_node(of->owner, type, wrapping);
	Trees::make_child(N, of);
	return N;
}

@h Types.
The above will provide for multiple different types of tree to be used for
different purposes. Heterogeneous trees allow the coder to make dangerously
type-unsafe structures, so we want to hedge them in with self-imposed
constraints:

=
typedef struct tree_type {
	struct text_stream *name;
	int (*verify_root)(struct tree_node *); /* function to vet the root node */
	MEMORY_MANAGEMENT
} tree_type;

@ =
tree_type *Trees::new_type(text_stream *name, int (*verifier)(tree_node *)) {
	tree_type *T = CREATE(tree_type);
	T->name = Str::duplicate(name);
	T->verify_root = verifier;
	return T;
}

@ Each node in a tree also has a type. Whenever the children of a node change,
they are re-verified by the |verify_children|.

=
typedef struct tree_node_type {
	struct text_stream *node_type_name; /* text such as |I"INVOCATION"| */
	int required_MT; /* if any; or negative for no restriction */
	int (*verify_children)(struct tree_node *); /* function to vet the children */
	MEMORY_MANAGEMENT
} tree_node_type;

@ =
tree_node_type *Trees::new_node_type(text_stream *name, int req,
	int (*verifier)(tree_node *)) {
	tree_node_type *NT = CREATE(tree_node_type);
	NT->node_type_name = Str::duplicate(name);
	NT->required_MT = req;
	NT->verify_children = verifier;
	return NT;
}

@h Hierarchy.
A special function is needed to choose the root node; and note that this is
verified.

=
void Trees::make_root(heterogeneous_tree *T, tree_node *N) {
	if (T == NULL) internal_error("no tree");
	if (N == NULL) internal_error("no node");
	N->owner = T;
	T->root = N;
	N->parent = NULL;
	N->next = NULL;
	if (T->type->verify_root)
		if ((*(T->type->verify_root))(N) == FALSE)
			internal_error("disallowed node as root");
}

void Trees::remove_root(heterogeneous_tree *T) {
	if (T == NULL) internal_error("no tree");
	T->root = NULL;
}

@ Otherwise, nodes are placed in a tree with respect to other nodes:

=
void Trees::make_child(tree_node *N, tree_node *of) {
	if (N == NULL) internal_error("no node");
	if (of == NULL) internal_error("no node");
	if (N == N->owner->root) Trees::remove_root(N->owner);
	N->owner = of->owner;
	N->parent = of;
	N->next = NULL;
	if (of->child == NULL)
		of->child = N;
	else
		for (tree_node *S = of->child; S; S = S->next)
			if (S->next == NULL) {
				S->next = N; break;
			}
	Trees::verify_children(of);
}

void Trees::make_eldest_child(tree_node *N, tree_node *of) {
	if (N == NULL) internal_error("no node");
	if (of == NULL) internal_error("no node");
	if (N == N->owner->root) Trees::remove_root(N->owner);
	N->owner = of->owner;
	N->parent = of;
	N->next = of->child;
	of->child = N;
	Trees::verify_children(of);
}

void Trees::make_sibling(tree_node *N, tree_node *of) {
	if (N == NULL) internal_error("no node");
	if (of == NULL) internal_error("no node");
	if (N == N->owner->root) Trees::remove_root(N->owner);
	if (of == of->owner->root)
		internal_error("nodes cannot be siblings of the root");
	N->owner = of->owner;
	N->parent = of->parent;
	N->next = of->next;
	of->next = N;
	if (of->parent)	Trees::verify_children(of->parent);
}

@ Removing a node from a tree does not change its ownership -- it still belongs
to that tree.

=
void Trees::remove(tree_node *N) {
	if (N == NULL) internal_error("no node");
	if (N == N->owner->root) { Trees::remove_root(N->owner); return; }
	tree_node *p = N->parent;
	if (N->parent->child == N)
		N->parent->child = N->next;
	else
		for (tree_node *S = N->parent->child; S; S = S->next)
			if (S->next == N)
				S->next = N->next;
	N->parent = NULL;
	N->next = NULL;
	if (p)	Trees::verify_children(p);
}

int Trees::verify_children(tree_node *N) {
	if (N == NULL) internal_error("no node");
	if (N->type->verify_children)
		return (*(N->type->verify_children))(N);
	return TRUE;
}

@h Traversals.
These two functions allow us to traverse the tree, visiting each node along
the way and carrying a state as we do. The distinction is that //Trees::traverse_from//
iterates from and then below the given node, but doesn't go through its siblings,
whereas //Trees::traverse// does.

Note that it is legal to traverse the empty node, and does nothing.

=
void Trees::traverse_tree(heterogeneous_tree *T,
	void (*visitor)(tree_node *, void *, int L), void *state) {
	if (T == NULL) internal_error("no tree");
	Trees::traverse_from(T->root, visitor, state, 0);
}

void Trees::traverse_from(tree_node *N,
	void (*visitor)(tree_node *, void *, int L), void *state, int L) {
	if (N) {
		(*visitor)(N, state, L);
		Trees::traverse(N->child, visitor, state, L+1);
	}
}

void Trees::traverse(tree_node *N,
	void (*visitor)(tree_node *, void *, int L), void *state, int L) {
	for (tree_node *M = N; M; M = M->next) {
		(*visitor)(M, state, L);
		Trees::traverse(M->child, visitor, state, L+1);
	}
}
