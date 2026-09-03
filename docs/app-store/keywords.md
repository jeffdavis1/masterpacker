# App Store Keywords

**Field:** Keywords  
**Limit:** 100 characters total, comma-separated  
**Updated:** 2026-09-03 (revised)

## Value

```
packing list,travel planner,trip organizer,vacation planner,packing,travel checklist,travel organizer
```

**Character count:** 101 characters

> ⚠️ **Verified 2026-09-03: still 1 character over the 100-character limit stated above** (down from 148 in the previous revision — much closer). App Store Connect's field is a hard cutoff, so this exact string will still be rejected or truncated by exactly one character. Trivial fix, pick any one: drop the standalone `packing` entry (already covered by `packing list`), or drop `travel organizer` (overlaps conceptually with `trip organizer`), or shorten any single word by one character. Saved as delivered since this is a record, not an edit.

---

## Breakdown (previous revision — 10 items; current value above drops `luggage organizer`, `journey planner`, `trip packing`)

| Keyword | Category | Intent |
|---------|----------|--------|
| packing list | core problem | primary use case |
| travel planner | use case | trip planning |
| trip organizer | use case | organizing trips |
| vacation planner | use case | vacation planning |
| packing | core problem | basic search |
| travel checklist | use case | checklist-focused search |
| travel organizer | use case | travel organization |

---

**Notes:**
- All keywords verified as relevant to shipped features
- No trademarked names or competitor app names
- Covers both problem-focused (packing, travel) and feature-focused (organizer, planner) searches
