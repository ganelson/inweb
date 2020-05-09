[LinkedLists::] Linked Lists and Stacks.

A simple implementation for single-linked lists of objects allocated by Foundation's
memory manager, and for last-in-first-out stacks of same.

@h Implementation.
Basically, there's a head structure, which points to a chain of body structures,
each linking to the next. But to reduce memory manager overhead, we're going to store
the first few body structures inside the head structure: that way, for a list of just
a few items, only one call to the memory manager is needed.

@d NO_LL_EARLY_ITEMS 32

=
typedef struct linked_list {
	struct linked_list_item *first_list_item;
	struct linked_list_item *last_list_item;
	int linked_list_length;
	struct linked_list_item early_items[NO_LL_EARLY_ITEMS];
	CLASS_DEFINITION
} linked_list;

typedef struct linked_list_item {
	void *item_contents;
	struct linked_list_item *next_list_item;
} linked_list_item;

@ =
linked_list *LinkedLists::new(void) {
	linked_list *ll = CREATE(linked_list);
	ll->linked_list_length = 0;
	ll->first_list_item = NULL;
	ll->last_list_item = NULL;
	return ll;
}

@ The following runs in constant time, i.e., performs no loops. In general we
want speed rather than memory efficiency.

=
void LinkedLists::add(linked_list *L, void *P, int to_end) {
	if (L == NULL) internal_error("null list");
	linked_list_item *item = NULL;
	if (L->linked_list_length < NO_LL_EARLY_ITEMS)
		item = &(L->early_items[L->linked_list_length]);
	else
		item = CREATE(linked_list_item);
	CREATE(linked_list_item);
	item->item_contents = P;
	if (to_end) {
		item->next_list_item = NULL;
		if (L->last_list_item == NULL) {
			L->first_list_item = item;
			L->last_list_item = item;
		} else {
			L->last_list_item->next_list_item = item;
			L->last_list_item = item;
		}
	} else {
		item->next_list_item = L->first_list_item;
		L->first_list_item = item;
		if (L->last_list_item == NULL) L->last_list_item = item;			
	}
	L->linked_list_length++;
}

@ Because of the direction of the links, only removing from the front is quick:

=
void *LinkedLists::remove_from_front(linked_list *L) {
	if (L == NULL) internal_error("null list");
	if (L->first_list_item == NULL) internal_error("empty list can't be popped");
	linked_list_item *top = L->first_list_item;
	L->first_list_item = top->next_list_item;
	if (L->first_list_item == NULL) L->last_list_item = NULL;
	L->linked_list_length--;
	return top->item_contents;
}

@ It's rather slower to delete from a known position in the middle:

=
void *LinkedLists::delete(int N, linked_list *L) {
	if (L == NULL) internal_error("null list");
	if ((N < 0) || (N >= L->linked_list_length)) internal_error("index not valid");
	if (N == 0) return LinkedLists::remove_from_front(L);

	for (linked_list_item *item = L->first_list_item; item; item = item->next_list_item) {
		N--;
		if (N == 0) {
			if (L->last_list_item == item->next_list_item) L->last_list_item = item;
			void *contents_deleted = item->next_list_item->item_contents;
			item->next_list_item = item->next_list_item->next_list_item;
			L->linked_list_length--;
			return contents_deleted;
		}
	}

	internal_error("index not found");
	return NULL;
}

@h A function call API.

=
int LinkedLists::len(linked_list *L) {
	return L?(L->linked_list_length):0;
}
linked_list_item *LinkedLists::first(linked_list *L) {
	return L?(L->first_list_item):NULL;
}
void *LinkedLists::entry(int N, linked_list *L) {
	if ((N < 0) || (L == NULL) || (N >= L->linked_list_length)) return NULL;
	for (linked_list_item *I = L->first_list_item; I; I = I->next_list_item)
		if (N-- == 0)
			return I->item_contents;
	return NULL;
}
linked_list_item *LinkedLists::last(linked_list *L) {
	return L?(L->last_list_item):NULL;
}
linked_list_item *LinkedLists::next(linked_list_item *I) {
	return I?(I->next_list_item):NULL;
}
void *LinkedLists::content(linked_list_item *I) {
	return I?(I->item_contents):NULL;
}

@h A macro-ized API.
These intentionally hide the implementation. The difference between
|FIRST_IN_LINKED_LIST| and |FIRST_ITEM_IN_LINKED_LIST| is that one returns
the first structure in the list, and the other returns the first
|linked_list_item| chunk in the list. From the latter you can make the
former using |CONTENT_IN_ITEM|, but not vice versa. The same object
may be listed in many different lists, so if all you have is the object,
you don't know its place in the list.

@d NEW_LINKED_LIST(T)
	(LinkedLists::new())

@d FIRST_ITEM_IN_LINKED_LIST(T, L)
	(LinkedLists::first(L))

@d ENTRY_IN_LINKED_LIST(N, T, L)
	((T *) (LinkedLists::entry(N, L)))

@d DELETE_FROM_LINKED_LIST(N, T, L)
	((T *) (LinkedLists::delete(N, L)))

@d LAST_ITEM_IN_LINKED_LIST(T, L)
	(LinkedLists::last(L))

@d NEXT_ITEM_IN_LINKED_LIST(I, T)
	(LinkedLists::next(I))

@d CONTENT_IN_ITEM(I, T)
	((T *) (LinkedLists::content(I)))

@d ADD_TO_LINKED_LIST(I, T, L)
	LinkedLists::add(L, (void *) (I), TRUE)

@d FIRST_IN_LINKED_LIST(T, L)
	((T *) (LinkedLists::content(LinkedLists::first(L))))

@d LAST_IN_LINKED_LIST(T, L)
	((T *) (LinkedLists::content(LinkedLists::last(L))))

@ The following macro requires slight care to use: the list |L| needs to be
calculable without side-effects. There's no such worry over |P| or |T|, since
they're just identifier names: the loop variable and the type name respectively.

Note that the loop variable |P| must already be defined. Inside the loop body,
a new variable will also then exist, |P_item|, to refer to the item which
points to |P|. This allows us to iterate despite the comments above.

@d LOOP_OVER_LINKED_LIST(P, T, L)
	for (linked_list_item *P##_item = (P = FIRST_IN_LINKED_LIST(T, L), FIRST_ITEM_IN_LINKED_LIST(T, L));
		P##_item;
		P##_item = (P = CONTENT_IN_ITEM(NEXT_ITEM_IN_LINKED_LIST(P##_item, T), T), NEXT_ITEM_IN_LINKED_LIST(P##_item, T)))

@h LIFO stacks.
The above gives us an almost free implementation of LIFO, last-in-first-out,
stacks, where we represent a stack as a linked list whose first entry is at
the front. To push an item, we add it at the front; to pull, we remove the
front iten.

We provide an abstract type name for these stacks, even though they're the
exact same structure. For reasons to do with the way |typedef| works in C,
it is awkward to typedef the two names together, so we'll simply use the
preprocessor:

@d lifo_stack linked_list

@ Otherwise, it's macros all the way:

@d NEW_LIFO_STACK(T)
	(LinkedLists::new())

@d PUSH_TO_LIFO_STACK(I, T, L)
	LinkedLists::add((L), (void *) (I), FALSE)

@d PULL_FROM_LIFO_STACK(T, L)
	((T *) LinkedLists::remove_from_front(L))

@d POP_LIFO_STACK(T, L)
	(LinkedLists::remove_from_front(L))

@d TOP_OF_LIFO_STACK(T, L)
	FIRST_IN_LINKED_LIST(T, L)

@d LIFO_STACK_EMPTY(T, L)
	((LinkedLists::len(L) == 0)?TRUE:FALSE)

@d LOOP_DOWN_LIFO_STACK(P, T, L)
	LOOP_OVER_LINKED_LIST(P, T, L)
