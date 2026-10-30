{ dir/dir.pas - the DIR module, directories: the per-object locks and
  handles, the page cache, the operation dispatcher and its handlers, the
  mount table.

  Image addresses:
    sau2  0x00E35038  DIR data (OS_INIT_DATA, 0x4 bytes)
    sau2  0x00E7DBF8  DIR data (.DATA, 0x212C bytes)

  One compilation unit: the map's DIR code segments in OS_INIT_PROC
  (DIR_$INIT, headed `[section(os_init_proc, os_init_data)]') and in
  .TEXT (DIR_$DO_OP .. DIR_$FIX_DIR), and its data segments in
  OS_INIT_DATA (4 bytes, zero) and .DATA (8492 bytes).

  DIR_WIRED (dir/dir_wired.pas), OLD_DIR (dir/old_dir.pas) and
  DIR_SERVER (dir/dir_server.pas) are the directory's other map modules;
  DIR_WIRED's objects are declared `extern' below.

  The .DATA block, zero except the values given, by its offset from A5
  (the block's start + 8):
    -0x008  the address of a zero longword cell after dir_$unlock_obj
    -0x004  the address of the cell 16#E0025 after dir_$lock_obj
    +0x000  dir_$link_buf            1024 bytes
    +0x400  dir_$entry_cache         111 * 40 bytes

    +0x1558 DIR_$MTTAB (defined)     the mount table, 164 bytes
    +0x15FC unused_15fc, a stand-in  4 bytes
    +0x1600 dir_$proc_flags          64 * 2 bytes, from pid 1
    +0x1680 dir_$lock_tab            32 * 16 bytes
    +0x1880 dir_$handle_tab          32 * 60 bytes

    +0x2000 dir_$name_offset_table   8 * 2 bytes: 0, 4, 16, 20, 12, 0, 0,
                                     0
    +0x2010 DIR_$ENTRY_CACHE_TOO_LONG_NAME .. DIR_$LK_WAITS (defined),
            eight longwords

    +0x2030 dir_$lock_free           4
    +0x2034 dir_$lock_in_use         4
    +0x2038 dir_$handle_free         4
    +0x203C dir_$handle_in_use       4
    +0x2040 dir_$link_buf_owner      2
    +0x2042 DIR_$OP_TAB (defined)    26 * 8 bytes, records 21..46

    +0x2112 (2 bytes: the next longword)
    +0x2114 the read-continuation cookies 16#00020001, 16#00010001,
            16#00000001
    +0x2120 '.bak', dir_$do_op_add_bak's static

  The routines live in one fragment file each (dir/<name>.pas), included
  below in image order; dir/README.md has their table.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/dir/dir.pas.  Check: tools/pascal_check.sh.
}
module dir;

{ TODO(pascal) the 4-byte OS_INIT_DATA block and the A5 load into it

  The map's 4-byte DIR segment in OS_INIT_DATA is zero, no object of the
  source that this module can name; DIR_$INIT loads A5 with its end and
  never uses it.  The same open point as file/file.pas's, acl/acl.pas's
  and xpd/xpd.pas's (the cause not known).  Until it is settled the
  module declares nothing for it. }

{ TODO(pascal) the two address cells before A5 in the .DATA block

  The block's first 8 bytes, at A5-8 and at A5-4, hold the addresses of
  two constant cells in DIR's code: a zero longword after dir_$unlock_obj
  and 16#E0025 after dir_$lock_obj.  The routines near the end of the
  segment push them where a routine within reach would push the
  constant's address PC-relative: the A5-4 cell for CRASH_SYSTEM's
  status (DIR_$CLEANUP three times, dir_$validate_pages once), the A5-8
  cell for AST_$PURIFY's page list (dir_$validate_pages) and
  FILE_$SET_REFCNT's count (dir_$do_op_fix_dir).  Every such site is
  more than 0x7FFF bytes past its cell, so out of a PC-relative
  operand's reach (the DIR .TEXT bullet), while the routines within
  reach take the same cells PC-relative (dir_$do_op_delete,
  dir_$create_dir_obj, dir_$write_def_prot).  A byte search of DIR's
  code finds these six sites and no others.  So the cells look like the
  compiler's own: a constant already placed in the code, reached through
  an address cell the compiler put before the block when a use lies out
  of PC reach.  The Pascal passes the constants as literals (each
  fragment says which) and declares nothing for the 8 bytes.  dpc does
  the same itself: it places two such cells at A5-8 and at A5-4,
  relocated to constants in its code, and pushes through them at five
  sites (the block compares identical but for the two cells, whose
  targets the compare does not verify).  What decides the cells' order
  in the original is not known. }

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'uid/uid.ins.pas';
%include 'node/node.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'mst/mst.ins.pas';
%include 'fim/fim.ins.pas';
%include 'cal/cal.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'rgyc/rgyc.ins.pas';
%include 'acl/acl.ins.pas';
%include 'ast/ast_acl.ins.pas';
%include 'audit/audit.ins.pas';
%include 'os/os.ins.pas';
%include 'disk/disk.ins.pas';
%include 'dbuf/dbuf.ins.pas';
%include 'fm/fm.ins.pas';
%include 'vtoc/vtoc.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'route/route.ins.pas';
%include 'network/network.ins.pas';
%include 'netlog/netlog.ins.pas';
%include 'bat/bat.ins.pas';
%include 'name/name.ins.pas';
%include 'rem_name/rem_name.ins.pas';
%include 'hint/hint.ins.pas';
%include 'volx/volx.ins.pas';
%include 'wp/wp.ins.pas';
%include 'dir/dir.ins.pas';
%include 'rem_file/rem_file.ins.pas';

const
  { The entry types of the SR10 directory format, the low three bits of
    an entry's first byte: 2 a file, 3 a hard link, 4 a soft link, and
    1, which dir_$write_entry_to_page refuses on a leaf page (an
    interior page's entry). }
  dir_entry_interior = 1;
  dir_entry_file = 2;
  dir_entry_hard_link = 3;
  dir_entry_soft_link = 4;

type
  dir_$handle_ptr_t = ^dir_$handle_t;
  dir_$lock_entry_ptr_t = ^dir_$lock_entry_t;

  { One per-object lock record, 0x10 bytes: the free list's link or, in
    use, the locked object's UID, at 0x00; the queue of waiting handles
    at 0x08; -1 for a writer or the readers' count at 0x0C; the slot
    number at 0x0E (DIR_$INIT numbers them). }
  dir_$lock_entry_t = record
    case integer of
      1: (next: dir_$lock_entry_ptr_t);   { 0x00 }
      2: (uid: uid_$t;                    { 0x00 }
          waiters: dir_$handle_ptr_t;     { 0x08 }
          lock_count: integer;            { 0x0C }
          index: integer);                { 0x0E }
  end;

  { One slot of a handle's two-slot page cache, 8 bytes, as dir_$map_page
    indexes it: the group number (page div 32) at +2 and the mapped base
    of its 0x8000 bytes at +4; the array starts at the handle's +0x20
    and the field at +2 of each element.  Slot 0's first word is the
    mapping's active flag and its alignment byte, slot 1's NAME's
    reserved_08 (below).  The group is pinteger: widened with zeros for
    its compare. }
  dir_$page_cache_t = record
    unused_0: integer;                    { 0x00 }
    group: pinteger;                      { 0x02 }
    base: integer32;                      { 0x04 }
  end;

  { The 16 bytes at a handle's +0x20: NAME's mapping record
    (name/name.ins.pas name_$mapped_info_t), copied whole from and to
    NAME's per-directory records by dir_$validate_handle and
    dir_$unmap_pages, its active flag tested and stored, and the same
    bytes as the page cache's two slots (above). }
  dir_$handle_map_t = record
    case integer of
      1: (info: name_$mapped_info_t);     { 0x00 }
      2: (slot: array[0..1] of dir_$page_cache_t);
                                          { 0x00 }
  end;

  { One directory handle, 0x3C bytes.  length is linteger: dir_$open_dir
    compares it unsigned and divides it by shifts; dir_$validate_handle
    only assigns it. }
  dir_$handle_t = record
    uid: uid_$t;                          { 0x00 }
    owner: integer;                       { 0x08 }
    lock_mode: integer;                   { 0x0A }
    dir_kind: integer;                    { 0x0C }
    split_busy: boolean;                  { 0x0E }
    unused_0f: char;                      { 0x0F }
    length: linteger;                     { 0x10 }
    wired_page: integer32;                { 0x14 }
    buf: univ_ptr;                        { 0x18 }
    max_slots: integer;                   { 0x1C }
    cur_slot: integer;                    { 0x1E }
    map: dir_$handle_map_t;               { 0x20 }
    next: dir_$handle_ptr_t;              { 0x30 }
    lock_entry: dir_$lock_entry_ptr_t;    { 0x34 }
    slot_index: integer;                  { 0x38 }
    volume: integer;                      { 0x3A }
  end;

  { A directory page's header word, a packed record of 16 bits, its
    first field in the high bits (ref 3.10.7): the kind (bits 15..14),
    the reclaimable bit 13, and the format (bits 5..0), which
    dir_$open_dir checks against 5.  Only format is checked by a
    fragment; kind and reclaimable are a reading of the bits. }
  { Bits 12 and 11 are two flags dir_$alloc_split_page uses: split_mark,
    set on the level-1 copy of a root split's path, merged into the
    byte; and seg_map_valid, the root page's "the segment map may be
    searched", read on the word, cleared on the byte.  unused_6 is bits
    10..6. }
  dir_$page_flags_t = packed record
    kind: 0..3;                           { bits 15..14 }
    reclaimable: 0..1;                    { bit 13 }
    split_mark: boolean;                  { bit 12 }
    seg_map_valid: boolean;               { bit 11 }
    unused_6: 0..31;                      { bits 10..6 }
    format: 0..63;                        { bits 5..0 }
  end;

  { A directory page's 0x12-byte header (the UID's two halves as one
    uid_$t).  page_no is pinteger: dir_$insert_entry widens it with
    zeros for a link's location; every other use compares it with 0 or
    copies it. }
  dir_$page_hdr_t = record
    flags: dir_$page_flags_t;             { 0x00 }
    dir_uid: uid_$t;                      { 0x02 }
    page_no: pinteger;                    { 0x0A }
    next_page: integer;                   { 0x0C }
    index_end: integer;                   { 0x0E }
    heap_base: integer;                   { 0x10 }
  end;
  dir_$page_hdr_ptr_t = ^dir_$page_hdr_t;

  { A page as dir_$find_entry reads it: the header, and on the root page
    the word at +0x14, the length of the root area between the header
    and the index table. }
  { The page's first word as a whole, the second variant:
    dir_$do_op_dir_readu tests it for zero. }
  { The whole page, 0x400 bytes, the third variant:
    dir_$alloc_split_page copies one page to another as a record (256
    longwords).
    The first word as a set of 0..15, the fourth variant: member 13 (the
    header's reclaimable bit, the "reclaimable entries" flag) set by
    dir_$move_entries_to_page, and tested and cleared by
    dir_$compact_page_entries on the word and on the byte:
    the member forms, which the packed field reclaimable (a 0..1
    subrange, `= 1') would not give.  The root page's two default
    protections, the fifth variant: the directories' at +0x1A and the
    files' at +0x4E, each a dir_$def_prot_t (below), as
    dir_$read_def_prot copies them for ACL_$DIR_ACL and ACL_$FILE_ACL.
    The root page's byte at +0x12 and word at +0x16, which
    dir_$create_dir_obj initializes (the entry count 1, the base data
    offset 16#68, and root_len as that plus 8): the first variant's
    entry_count and the byte unused_13, and base_offset follows
    root_len. }
  { One default protection on the root page, 0x34 bytes: the protection
    record, then the default ACL's UID. }
  dir_$def_prot_t = record
    prot: acl_$prot_data_t;               { 0x00 }
    acl_uid: uid_$t;                      { 0x2C }
  end;
  dir_$root_page_t = record
    case integer of
      1: (hdr: dir_$page_hdr_t;           { 0x00 }
          entry_count: dir_$byte_t;       { 0x12 }
          unused_13: char;                { 0x13 }
          root_len: integer;              { 0x14 }
          base_offset: integer);          { 0x16 }
      2: (word_00: integer);              { 0x00 }
      3: (longs: array[1..256] of integer32);
                                          { 0x00 }
      4: (flag_set: set of 0..15);        { 0x00 }
      5: (unused_00: array[0..25] of char;
                                          { 0x00 }
          dir_def_prot: dir_$def_prot_t;  { 0x1A }
          file_def_prot: dir_$def_prot_t);
                                          { 0x4E }
  end;
  dir_$root_page_ptr_t = ^dir_$root_page_t;

  { A page's index table, from 1: entry k's offset in the page at
    2 * k - 2 (dir_$find_entry).  The bound is a 0x400-byte page's
    words. }
  dir_$index_t = array[1..511] of integer;
  dir_$index_ptr_t = ^dir_$index_t;

  { A run of words in a page, from 1, as dir_$move_entries_to_page
    copies an entry and dir_$compact_page_entries moves the entries
    below a dead one up; and a pointer to one word, an index slot
    dir_$write_entry_to_page fills.  The bound is a page's words. }
  dir_$words_t = array[1..512] of integer;
  dir_$words_ptr_t = ^dir_$words_t;
  dir_$word_ptr_t = ^integer;

  { The head of a directory entry: its type in the low three bits of
    byte 0, the name's length at +1, and the word at +2, an interior
    entry's child page (passed to dir_$map_page) and a soft link's text
    length.  A file's or a hard link's UID at +4 and a hard link's
    longword at +0xC, which dir_$lookup_entry copies.  A soft link's
    other view, from +4 (the inner second variant): the page of its
    text, -1 for text kept in the entry (dir_$do_op_read_linku compares
    it and passes it on to dir_$map_link_page); and its name at +0xC
    (dir_$name_offset_table's 16#0C for type 4), the text right after
    it.  The whole record is a variant, its first variant the fields
    above, with two more longwords and a word that
    dir_$write_entry_to_page clears or sets when it builds an entry: a
    type-3 entry's +0x10 (type 3's name follows it, at
    dir_$name_offset_table's 16#14), and a soft link's +0x6 and +0xA:
    reserved_10, unused_06 and unused_0a.  The second variant is the
    first word as a set of 0..15: dir_$move_entries_to_page marks an
    entry dead with its member 15 (`s := s + [c]' on the byte that
    holds it), dir_$compact_page_entries tests it as the word's sign,
    and dir_$write_entry_to_page clears the word (`flag_set := []').
    The third variant is byte 0 as a packed record (dir_$entry_bits_t):
    its type field merged by dir_$write_entry_to_page, the field forms
    (`flags & 7', the readers' form, compiles the same). }
  dir_$entry_bits_t = packed record
    dead: boolean;                        { bit 7 }
    unused_3: 0..15;                      { bits 6..3 }
    kind: 0..7;                           { bits 2..0 }
  end;
  dir_$entry_t = record
    case integer of
      1: (flags: dir_$byte_t;             { 0x00 }
          name_len: dir_$byte_t;          { 0x01 }
          child: integer;                 { 0x02 }
          case integer of
            1: (uid: uid_$t;              { 0x04 }
                extra: integer32;         { 0x0C }
                reserved_10: integer32);  { 0x10 }
            2: (link_page: integer;       { 0x04 }
                unused_06: integer32;     { 0x06 }
                unused_0a: integer;       { 0x0A }
                link_name: name_$long_name_t);
                                          { 0x0C }
            3: (child_name: name_$long_name_t));
                                          { 0x04 }
      2: (flag_set: set of 0..15);        { 0x00 }
      3: (bits: dir_$entry_bits_t);       { 0x00 }
  end;
  dir_$entry_ptr_t = ^dir_$entry_t;

  { An entry's name, 1-based from its type's offset (dir_$find_entry). }
  dir_$name_ptr_t = ^name_$long_name_t;

  { One level of the root-to-leaf path dir_$find_entry records: the page
    number and the index, from 1; eight levels, dir_$add_entry's buffer
    (it passes the depth 8).  page_no is pinteger: dir_$remove_entry
    and its nested routine widen it with zeros. }
  dir_$page_path_t = record
    page_no: pinteger;                    { 0x00 }
    entry_idx: integer;                   { 0x02 }
  end;
  dir_$path_t = array[1..8] of dir_$page_path_t;

  { A cache slot's length and flag bits, the 16 bits at its +0x16: the
    name's length in bits 15..10, read and merged by the cache's
    routines; bit 8 a boolean, set when the rights were read for the
    entry.  A packed record of 16 bits, its first field in the high bits
    (ref 3.10.7), as dir_$page_flags_t.  unused_9 is bit 9, unused_0 the
    byte at +0x17, the name's first character. }
  dir_$cache_flags_t = packed record
    len: 0..63;                           { bits 15..10 }
    unused_9: 0..1;                       { bit 9 }
    acl_ok: boolean;                      { bit 8 }
    unused_0: 0..255;                     { bits 7..0 }
  end;

  { One slot of the per-UID entry cache, 0x28 bytes.  The time at 0x10 is
    AST_$GET_DTV's, compared and stored as a whole.  From 0x16 three
    views of the same bytes (ref 3.10.3): the flags record; the name,
    character i at +0x16 + i, an array from 0 whose element 0 is the
    flags' high byte (a char array is word aligned, ref 3.10.5.5, so one
    from 1 cannot start at +0x17); and the word, its bit 8 tested on the
    word (the whole form: an integer bit test).  The names: entry_name
    renamed from name, since dir_$get_entry_cached reads it in a `with'
    beside its parent's `name'. }
  dir_$entry_cache_t = record
    dir_uid: uid_$t;                      { 0x00 }
    entry_uid: uid_$t;                    { 0x08 }
    dtv: time_$clock_t;                   { 0x10 }
    case integer of
      1: (lf: dir_$cache_flags_t);        { 0x16 }
      2: (entry_name: array[0..17] of char);
                                          { 0x16 }
      3: (w: integer);                    { 0x16 }
  end;

  { The mount table, DIR_$MTTAB, 0xA4 bytes: the count, then entry n of
    the three tables at +0x04 + 8 * (n - 1), +0x44 + 8 * (n - 1) and
    +0x84 + 4 * (n - 1). }
  dir_$mttab_t = record
    count: integer32;                     { 0x00 }
    mount_uid: array[1..8] of uid_$t;     { 0x04 }
    mount_tgt: array[1..8] of uid_$t;     { 0x44 }
    mount_node: array[1..8] of integer32; { 0x84 }
  end;

  { A process's flags word in dir_$proc_flags: dir_$lock_obj tests member
    1, the short lock wait, and DIR_$DO_OP stores the whole word from
    the request. }
  dir_$proc_flags_t = set of 0..15;

  { dir_$op_tab_entry_t and DIR_$OP_TAB's extern declaration are in
    dir/dir.ins.pas: DIR_$SERVER, in the DIR_SERVER module, reads the
    table too (dir/server.pas). }

  { DIR_$RESOLVE's request and reply: the header and the resolve body,
    at the offsets DIR_$RESOLVE writes and reads, and the request's
    0x100 bytes past its body that nothing addresses, the stand-in
    unused_b0 (see the TODO(pascal) in dir/resolve.pas); the reply 0x34
    bytes, the size DIR_$RESOLVE gives DIR_$DO_OP.  A dpc probe
    confirmed every offset and the sizes (0x1B0, 0x34).  The names are
    dir/dir.ins.pas dir_$reply_t's variant's. }
  dir_$resolve_req_t = record
    hdr: dir_$req_hdr_t;                  { 0x00 }
    body: dir_$req_resolve_t;             { 0x8E }
    unused_b0: array[1..256] of char;     { 0xB0 }
  end;
  dir_$resolve_reply_t = record
    hdr: dir_$reply_hdr_t;                { 0x00 }
    more: boolean;                        { 0x14 }
    loop: boolean;                        { 0x15 }
    state: dir_$resolve_state_t;          { 0x16 }
    link_count: integer;                  { 0x2E }
    redirect: integer32;                  { 0x30 }
  end;

  { The request and reply of DIR_$GET_ENTRYU's nested routine (operation
    16#44): the header and a name body, 0x190 bytes; the reply, 0x22
    bytes: the header, the entry's type word at +0x14, its UID at +0x16,
    its longword at +0x1E.  A dpc probe confirmed every offset and the
    sizes.  The names are dir/dir.ins.pas dir_$reply_t's variant's (len,
    entry, extra) and dir_$req_name_t's. }
  dir_$entry_req_t = record
    hdr: dir_$req_hdr_t;                  { 0x00 }
    body: dir_$req_name_t;                { 0x8E }
  end;
  dir_$entry_reply_t = record
    hdr: dir_$reply_hdr_t;                { 0x00 }
    len: integer;                         { 0x14 }
    entry: uid_$t;                        { 0x16 }
    extra: integer32;                     { 0x1E }
  end;

  { DIR_$READ_LINKU's request and reply (operation 16#3E): the header and
    the link body (dir/dir.ins.pas dir_$req_add_link_t), 0x196 bytes;
    the reply, 0x1E bytes: the header, the text's length at +0x14 and
    the UID at +0x16.  A dpc probe confirmed every offset and the sizes.
    The names are dir/dir.ins.pas dir_$reply_t's variant's (len,
    entry). }
  dir_$link_req_t = record
    hdr: dir_$req_hdr_t;                  { 0x00 }
    body: dir_$req_add_link_t;            { 0x8E }
  end;
  dir_$link_reply_t = record
    hdr: dir_$reply_hdr_t;                { 0x00 }
    len: integer;                         { 0x14 }
    entry: uid_$t;                        { 0x16 }
  end;

  { DIR_$DIR_READU's request and reply (operation 16#42), as its nested
    dir_$dir_readu_via_do_op builds them: the header and the read body
    (dir/dir.ins.pas dir_$req_readu_t), 0x1A0 bytes; the reply, 0x24
    bytes: the header, then the continuation, the count, the bytes used
    and the last entry's offset at +0x14, +0x18, +0x1C and +0x20.  A dpc
    probe confirmed every offset and the sizes.  The names are
    dir/dir.ins.pas dir_$reply_t's variant's (continuation, count, size,
    last_offset). }
  dir_$readu_req_t = record
    hdr: dir_$req_hdr_t;                  { 0x00 }
    body: dir_$req_readu_t;               { 0x8E }
  end;
  dir_$readu_reply_t = record
    hdr: dir_$reply_hdr_t;                { 0x00 }
    continuation: integer32;              { 0x14 }
    count: integer32;                     { 0x18 }
    size: integer32;                      { 0x1C }
    last_offset: integer32;               { 0x20 }
  end;

  { dir_$find_uid_internal's request and reply (operation 16#46): the
    header and the find-UID body (dir/dir.ins.pas dir_$req_find_uid_t),
    0x98 bytes; the reply, 0x11A bytes: the header, the name's length at
    +0x14, the extra longword at +0x16 and the name from +0x1A, 256
    bytes to the size.  The names: dir/dir.ins.pas dir_$reply_t's sixth
    variant's (name_len, find_extra, name); the name's bound the reply's
    size. }
  dir_$find_uid_req_t = record
    hdr: dir_$req_hdr_t;                  { 0x00 }
    body: dir_$req_find_uid_t;            { 0x8E }
  end;
  dir_$find_uid_reply_t = record
    hdr: dir_$reply_hdr_t;                { 0x00 }
    name_len: integer;                    { 0x14 }
    find_extra: integer32;                { 0x16 }
    name: array[1..256] of char;          { 0x1A }
  end;

  { dir_$add_entry_internal's request (operation 16#2A), 0x19C bytes:
    the header and the add-entry body (dir/dir.ins.pas
    dir_$req_add_entry_t): the operation byte at +0x03, the directory's
    UID at +0x04, the version at +0x0E, the name's length at +0x8E, the
    object's UID at +0x90, the extra longword at +0x98 and the name from
    +0x9C; its reply is the bare header, dir_$reply_hdr_t, 0x14 bytes.
    A dpc probe confirmed the offsets and the size. }
  dir_$add_entry_req_t = record
    hdr: dir_$req_hdr_t;                  { 0x00 }
    body: dir_$req_add_entry_t;           { 0x8E }
  end;

  { The request of operations 16#2C and 16#34 (DIR_$ADD_HARD_LINKU,
    DIR_$ADD_BAKU): the header and the UID-and-name body
    (dir/dir.ins.pas dir_$req_uid_name_t), 0x198 bytes: the length at
    +0x8E, the UID at +0x90, the name from +0x98; and DIR_$ADD_BAKU's
    reply, 0x1C bytes: the header, the replaced backup's UID at +0x14.
    A dpc probe confirmed the offsets and sizes.  The name uid is
    dir/dir.ins.pas dir_$reply_t's variant's. }
  dir_$uid_name_req_t = record
    hdr: dir_$req_hdr_t;                  { 0x00 }
    body: dir_$req_uid_name_t;            { 0x8E }
  end;
  dir_$uid_reply_t = record
    hdr: dir_$reply_hdr_t;                { 0x00 }
    uid: uid_$t;                          { 0x14 }
  end;

  { The requests of operations 16#36 (DIR_$DELETE_FILEU) and 16#2E
    (DIR_$DROP_HARD_LINKU), 0x192 bytes each: the header, the length at
    +0x8E, the two boolean bytes at +0x90 and +0x91 or the flag word at
    +0x90, and the name from +0x92.  Their replies are
    dir_$uid_reply_t's 0x1C bytes.  A dpc probe confirmed the offsets and
    sizes.  The bodies are dir/dir.ins.pas's. }
  dir_$delete_file_req_t = record
    hdr: dir_$req_hdr_t;                  { 0x00 }
    body: dir_$req_delete_file_t;         { 0x8E }
  end;
  dir_$word_name_req_t = record
    hdr: dir_$req_hdr_t;                  { 0x00 }
    body: dir_$req_word_name_t;           { 0x8E }
  end;

  { DIR_$CNAMEU's operation-16#32 request, 0x292 bytes (dir_$request_t's
    size): the header, then the two lengths and the old name
    (dir/dir.ins.pas dir_$req_cname_t), and the body as text from 1 at
    +0x8E, where the new name follows the old one at index i +
    base_size + old_len.  A dpc probe confirmed old_len +0x8E, new_len
    +0x90, name +0x92, text[1] +0x8E, size 0x292. }
  dir_$cname_req_t = record
    hdr: dir_$req_hdr_t;                  { 0x00 }
    case integer of
      1: (body: dir_$req_cname_t);        { 0x8E }
      2: (text: array[1..516] of char);
                                          { 0x8E }
  end;

  { DIR_$GET_DEF_PROTECTION's operation-16#56 request, 0x96 bytes: the
    header and the ACL type's UID at +0x8E (the size sent is the
    record's base_size alone); and its reply, 0x48 bytes: the header,
    the protection record at +0x14 and the default ACL's UID at +0x40.
    A dpc probe confirmed the offsets and sizes. }
  dir_$uid_req_t = record
    hdr: dir_$req_hdr_t;                  { 0x00 }
    acl_type: uid_$t;                     { 0x8E }
  end;
  dir_$def_prot_reply_t = record
    hdr: dir_$reply_hdr_t;                { 0x00 }
    prot: acl_$prot_data_t;               { 0x14 }
    acl_uid: uid_$t;                      { 0x40 }
  end;

  { DIR_$SET_DEF_PROTECTION's operation-16#54 request, 0xCA bytes: the
    header, the ACL type's UID at +0x8E, the protection record at +0x96,
    the default ACL's UID at +0xC2 (dir/dir.ins.pas
    dir_$req_set_def_prot_t's offsets, the record the protection's own
    type here).  DIR_$SET_PROTECTION's operation-16#52 request, 0xC4
    bytes: the header, the protection record at +0x8E, the default ACL's
    UID at +0xBA, the protection type word at +0xC2
    (dir_$req_set_prot_t's offsets).  A dpc probe confirmed the offsets
    and sizes.  The names are dir/dir.ins.pas's bodies'. }
  dir_$set_def_prot_req_t = record
    hdr: dir_$req_hdr_t;                  { 0x00 }
    acl_type_uid: uid_$t;                 { 0x8E }
    prot: acl_$prot_data_t;               { 0x96 }
    acl_uid: uid_$t;                      { 0xC2 }
  end;
  dir_$set_prot_req_t = record
    hdr: dir_$req_hdr_t;                  { 0x00 }
    prot: acl_$prot_data_t;               { 0x8E }
    acl_uid: uid_$t;                      { 0xBA }
    prot_type: integer;                   { 0xC2 }
  end;
  { DIR_$SET_DEFAULT_ACL's request, operation 16#4C, 0x9E bytes: the
    header and dir/dir.ins.pas's body for the operation (the ACL type's
    UID at +0x8E, the ACL's at +0x96).  A dpc probe confirmed the
    offsets and the size. }
  dir_$set_default_acl_req_t = record
    hdr: dir_$req_hdr_t;                  { 0x00 }
    body: dir_$req_uid_pair_t;            { 0x8E }
  end;

  { The requests of operations 16#5A (DIR_$ADD_MOUNT) and 16#5C
    (DIR_$DROP_MOUNT), 0x9A bytes: the header (the op at +0x03, the UID
    at +0x04, the version at +0x0E), the mount UID at +0x8E and the node
    word at +0x96: dir/dir.ins.pas dir_$req_mount_t.  A dpc probe
    confirmed the offsets and the size. }
  dir_$mount_req_t = record
    hdr: dir_$req_hdr_t;                  { 0x00 }
    body: dir_$req_mount_t;               { 0x8E }
  end;

  { A UID whose low half's node (its low 20 bits) is stored on its own:
    DIR_$FIND_NET merges its index into the field unmasked, uid/
    uid.ins.pas uid_$gen_low_t's node (bat/bat.ins.pas
    bat_$node_word_t's form, BAT_$MOUNT's store of NODE_$ME), and passes
    the whole on as a UID. }
  dir_$node_uid_t = record
    case integer of
      1: (uid: uid_$t);                   { 0x00 }
      2: (high: integer32;                { 0x00 }
          low: uid_$gen_low_t);           { 0x04 }
  end;

  { dir_$readu_entry_t and dir_$readu_entry_ptr_t are in
    dir/dir.ins.pas: OLD_DIR's DIR_$OLD_FIX_DIR reads such an entry
    from DIR_$OLD_DIR_READU. }

  { One entry of a DIR_READU reply in the old format (a reply version of
    0): the type at 0, the name's length at 2, the UID at 4, the extra
    longword at 0xC, the name from 0x10 (dir_$do_op_dir_readu fills
    them), no size word (the entries are name_len + 16#10 bytes, rounded
    to even).  The names as dir_$readu_entry_t's. }
  dir_$readu_old_entry_t = record
    enttype: pinteger;                    { 0x00 }
    entlen: pinteger;                     { 0x02 }
    entuid: uid_$t;                       { 0x04 }
    entextra: integer32;                  { 0x0C }
    entname: name_$long_name_t;           { 0x10 }
  end;
  dir_$readu_old_entry_ptr_t = ^dir_$readu_old_entry_t;

  { dir_$readu_cont_t and dir_$readu_buf_t are in dir/dir.ins.pas:
    DIR_$OLD_DIR_READU's heading takes them. }

  { AST_$GET_ACL_ATTRIBUTES' record (acl/acl.ins.pas ast_$acl_attr_t,
    0x38 bytes) with a boolean view of its byte +0x29 (the protection
    record's reserved_1d there, a char): dir_$do_op_cname tests it on
    its sign, and a set byte refuses the rename with
    status_$ast_only_local_access_allowed.  A dpc probe confirmed
    local_only +0x29, size 0x38. }
  dir_$acl_attr_view_t = record
    case integer of
      1: (attr: ast_$acl_attr_t);         { 0x00 }
      2: (unused_00: array[0..40] of char;
                                          { 0x00 }
          local_only: boolean);           { 0x29 }
  end;

{ DIR_WIRED's objects (dir/dir_wired.pas), named by their absolute
  addresses.  Declared here, not in dir/dir.ins.pas, so that the insert
  file needs neither ec/ec.ins.pas nor ml/ml.ins.pas. }
var
  dir_$wt_for_hdnl_ec: extern ec_$eventcount_t;
  dir_$wait_ecs: extern array[0..31] of ec_$eventcount_t;
  dir_$link_buf_mutex: extern ml_$exclusion_t;
  dir_$mutex: extern ml_$exclusion_t;

{ The globals this module defines in its .DATA block. }
var
  dir_$mttab: extern dir_$mttab_t;
  dir_$entry_cache_too_long_name: extern integer32;
  dir_$entry_cache_skipped_acl: extern integer32;
  dir_$entry_cache_tries: extern integer32;
  dir_$entry_cache_hits: extern integer32;
  dir_$hndl_waits: extern integer32;
  dir_$lk_timeouts: extern integer32;
  dir_$lk_wait_2: extern integer32;
  dir_$lk_waits: extern integer32;
  { DIR_$OP_TAB: extern in dir/dir.ins.pas (DIR_SERVER reads it). }

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above; offsets from A5). }
var
  dir_$link_buf: array[1..1024] of char;             { +0x000, zero }
  dir_$entry_cache: array[0..110] of dir_$entry_cache_t;
                                                     { +0x400, zero }

define
  dir_$mttab;                                        { +0x1558, zero }

var
  unused_15fc: integer32;                            { +0x15FC, zero:
                                                       never addressed }
  dir_$proc_flags: array[1..64] of dir_$proc_flags_t;
                                                     { +0x1600, zero }
  dir_$lock_tab: array[0..31] of dir_$lock_entry_t;  { +0x1680, zero }
  dir_$handle_tab: array[0..31] of dir_$handle_t;    { +0x1880, zero }
  dir_$name_offset_table: array[0..7] of integer :=
    [0, 4, 16#10, 16#14, 16#0C, 0, 0, 0];            { +0x2000 }

define
  dir_$entry_cache_too_long_name;                    { +0x2010, zero }
  dir_$entry_cache_skipped_acl;                      { +0x2014, zero }
  dir_$entry_cache_tries;                            { +0x2018, zero }
  dir_$entry_cache_hits;                             { +0x201C, zero }
  dir_$hndl_waits;                                   { +0x2020, zero }
  dir_$lk_timeouts;                                  { +0x2024, zero }
  dir_$lk_wait_2;                                    { +0x2028, zero }
  dir_$lk_waits;                                     { +0x202C, zero }

var
  dir_$lock_free: dir_$lock_entry_ptr_t;             { +0x2030, zero }
  dir_$lock_in_use: set of 0..31;                    { +0x2034, zero }
  dir_$handle_free: dir_$handle_ptr_t;               { +0x2038, zero }
  dir_$handle_in_use: set of 0..31;                  { +0x203C, zero }
  dir_$link_buf_owner: integer;                      { +0x2040, zero }

define
  dir_$op_tab := [[0, 0, 16#0E, 0], [0, 0, 16#0A, 0], [0, 0, 4, 8],
                  [0, 0, 2, 8], [1, 0, 4, 0], [1, 0, 16#0A, 8],
                  [0, 0, 4, 8], [0, 0, 2, 8], [0, 0, 2, 0], [0, 0, 8, 0],
                  [0, 0, 8, 16#0A], [0, 0, 2, 8], [0, 1, 16#12, 16#10],
                  [0, 0, 2, 16#0E], [0, 0, 16#0A, 6], [0, 0, 0, 0],
                  [0, 0, 8, 0], [0, 0, 16#10, 0], [0, 0, 8, 8],
                  [0, 0, 2, 0], [0, 0, 16#36, 0], [0, 0, 16#3C, 0],
                  [0, 0, 16#3C, 16#34], [0, 1, 16#22, 16#20],
                  [0, 0, 16#0C, 0], [0, 0, 16#0C, 0]];
                                                     { +0x2042: records
                                                       21..46 }

{ +0x2112 to the block's end are routines' statics, after the module
  variables, in routine order and from the next longword (the 2 bytes
  at +0x2112): the three read-continuation cookies at +0x2114 are
  dir_$do_op_dir_readu's (dir/do_op_dir_readu.pas; no other routine
  addresses +0x2114..+0x211F), and '.bak' at +0x2120 is
  dir_$do_op_add_bak's (its only reader: its fragment declares it). }

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order.  The ones whose fragments are not written yet join the list
  with them (dir/README.md). }
{ DIR_$DIR_READU (compiled, global).  The default convention:
  PROC2_$DELETE_CLEANUP pushes nine addresses, and the SVC table makes
  it a user call.  The modes from the body and its nested routines
  (dir/dir_readu.pas): dir_uid `in', name and name_len `in
  out' (pinteger: compared unsigned with 16#FF), continuation `in out'
  REM_NAME's record (passed on to REM_NAME_$DIR_READU's `in out'),
  max_entries and buf_size `in' integer32, buf `var' (passed on to
  DIR_$OLD_DIR_READU's `var'), count_ret and status_ret `out' (count_ret
  linteger: passed by address to DIR_$OLD_DIR_READU's linteger count,
  dir/dir.ins.pas).  Declared here, not in dir/dir.ins.pas: its
  continuation's type is rem_name/rem_name.ins.pas's, which
  dir.ins.pas's users need not include. }
procedure dir_$dir_readu(in dir_uid: uid_$t;
                         in out name: univ name_$long_name_t;
                         in out name_len: pinteger;
                         in out continuation: rem_name_$continuation_t;
                         in max_entries: integer32;
                         in buf_size: integer32;
                         var buf: univ dir_$readu_buf_t;
                         out count_ret: linteger;
                         out status_ret: status_$t);
  extern;

{  DIR_$GET_DEF_PROTECTION's,
  DIR_$SET_DEF_PROTECTION's and DIR_$SET_PROTECTION's extern headings,
  declared here since DIR parts 4 and 7, are in acl/acl.ins.pas now (the
  protection record's insert file; dir/dir.ins.pas's includers do not
  all include it), one copy each, with acl/acl.pas's copies gone. }

define
  dir_$init;
  dir_$do_op;
  dir_$resolve;
  dir_$get_entryu;
  dir_$read_linku;
  dir_$dir_readu;
  dir_$find_uid;
  dir_$find_net;
  dir_$addu;
  dir_$validate_root_entry;
  dir_$add_hard_linku;
  dir_$add_linku;
  dir_$add_baku;
  dir_$delete_fileu;
  dir_$dropu;
  dir_$drop_hard_linku;
  dir_$drop_linku;
  dir_$cnameu;
  dir_$get_def_protection;
  dir_$set_def_protection;
  dir_$set_protection;
  dir_$create_diru;
  dir_$drop_diru;
  dir_$set_dad;
  dir_$root_addu;
  dir_$set_acl;
  dir_$set_default_acl;
  dir_$get_default_acl;
  dir_$add_mount;
  dir_$drop_mount;
  dir_$cleanup;
  dir_$fix_dir;

{ dir_$validate_pages, forward: dir_$open_dir calls it before its body,
  with the handle's address, a boolean by value and the status's
  address; the callee clears the status first: `out'.  Module-local:
  `internal'.  dir/validate_pages.pas confirms the heading. }
{ body: dir/validate_pages.pas }
procedure dir_$validate_pages(var handle: dir_$handle_t; crash_flag: boolean;
                              out status_ret: status_$t);
  forward; internal;

{ dir_$remove_entry, forward: dir_$insert_entry, nested in
  dir_$add_entry before it, calls it with the handle's and the name's
  addresses (dir_$add_entry's by-address parameters' slots), two words
  by value, the UID's and the status's addresses.  The handle, the name
  and the word name_len are passed on to dir_$find_entry's `var', `in
  univ' and by-value word; the UID is written only, the status written
  first: `out'.  Module-local: `internal'.  dir/remove_entry.pas
  confirms the heading. }
{ body: dir/remove_entry.pas }
procedure dir_$remove_entry(var handle: dir_$handle_t;
                            in name: univ name_$long_name_t;
                            name_len: integer; op_type: integer;
                            out uid_ret: uid_$t;
                            out status_ret: status_$t);
  forward; internal;

{ dir_$read_def_prot, forward: dir_$add_bak_default_prot, nested in
  dir_$do_op_add_bak before it, calls it with the handle's address (the
  parent's pointer, its value), the ACL type UID ACL_$FILE_ACL by
  address, the protection record's and the UID's addresses, the
  status's.  The status is cleared first: `out'; the handle is passed on
  to dir_$map_page's `var'; the type UID only compared: `in'; the record
  and the UID written: `out'.  Module-local: `internal'.
  dir/read_def_prot.pas confirms the heading. }
{ body: dir/read_def_prot.pas }
procedure dir_$read_def_prot(var handle: dir_$handle_t; in acl_type: uid_$t;
                             out prot_buf: acl_$prot_data_t;
                             out acl_uid_ret: uid_$t;
                             out status_ret: status_$t);
  forward; internal;

{  FILE_$SET_PROT's heading is in acl/acl.ins.pas. }

{  AST_$GET_ACL_ATTRIBUTES' heading,
  declared here before, is ast/ast_acl.ins.pas's now (included above). }

{ The DIR_$DO_OP handlers, module-local routines after DIR_$DO_OP in
  image order, called from its arms (dir/do_op.pas).  Each heading is
  read from DIR_$DO_OP's pushes and the callee's prologue (a word or
  boolean by value, `internal'; the others by address).  The modes of
  the by-address parameters: `in' for the inputs DIR_$DO_OP takes from
  the request or its local UID copy; `out' where the callee writes the
  slot first (UID_$NIL stored) or, for the statuses, `out' as every DIR
  handler's status that it hands to dir_$open_dir's `out' or writes;
  `var' for the other results (the rules' choice when the use is not
  traced).  The handlers' own fragments confirm or correct these. }

{ dir_$do_op_resolve, forward; confirmed against the body
  (dir/do_op_resolve.pas): path_len a pinteger, compared unsigned;
  result the directory UID as a view (compared, replaced, handed to
  dir_$do_op_get_entryu's view), read then written: `in out';
  extra_ret, flags1, flags2, link_count and status_ret written first:
  `out' (link_count is passed on to dir_$do_op_read_linku's `out'
  link_type_ret); parent_uid_ret written on the paths before its one
  read but not provably: `var'; cont read then written: `in out', a
  dir_$path_index_t (its word index form); size written before every
  read: `out' pinteger; last_start, last_size written only: `out'; max
  the link-text buffer's pointer by value (dir_$do_op_read_linku's
  buffer), dir_$text_ptr_t. }
{ body: dir/do_op_resolve.pas }
procedure dir_$do_op_resolve(in path_data: univ name_$long_pname_t;
                             path_len: pinteger;
                             in out result: dir_$uid_view_t;
                             out extra_ret: integer32;
                             var parent_uid_ret: uid_$t;
                             out flags1: boolean; out flags2: boolean;
                             in out cont: dir_$path_index_t;
                             out size: pinteger;
                             out last_start: dir_$path_index_t;
                             out last_size: pinteger;
                             max: dir_$text_ptr_t;
                             out link_count: integer;
                             out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_get_entryu, forward; confirmed against the body and its
  two nested routines: uid only read, passed on and its second word
  read for the hash: `in', the view record (DIR_$DO_OP passes its
  local_uid); name read and passed on: `in'; name_len a word by value,
  compared signed, its address passed on to REM_NAME_$GET_ENTRY;
  type_ret, uid_ret and extra_ret written by the nested routines on
  some paths only and read after them: `var'; status_ret written first
  on every path (dir_$open_dir's `out', AST_$GET_DTV's `out'): `out'. }
{ body: dir/do_op_get_entryu.pas }
procedure dir_$do_op_get_entryu(in uid: dir_$uid_view_t;
                                in name: univ name_$long_name_t;
                                name_len: integer; var type_ret: integer;
                                var uid_ret: dir_$uid_view_t;
                                var extra_ret: integer32;
                                out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_read_linku, forward; confirmed against the body
  (dir/do_op_read_linku.pas): uid passed on to dir_$open_dir's `in':
  `in'; name passed on to dir_$find_entry's `in': `in'; name_len a word
  passed on, buf_len a word compared signed: integer; buf the text
  buffer's pointer by value (the copy's destination); link_type_ret,
  the text's length, cleared first: `out'; uid_ret written first
  (UID_$NIL): `out'; status_ret written first by dir_$open_dir's `out':
  `out'.  The second caller, dir_$do_op_resolve, passes its link
  count's slot as link_type_ret and its local entry_uid as uid_ret. }
{ body: dir/do_op_read_linku.pas }
procedure dir_$do_op_read_linku(in uid: uid_$t;
                                in name: univ name_$long_name_t;
                                name_len: integer; buf_len: integer;
                                buf: dir_$text_ptr_t;
                                out link_type_ret: integer;
                                out uid_ret: dir_$uid_view_t;
                                out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_dir_readu, forward; confirmed against the body: cont is
  read first, then written: `in out', `univ' the continuation record
  (DIR_$DO_OP passes its reply's longword); size_ret, offset_ret,
  count_ret and status_ret are written first: `out'; buf_ptr the reply
  buffer's word view. }
{ body: dir/do_op_dir_readu.pas }
procedure dir_$do_op_dir_readu(in uid: uid_$t; version: integer;
                               in name: univ name_$long_name_t;
                               name_flags: integer;
                               in out cont: univ dir_$readu_cont_t;
                               max_entries: integer32; max_size: linteger;
                               buf_ptr: dir_$readu_buf_ptr_t;
                               out size_ret: integer32;
                               out offset_ret: integer32;
                               out count_ret: integer32;
                               out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_find_uid, forward: flag a byte by value; len_ret and
  extra_ret cleared first.  Confirmed against the body
  (dir/do_op_find_uid.pas): name_ret is `out', only written. }
{ body: dir/do_op_find_uid.pas }
procedure dir_$do_op_find_uid(in uid: uid_$t; in target_uid: uid_$t;
                              flag: boolean;
                              out name_ret: univ name_$long_name_t;
                              out len_ret: integer;
                              out extra_ret: integer32;
                              out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_add_entry, forward: DIR_$DO_OP's arms 16#2A and 16#3C,
  eleven arguments; volume_ret written at the end.  The target UID and
  the link text receive literals (a 4-byte 0 cell, a zero-length one:
  dir/do_op.pas): `in univ'. }
{ body: dir/do_op_add_entry.pas }
procedure dir_$do_op_add_entry(in uid: uid_$t; rights: integer;
                               in name: univ name_$long_name_t;
                               name_len: integer; entry_type: integer;
                               extra: integer32;
                               in target_uid: univ uid_$t;
                               link_len: integer;
                               in link_data: univ name_$long_pname_t;
                               out volume_ret: integer;
                               out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_validate_root_entry, forward. }
{ body: dir/do_op_validate_root_entry.pas }
procedure dir_$do_op_validate_root_entry(in name: univ name_$long_name_t;
                                         name_len: integer;
                                         out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_add_link, forward: is_hard_link a byte by value (DIR_$DO_OP
  passes false or true). }
{ body: dir/do_op_add_link.pas }
procedure dir_$do_op_add_link(in uid: uid_$t;
                              in name: univ name_$long_name_t;
                              name_len: integer; in file_uid: uid_$t;
                              is_hard_link: boolean;
                              out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_add_bak, forward: result_uid has UID_$NIL stored first. }
{ uid_data is `in': the body only reads it and passes it on to `in'
  formals (ACL_$COPY's and FILE_$SET_PROT's, file/set_prot.pas,
  acl/copy.pas) and AST_$SET_ATTRIBUTE's value parameter. }
{ body: dir/do_op_add_bak.pas }
procedure dir_$do_op_add_bak(in uid: uid_$t; req_version: integer;
                             in name: univ name_$long_name_t;
                             name_len: integer; in uid_data: uid_$t;
                             out result_uid: uid_$t;
                             out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_drop_entry, forward.  result_uid `out': the body only
  passes it on to dir_$remove_entry's `out' uid_ret. }
{ body: dir/do_op_drop_entry.pas }
procedure dir_$do_op_drop_entry(in uid: uid_$t; rights: integer;
                                in name: univ name_$long_name_t;
                                name_len: integer; entry_type: integer;
                                out result_uid: uid_$t;
                                out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_delete, forward: nine arguments, the three booleans as
  bytes; deleted_uid_ret has UID_$NIL stored first.  entry_uid_ret
  `out': the body writes it, or passes it on to dir_$remove_entry's
  `out' uid_ret, and never reads it. }
{ body: dir/do_op_delete.pas }
procedure dir_$do_op_delete(in dir_uid: uid_$t;
                            in name: univ name_$long_name_t;
                            name_len: integer; check_del_right: boolean;
                            entry_only: boolean; allow_link: boolean;
                            out entry_uid_ret: uid_$t;
                            out deleted_uid_ret: uid_$t;
                            out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_cname, forward: req_version is never read. }
{ body: dir/do_op_cname.pas }
procedure dir_$do_op_cname(in uid: uid_$t; req_version: integer;
                           in old_name: univ name_$long_name_t;
                           old_name_len: integer;
                           in new_name: univ name_$long_name_t;
                           new_name_len: integer;
                           out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_get_def_prot, forward.  prot_buf and acl_ret `out': passed
  on only, to dir_$read_def_prot's `out' formals. }
{ body: dir/do_op_get_def_prot.pas }
procedure dir_$do_op_get_def_prot(in uid: uid_$t; in acl_type: uid_$t;
                                  out prot_buf: univ acl_$prot_data_t;
                                  out acl_ret: uid_$t;
                                  out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_set_def_prot, forward. }
{ body: dir/do_op_set_def_prot.pas }
procedure dir_$do_op_set_def_prot(in dir_uid: uid_$t; in acl_type: uid_$t;
                                  in prot_data: univ acl_$prot_data_t;
                                  in src_acl_uid: uid_$t;
                                  out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_set_prot, forward: prot_type a word whose address the body
  takes. }
{ uid is `in': FILE_$SET_PROT's body has it `in' (file/set_prot.pas),
  and the body only passes uid on to `in' formals (dir_$open_dir's
  too). }
{ body: dir/do_op_set_prot.pas }
procedure dir_$do_op_set_prot(in uid: uid_$t;
                              in prot_data: univ acl_$prot_data_t;
                              in acl_uid: uid_$t; prot_type: integer;
                              out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_create_dir, forward; confirmed by the body. }
{ body: dir/do_op_create_dir.pas }
procedure dir_$do_op_create_dir(in uid: uid_$t;
                                in name: univ name_$long_name_t;
                                name_len: integer; var result_uid: uid_$t;
                                out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_drop_dir, forward; confirmed by the body.  name_len is
  pinteger: the routine passes its own slot's address to
  DIR_$OLD_DROP_DIRU's `in name_len: pinteger', and by value to
  dir_$find_entry and dir_$remove_entry. }
{ body: dir/do_op_drop_dir.pas }
procedure dir_$do_op_drop_dir(in uid: uid_$t;
                              in name: univ name_$long_name_t;
                              name_len: pinteger;
                              out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_set_acl, forward; acl_uid `in' and status_ret `out'
  confirmed.  uid is `in': FILE_$SET_PROT's body has the UID `in'
  (file/set_prot.pas), and the body passes uid on only to `in' formals
  (dir_$open_dir's, AUDIT_$LOG_PROT_OP's). }
{ body: dir/do_op_set_acl.pas }
procedure dir_$do_op_set_acl(in uid: uid_$t; in acl_uid: uid_$t;
                             out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_set_default_acl, forward. }
{ body: dir/do_op_set_default_acl.pas }
procedure dir_$do_op_set_default_acl(in dir_uid: uid_$t;
                                     in acl_type: uid_$t;
                                     in src_acl_uid: uid_$t;
                                     out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_get_default_acl, forward; confirmed against the body, with
  acl_ret `out' (only written) and the UID view (its low half's set),
  and the UID named dir_uid (the body's `with handle^' has a field
  uid). }
{ body: dir/do_op_get_default_acl.pas }
procedure dir_$do_op_get_default_acl(in dir_uid: uid_$t;
                                     in acl_type: uid_$t;
                                     out acl_ret: dir_$uid_view_t;
                                     out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_add_mount, forward; confirmed against the body. }
{ body: dir/do_op_add_mount.pas }
procedure dir_$do_op_add_mount(in dir_uid: uid_$t; in mount_uid: uid_$t;
                               node_id: integer32;
                               out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_drop_mount, forward; confirmed against the body:
  status_ret only written, last. }
{ body: dir/do_op_drop_mount.pas }
procedure dir_$do_op_drop_mount(in mount_uid: uid_$t; node_id: integer32;
                                out status_ret: status_$t);
  forward; internal;

{ dir_$do_op_fix_dir, forward. }
{ body: dir/do_op_fix_dir.pas }
procedure dir_$do_op_fix_dir(in uid: uid_$t; out status_ret: status_$t);
  forward; internal;

{ ---- OS_INIT_PROC ---- }
%include 'dir/init.pas';                     { DIR_$INIT }

{ ---- .TEXT ---- }
%include 'audit/log_prot_op.pas';            { audit_$log_prot_op }
%include 'dir/lock_obj.pas';                 { dir_$lock_obj }
%include 'dir/unlock_obj.pas';               { dir_$unlock_obj }
%include 'dir/map_page.pas';                 { dir_$map_page }
%include 'dir/validate_handle.pas';          { dir_$validate_handle }
%include 'dir/unmap_pages.pas';              { dir_$unmap_pages }
%include 'dir/wire_page.pas';                { dir_$wire_page }
%include 'dir/release_wire.pas';             { dir_$release_wire }
%include 'dir/alloc_handle.pas';             { dir_$alloc_handle }
%include 'dir/free_handle.pas';              { dir_$free_handle }
%include 'dir/release_handle.pas';           { dir_$release_handle }
%include 'dir/open_dir.pas';                 { dir_$open_dir }
%include 'dir/is_retryable_status.pas';      { dir_$is_retryable_status }
%include 'dir/update_hint.pas';              { dir_$update_hint }
%include 'audit/log_mount_op.pas';           { audit_$log_mount_op }
%include 'audit/log_link_op.pas';            { audit_$log_link_op }
%include 'audit/log_dir_op.pas';             { audit_$log_dir_op }
%include 'audit/log_cname_op.pas';           { audit_$log_cname_op }
%include 'dir/audit_log_resolve_op.pas';     { audit_$log_resolve_op }
%include 'dir/do_op.pas';                    { DIR_$DO_OP }
%include 'dir/find_entry.pas';               { dir_$find_entry }
%include 'dir/do_op_get_entryu.pas';         { dir_$do_op_get_entryu, with
                                               dir_$lookup_entry and
                                               dir_$get_entry_cached nested in
                                               it (their fragments included
                                               there) }
%include 'dir/get_parent_uid.pas';           { dir_$get_parent_uid }
%include 'dir/do_op_resolve.pas';            { dir_$do_op_resolve }
%include 'dir/resolve.pas';                  { DIR_$RESOLVE }
%include 'dir/get_entryu.pas';               { DIR_$GET_ENTRYU, with its
                                               nested routine }
%include 'dir/map_link_page.pas';            { dir_$map_link_page }
%include 'dir/do_op_read_linku.pas';         { dir_$do_op_read_linku }
%include 'dir/read_linku.pas';               { DIR_$READ_LINKU }
%include 'dir/next_page.pas';                { dir_$next_page }
%include 'dir/do_op_dir_readu.pas';          { dir_$do_op_dir_readu, with
                                               dir_$refind_entry nested in it
                                               (its fragment included there) }
{ dir_$read_canned_root (dir/read_canned_root.pas) is nested in
  dir_$dir_readu_fallback (dir/dir_readu_fallback.pas, its fragment
  included there), and the fallback and dir_$dir_readu_via_do_op
  (dir/dir_readu_via_do_op.pas) in DIR_$DIR_READU: their fragments are
  included in dir/dir_readu.pas's declaration part. }
%include 'dir/dir_readu.pas';                { DIR_$DIR_READU }
%include 'dir/do_op_find_uid.pas';           { dir_$do_op_find_uid }
%include 'dir/find_uid_internal.pas';        { dir_$find_uid_internal }
%include 'dir/find_uid.pas';                 { DIR_$FIND_UID }
%include 'dir/find_net.pas';                 { DIR_$FIND_NET }
%include 'dir/truncate_pages.pas';           { dir_$truncate_pages }
{ dir_$add_entry has a family of nested routines in front of it:
  dir_$alloc_overflow_page (dir/alloc_overflow_page.pas) and
  dir_$insert_entry (dir/insert_entry.pas, nested in add_entry); in
  insert_entry, dir_$purify_split_pages, dir_$alloc_split_page,
  dir_$finalize_split, dir_$calc_entry_size, dir_$move_entries_to_page,
  dir_$write_entry_to_page and dir_$compact_page_entries
  (dir/purify_split_pages.pas, alloc_split_page.pas, finalize_split.pas,
  calc_entry_size.pas, move_entries_to_page.pas, write_entry_to_page.pas,
  compact_page_entries.pas); and in write_entry_to_page,
  dir_$copy_name_cross_page (dir/copy_name_cross_page.pas, which
  dir/write_entry_to_page.pas includes).  dir/add_entry.pas includes
  alloc_overflow_page.pas and insert_entry.pas in its declaration part,
  dir/insert_entry.pas the other seven in its own, in image order. }
%include 'dir/add_entry.pas';                { dir_$add_entry }
%include 'dir/do_op_add_entry.pas';          { dir_$do_op_add_entry }
%include 'dir/add_entry_internal.pas';       { dir_$add_entry_internal }
%include 'dir/addu.pas';                     { DIR_$ADDU }
%include 'dir/do_op_validate_root_entry.pas';
                                             { dir_$do_op_validate_root_entry }
%include 'dir/validate_root_entry.pas';      { DIR_$VALIDATE_ROOT_ENTRY }
%include 'dir/do_op_add_link.pas';           { dir_$do_op_add_link }
%include 'dir/add_hard_linku.pas';           { DIR_$ADD_HARD_LINKU }
%include 'dir/add_linku.pas';                { DIR_$ADD_LINKU }
{ dir_$add_bak_default_prot is nested in dir_$do_op_add_bak:
  dir/do_op_add_bak.pas includes dir/add_bak_default_prot.pas. }
%include 'dir/do_op_add_bak.pas';            { dir_$do_op_add_bak }
%include 'dir/add_baku.pas';                 { DIR_$ADD_BAKU }
%include 'dir/remove_entry.pas';             { dir_$remove_entry_from_page,
                                               dir_$remove_entry }
%include 'dir/do_op_drop_entry.pas';         { dir_$do_op_drop_entry }
%include 'dir/do_op_delete.pas';             { dir_$do_op_delete }
%include 'dir/delete_fileu.pas';             { DIR_$DELETE_FILEU }
%include 'dir/dropu.pas';                    { DIR_$DROPU }
%include 'dir/drop_hard_linku.pas';          { DIR_$DROP_HARD_LINKU }
%include 'dir/drop_linku.pas';               { DIR_$DROP_LINKU }
%include 'dir/do_op_cname.pas';              { dir_$do_op_cname }
%include 'dir/cnameu.pas';                   { DIR_$CNAMEU }
%include 'dir/read_def_prot.pas';            { dir_$read_def_prot }
%include 'dir/do_op_get_def_prot.pas';       { dir_$do_op_get_def_prot }
%include 'dir/get_def_protection.pas';       { DIR_$GET_DEF_PROTECTION }
%include 'dir/write_def_prot.pas';           { dir_$write_def_prot }
%include 'dir/do_op_set_def_prot.pas';       { dir_$do_op_set_def_prot }
%include 'dir/set_def_protection.pas';       { DIR_$SET_DEF_PROTECTION }
%include 'dir/do_op_set_prot.pas';           { dir_$do_op_set_prot }
%include 'dir/set_protection.pas';           { DIR_$SET_PROTECTION }
%include 'dir/create_dir_obj.pas';           { dir_$create_dir_obj }
%include 'dir/do_op_create_dir.pas';         { dir_$do_op_create_dir }
%include 'dir/do_op_drop_dir.pas';           { dir_$do_op_drop_dir }
%include 'dir/create_diru.pas';              { DIR_$CREATE_DIRU }
%include 'dir/drop_diru.pas';                { DIR_$DROP_DIRU }
%include 'dir/set_dad.pas';                  { DIR_$SET_DAD }
%include 'dir/root_addu.pas';                { DIR_$ROOT_ADDU }
%include 'dir/do_op_set_acl.pas';            { dir_$do_op_set_acl }
%include 'dir/set_acl.pas';                  { DIR_$SET_ACL }
%include 'dir/set_default_acl_internal.pas';
                                             { dir_$set_default_acl_internal }
%include 'dir/do_op_set_default_acl.pas';    { dir_$do_op_set_default_acl }
%include 'dir/set_default_acl.pas';          { DIR_$SET_DEFAULT_ACL }
%include 'dir/do_op_get_default_acl.pas';    { dir_$do_op_get_default_acl }
%include 'dir/get_default_acl.pas';          { DIR_$GET_DEFAULT_ACL }
%include 'dir/do_op_add_mount.pas';          { dir_$do_op_add_mount }
%include 'dir/do_op_drop_mount.pas';         { dir_$do_op_drop_mount }
%include 'dir/add_mount.pas';                { DIR_$ADD_MOUNT }
%include 'dir/drop_mount.pas';               { DIR_$DROP_MOUNT }
%include 'dir/cleanup.pas';                  { DIR_$CLEANUP }
%include 'dir/validate_pages.pas';           { dir_$validate_pages }
%include 'dir/do_op_fix_dir.pas';            { dir_$do_op_fix_dir }
%include 'dir/fix_dir.pas';                  { DIR_$FIX_DIR }
