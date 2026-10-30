{ bat/bat.ins.pas - BAT_ (the block allocation table), for the Domain
  Pascal tree.

  Holds only what the Pascal files use: the statuses, the volume record
  of the module's block and the logical-volume label it is copied from,
  the bitmap and VTOCE block views, BAT_DATA and BAT_$UID, and the
  headings of the eleven BAT_$ routines.  The module is bat/bat.pas.

  Apollo's customer insert files of SR10.2 declare none of it; the
  layouts are the image's.  Include base/base.ins.pas before it, and
  fm/fm.ins.pas and vtoc/vtoc.ins.pas (the label's VTOC record, below;
  every includer had them first already).
}

const
  { 16#00010004, "BAT not mounted" (stcode.db.10.2, OS / BAT manager);
    the name is made from the text.  VOLX_$GET_INFO maps BAT_$N_FREE's
    status from it. }
  status_$bat_not_mounted = 16#00010004;

  { 16#80010003, "attempt to free illegal disk address", and 16#80010001,
    "attempt to free already-freed block" (stcode.db.10.2, OS / BAT
    manager, with the fail bit).  BAT_$FREE stores both, BAT_$CANCEL the
    second.  Written negative: 16#8001xxxx is not an integer32
    (log/log.ins.pas's log_$pending_magic). }
  bat_$invalid_block = -16#7FFEFFFD;
  bat_$error = -16#7FFEFFFF;

  { DBUF_$SET_BUFF's flags words the routines pass: release (8), release
    and dirty (9), release, write back and dirty (16#B)
    (dbuf/dbuf.ins.pas dbuf_flag_*): BAT_$ALLOCATE, BAT_$FREE, BAT_$MOUNT,
    BAT_$DISMOUNT. }
  bat_buf_clean = 8;
  bat_buf_dirty = 9;
  bat_buf_writeback = 16#B;

  { A VTOCE block's check word (16#FEDCA984) and its number of entries,
    as BAT_$ALLOC_VTOCE stores and tests them.  Written negative, as
    above. }
  vtoce_magic = -16#0123567C;
  vtoce_entries_per_block = 3;

type
  { A byte read as an unsigned 8-bit integer (ref 3.15.5), the form of
    disk/disk.ins.pas's disk_$byte_t. }
  bat_$byte_t = [byte] 0..255;

  { The volume trouble word, three ways (AEGIS Internals fig. 4-5
    "Volume Trouble").  BAT_$MOUNT reads it as an integer (`value < 0'),
    as a word set (`12 in members', the whole-value form), and stores a
    boolean into its bit 12 as a packed field (bit k < 7 of the byte
    unit). }
  bat_$trouble_bits_t = packed record
    bits_15_13: 0..7;                     { bits 15..13 }
    bit_12: boolean;                      { bit 12 }
    bits_11_0: 0..4095;                   { bits 11..0 }
  end;
  bat_$trouble_t = record
    case integer of
      1: (value: integer);                { 0x00 }
      2: (members: set of 0..15);         { 0x00 }
      3: (bits: bat_$trouble_bits_t);     { 0x00 }
  end;

  { The BAT header, 0x20 bytes: the label's +0x2C..+0x4B, the first part
    of a volume record (AEGIS Internals fig. 4-5).  BAT_$MOUNT and
    BAT_$DISMOUNT copy it whole, eight longwords: a record assignment
    (20 bytes and more).  The block numbers and counts are compared
    unsigned (BAT_$ALLOCATE, BAT_$CANCEL): linteger.  The pair at +0x12
    is read as one longword by BAT_$ALLOCATE and on the label by
    BAT_$MOUNT, and its second word alone by BAT_$GET_BAT_STEP: the
    variant step_long. }
  bat_$hdr_t = record
    total_blocks: linteger;               { 0x00 }
    free_blocks: linteger;                { 0x04 }
    bat_block_start: linteger;            { 0x08 }
    first_data_block: linteger;           { 0x0C }
    volume_trouble: bat_$trouble_t;       { 0x10 }
    case integer of
      1: (step_blocks: pinteger;          { 0x12 }
          bat_step: pinteger;             { 0x14 }
          reserved_16: pinteger;          { 0x16 }
          reserved_blocks: linteger;      { 0x18 }
          unknown_1c: integer32);         { 0x1C }
      2: (step_long: integer32);          { 0x12 }
  end;

  { A partition's record, 8 bytes (every index scaled by 8).  The
    longword at +4 is the chain: BAT_$ADD_PART_VTOCE and BAT_$ALLOC_VTOCE
    mask and merge it as an integer; its first byte is the partition's
    state, read as a byte (BAT_$ALLOC_FM, BAT_$ALLOC_VTOCE; the byte form
    of disk/disk.ins.pas disk_$io_req_t.owner).  The byte is named
    `state', since inside `with partitions[i]' a field `status' would
    hide the routines' status parameters (BAT_$ALLOC_VTOCE passes its
    own on inside such a `with', bat/alloc_vtoce.pas). }
  bat_$partition_t = record
    free_count: linteger;                 { 0x00 }
    case integer of
      1: (chain: integer32);              { 0x04 }
      2: (state: bat_$byte_t);            { 0x04 }
  end;

  { The partition table, 0x20C bytes: the label's +0xFC..+0x307, the
    second part of a volume record.  BAT_$MOUNT and BAT_$DISMOUNT copy
    it whole, 0x83 longwords.  num_partitions is zero-extended for its
    compares and halved with a logical shift: pinteger;
    partition_start_offset zero-extended: pinteger; partition_size
    quartered with a logical shift: linteger. }
  bat_$ptab_t = record
    num_partitions: pinteger;             { 0x000 }
    partition_start_offset: pinteger;     { 0x002 }
    partition_size: linteger;             { 0x004 }
    unknown_28: integer32;                { 0x008 }
    partitions: array[0..63] of bat_$partition_t;   { 0x00C }
  end;

  { A volume's record, 0x234 bytes (every routine scales the volume
    index by 0x234).  The header and the table are records of their own:
    the copies above are record assignments, and BAT_$ALLOCATE and
    BAT_$FREE reach the two through two with-temporaries of their own
    besides the element's (bat/allocate.pas).  The chunk fields are
    BAT_$MOUNT's, computed from the drive's geometry. }
  bat_$volume_t = record
    hdr: bat_$hdr_t;                      { 0x000 }
    ptab: bat_$ptab_t;                    { 0x020 }
    alloc_chunk_size: linteger;           { 0x22C }
    alloc_chunk_offset: linteger;         { 0x230 }
  end;

  { The low longword of the label's +0xB4, "Unused | Last Mounted Node"
    (AEGIS Internals fig. 4-4): a packed record of 32 bits, the node ID
    in the low 20.  BAT_$MOUNT stores NODE_$ME into it as
    uid/uid.ins.pas's uid_$gen_low_t.node, masked and merged. }
  bat_$node_word_t = packed record
    bits_31_20: 0..4095;                  { bits 31..20 }
    node: 0..16#FFFFF;                    { bits 19..0 }
  end;

  { The logical-volume label, block 0 of a logical volume (AEGIS
    Internals fig. 4-4).  The fields the BAT routines address, by
    BAT_$MOUNT and BAT_$DISMOUNT, with the BAT header and the partition
    table as the volume record's types (bat_hdr, bat_ptab).  0x308
    bytes (the rest of the block is not addressed).  vtoc_header is
    VTOC_'s volume record, vtoc/vtoc.ins.pas's vtoc_$vol_t: VTOC_$MOUNT
    copies it whole into the volume's record and VTOC_$DISMOUNT back,
    25 longwords, a record assignment between objects of one type.  No
    other user names the field. }
  bat_$label_t = record
    version: integer;                     { 0x000 }
    unused_02: pinteger;                  { 0x002 }
    lv_name: array[1..32] of char;        { 0x004 }
    lv_uid: uid_$t;                       { 0x024 }
    bat_hdr: bat_$hdr_t;                  { 0x02C }
    vtoc_header: vtoc_$vol_t;             { 0x04C }
    mount_time_high: time_$clockh_t;      { 0x0B0 }
    mount_time_low: bat_$node_word_t;     { 0x0B4 }
    boot_time: time_$clockh_t;            { 0x0B8 }
    dismount_time: time_$clockh_t;        { 0x0BC }
    current_time: time_$clockh_t;         { 0x0C0 }
    reserved_c4: array[1..10] of char;    { 0x0C4 }
    salvage_flag: integer;                { 0x0CE }
    reserved_d0: array[1..16] of char;    { 0x0D0 }
    { 0x0E0..0x0E9: the boot volume's timezone record and last valid
      time, which CAL_$READ_TIMEZONE reads and CAL_$WRITE_TIMEZONE and
      CAL_$SHUTDOWN write (the names after CAL's label view). }
    utc_delta: integer;                   { 0x0E0 }
    tz_name: array[1..4] of char;         { 0x0E2 }
    last_valid_time: time_$clockh_t;      { 0x0E6 }
    reserved_ea: array[1..18] of char;    { 0x0EA }
    bat_ptab: bat_$ptab_t;                { 0x0FC..0x307 }
  end;
  bat_$label_ptr_t = ^bat_$label_t;

  { A BAT bitmap block, 1024 bytes: 256 longwords of 32 blocks each, a
    set bit a free block.  BAT_$ALLOCATE tests and clears a member,
    BAT_$FREE sets one: sets of 0..31. }
  bat_$bitmap_word_t = set of 0..31;
  bat_$bitmap_t = array[0..255] of bat_$bitmap_word_t;
  bat_$bitmap_ptr_t = ^bat_$bitmap_t;

  { A VTOCE block as BAT_$ALLOC_VTOCE writes it: the chain word, the
    entry count, the check word and the block's own number. }
  bat_$vtoce_block_t = record
    next_vtoce: integer32;                { 0x000 }
    entry_count: integer;                 { 0x004 }
    reserved: array[1..1010] of char;     { 0x006 }
    magic: integer32;                     { 0x3F8 }
    self_block: integer32;                { 0x3FC }
  end;
  bat_$vtoce_block_ptr_t = ^bat_$vtoce_block_t;

  { A longword reached through an address held as an integer
    (BAT_$ALLOCATE's out_ptr, BAT_$FREE's cursor, BAT_$ALLOC_VTOCE's
    ptr). }
  bat_$long_ptr_t = ^linteger;

var
  { BAT_DATA (map symbol without `$', the first of BAT_'s data segment,
    .DATA: a global): the six volume records, from volume 1.  Every
    routine reaches volume v's at the block plus v * 0x234, the lower
    bound folded into the displacements: an array from 1.  Six: the
    module's other variables start at +0xD38 = 6 * 0x234. }
  bat_data: extern array[1..6] of bat_$volume_t;

  { BAT_$UID (map symbol, in UID_LIST, the table of well-known UIDs):
    the bitmap blocks' UID, passed by address to DBUF_$GET_BLOCK
    (BAT_$ALLOCATE, BAT_$FREE): another unit's variable by address. }
  bat_$uid: extern uid_$t;

{ Routine headings, in map order (BAT_'s .TEXT segment): BAT_$ALLOC_FM ..
  BAT_$GET_BAT_STEP.  Every routine is compiled and global
  (bat/README.md).  The bodies repeat the full heading. }

{ BAT_$ALLOC_FM - allocate one block in the partition with the most room. }
function bat_$alloc_fm(vol_idx: integer; out status: status_$t): linteger;
  options(extern, val_param);

{ BAT_$ADD_PART_VTOCE - make a block the head of its partition's VTOCE
  chain. }
function bat_$add_part_vtoce(vol_idx: integer; block: linteger;
                             out status: status_$t): integer32;
  options(extern, val_param);

{ BAT_$ALLOC_VTOCE - find or make room for a VTOCE and return its block. }
function bat_$alloc_vtoce(vol_idx: integer; hint: linteger;
                          out block_out: linteger; out status: status_$t;
                          out new_vtoce: boolean): univ_ptr;
  options(extern, val_param);

{ BAT_$ALLOCATE - allocate blocks from a volume's BAT bitmap. }
procedure bat_$allocate(vol_idx: integer; hint: linteger;
                        alloc_count: integer; use_reserved: integer;
                        out blocks_out: univ linteger;
                        out status: status_$t);
  options(extern, val_param);

{ BAT_$FREE - return blocks to a volume's pool. }
procedure bat_$free(in blocks: univ linteger; count: integer;
                    vol_idx: integer; reserved: integer;
                    out status: status_$t);
  options(extern, val_param);

{ BAT_$MOUNT - mount a volume's BAT from its logical-volume label. }
procedure bat_$mount(vol_idx: integer; salvage_ok: boolean;
                     out status: status_$t);
  options(extern, val_param);

{ BAT_$DISMOUNT - dismount a volume's BAT, writing its label back. }
procedure bat_$dismount(vol_idx: integer; skip_label: boolean;
                        out status: status_$t);
  options(extern, val_param);

{ BAT_$N_FREE - return a volume's free and total block counts. }
procedure bat_$n_free(in vol_idx: integer; out free_out: integer32;
                      out total_out: integer32; out status: status_$t);
  extern;

{ BAT_$RESERVE - move blocks from a volume's free pool to its reserved
  pool. }
procedure bat_$reserve(vol_idx: integer; count: linteger;
                       out status: status_$t);
  options(extern, val_param);

{ BAT_$CANCEL - move blocks from a volume's reserved pool back to its free
  pool. }
procedure bat_$cancel(vol_idx: integer; count: linteger;
                      out status: status_$t);
  options(extern, val_param);

{ BAT_$GET_BAT_STEP - return a volume's BAT step. }
function bat_$get_bat_step(vol_idx: integer): pinteger;
  options(extern, val_param);
