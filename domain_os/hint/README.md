# The HINT subsystem in Domain Pascal

The hint file (where remote objects were last found) and the small local
cache of lookup answers.

## Layout

Two map modules, so two module files:

| segment | section | routines / objects | Pascal |
|---------|---------|--------------------|--------|
| HINT_ code, 0x278 bytes | OS_INIT_PROC | hint_$clear_hintfile, HINT_$INIT, HINT_$INIT_CACHE | `hint.pas`, `[section(os_init_proc, os_init_data)]` |
| HINT_ code, 0x540 bytes | .TEXT | HINT_$SHUTDN, _$GET_HINTS, hint_$add_internal, _$ADDI, _$ADD, _$ADDU, _$ADD_NET, _$GET_NET, _$LOOKUP_CACHE, _$ADD_CACHE | `hint.pas`, no attribute (the default) |
| HINT_ data, 0x28 bytes | .DATA | the module's block, HINT_$HINTFILE_UID | `hint.pas`'s variables and one defined global |
| HINT_WIRED data, 0x14 bytes | WIRED_DATA | HINT_$EXCLUSION_LOCK | `hint_wired.pas`, data only |

`hint.pas` is `module hint_;` (.TEXT and .DATA are the defaults; the
OS_INIT_PROC routines reach the block by its absolute address).
`hint_wired.pas` is `module hint_wired, , wired_data;`, a unit with no
code (`tools/pascal_check.sh`
finds it by its heading, as `pchist/pchist.pas`).

The HINT_ block:

| offset | variable | type |
|--------|----------|------|
| +0x00 | `hint_$cache` | array[1..2] of hint_$cache_entry_t (12 bytes each) |
| +0x18 | HINT_$HINTFILE_UID (`define`d, map symbol) | uid_$t |
| +0x20 | `hint_$data_hintfile_ptr` | hint_$file_ptr_t |
| +0x24 | `hint_$cache_index` | integer |
| +0x26 | `hint_$bucket_index` | integer, initialized 1 |

HINT_$HINTFILE_PTR is a cell of the hand-written NET_ASM segment,
declared extern in `hint.ins.pas`, as node/node.ins.pas's NODE_$ME of
the same segment.

Routines: eleven globals (every map symbol), two module-local
(`internal`): hint_$clear_hintfile and hint_$add_internal, the first
routines of their segments, with no map symbols.  None is nested; none
is hand assembly.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| HINT_$clear_hintfile | `clear_hintfile.pas` |
| HINT_$INIT | `init.pas` |
| HINT_$INIT_CACHE | `init_cache.pas` |
| HINT_$SHUTDN | `shutdn.pas` |
| HINT_$GET_HINTS | `get_hints.pas` |
| HINT_$add_internal | `add_internal.pas` |
| HINT_$ADDI | `addi.pas` |
| HINT_$ADD | `add.pas` |
| HINT_$ADDU | `addu.pas` |
| HINT_$ADD_NET | `add_net.pas` |
| HINT_$GET_NET | `get_net.pas` |
| HINT_$LOOKUP_CACHE | `lookup_cache.pas` |
| HINT_$ADD_CACHE | `add_cache.pas` |
| (data) | the block in `hint.pas`, the lock in `hint_wired.pas`; HINT_$HINTFILE_PTR is NET_ASM's (hand-written data) |

## Insert files

- `hint.ins.pas`: the hint pair and its list of five, the slot, the
  bucket, the file (header and 65 buckets from 0), the cache entry, a
  UID with a packed low longword (for hint_$add_internal's reverse
  UID), the three extern variables of other segments, and the eleven
  headings, each with its reasons.
- `ast/ast.ins.pas`: AST_$TRUNCATE (`val_param`; uid an 8-byte value
  parameter the callee copies, `out result: boolean`).
- `name/name.ins.pas`: NAME_$DROP (the default convention; `var
  file_uid`, passed on to DIR_$DROPU, which sets it to UID_$NIL).
- `file/file.ins.pas`: FILE_$DELETE (a boolean function, the tail call
  of FILE_$DELETE_INT).
- Used as they are: `base`, `ec`, `ml` (ML_$EXCLUSION_INIT, _START,
  _STOP), `time` (TIME_$CLOCKH), `uid` (uid_$gen_low_t), `mst`
  (MST_$MAPS, MST_$UNMAP_PRIVI), `node` (NODE_$ME), `pkt`, `route`
  (ROUTE_$PORTP, ROUTE_$PORT and the port record's port_type and socket).

`hint.ins.pas`'s hint_$addr_t.node_id and HINT_$ADD's node_id are
linteger: hint_$add_internal stores the node unmasked into the reverse
UID's 20-bit field, dpc's form for a type with no negative values
(dpc masks an integer32 value).  The
foreign headings added for HINT (AST_$TRUNCATE, NAME_$DROP,
FILE_$DELETE) were checked against their bodies and against their other
callers' pushes.

## Open items

### Forms the image settles

- HINT_$clear_hintfile reaches the file through the block's +0x20, not
  through HINT_$HINTFILE_PTR; the one caller has set both to the same
  value.
- The block is four module variables and the defined global
  HINT_$HINTFILE_UID (a map symbol inside the segment), not one record.
- The header's port type and socket are two words, compared one by one
  (see the TODO).
- HINT_$INIT's map_info is a longword, as MST_$MAPS' other callers pass
  (see the TODO in `init.pas`).
- HINT_$ADDU has no key locals; HINT_$GET_HINTS's and
  hint_$add_internal's pointers are stepped addresses and `with`s.
- HINT_$LOOKUP_CACHE and HINT_$ADD_CACHE have one unlock that the found
  path branches to.
- hint_$add_internal's fall-through after the key test is the reverse
  hint (the test is `<>`).

### TODO(pascal)

- `clear_hintfile.pas`: two word fields copied as one longword (also
  HINT_$ADD_NET).
- `clear_hintfile.pas`: 16 frame bytes unaddressed (stand-in unused_20).
- `init.pas`: 8 frame bytes unaddressed (stand-in unused_10).
- `get_hints.pas`: frame bytes beyond the locals (stand-in unused_24).
- `add_internal.pas`: frame bytes beyond the locals (stand-in
  unused_28).