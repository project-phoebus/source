{ uid/uid.ins.pas - UID_ (unique identifiers) types and routine headings,
  for the Domain Pascal tree.

  What the Pascal files use: the UID generator's state as the UID_
  module reads it and the headings of UID_$GEN, UID_$INIT and the
  hand-written UID_$HASH.  uid_$t and UID_$NIL are base/base.ins.pas's
  (Apollo's base.ins.pas declares them).  The module is uid/uid.pas.
  Include base/base.ins.pas before it.
}

type
  { A byte read as an unsigned 8-bit integer (ref 3.15.5), the form of
    suma/suma.ins.pas's suma_$byte_t. }
  uid_$byte_t = [byte] 0..255;

  { The low longword of the generator's UID, a packed record of 32 bits
    (ref 3.10.7; fields from the most significant bit).  UID_$GEN reads
    its top four bits, the counter nibble, through the first byte, once
    into a longword (for a compare with one) and once into a word
    (tested against 0): "Wider field, value", the unit the byte, the
    mask in the value's width.  UID_$INIT stores the node ID into its
    low 20 bits in place, "Wider field, value" with a longword unit (the
    field crosses the word).  The bits between are never addressed.  The
    counter UID_$GEN compares, then bumps, is the top nibble, so the
    names are counter, bits_27_20 and node. }
  uid_$gen_low_t = packed record
    counter: 0..15;                       { bits 31..28 }
    bits_27_20: 0..255;                   { bits 27..20 }
    node: 0..16#FFFFF;                    { bits 19..0 }
  end;

  { The generator's state, 8 bytes, three ways.  UID_$GEN copies it
    whole into its UID local: a uid_$t (the first variant).  It
    compares the high longword unsigned (linteger, the customer
    base.ins.pas's time_$clockh_t for a clock's high half), stores it,
    adds 1 to it; it reads the low longword's fields (above), then
    adds 16 to its first byte in place, an integer byte (the third
    variant): a packed field's update would mask and merge. }
  uid_$gen_state_t = record
    case integer of
      1: (uid: uid_$t);                   { 0x00..0x07 }
      2: (high: time_$clockh_t;           { 0x00 }
          low: uid_$gen_low_t);           { 0x04 }
      3: (high_3: time_$clockh_t;         { 0x00 }
          counter_byte: uid_$byte_t);     { 0x04 }
  end;

var
  { LV_LABEL_$UID (map symbol, in the map's UID_LIST segment, the table
    of well-known UIDs): the logical-volume label's UID.  BAT_$MOUNT and
    BAT_$DISMOUNT pass its address to DBUF_$GET_BLOCK: another unit's
    variable by address.  (Added for BAT.) }
  lv_label_$uid: extern uid_$t;

  { PV_LABEL_$UID (map symbol, in UID_LIST, before LV_LABEL_$UID): the
    physical-volume label's UID.  DISK_'s third unit passes its address
    to DISK_$GET_BLOCK, from four sites.  (Added for DISK_'s third
    unit.) }
  pv_label_$uid: extern uid_$t;

  { NIL_$NETWORK_UID, USER_$NETWORK_UID and UNKNOWN_$NETWORK_UID (map
    symbols in UID_LIST): the network types' UIDs.  NET_IO_$BOOT_DEVICE
    copies the first two into the NIL and USER driver records,
    NET_IO_$DEVICE_STAT the third into its caller's UID. }
  nil_$network_uid: extern uid_$t;
  user_$network_uid: extern uid_$t;
  unknown_$network_uid: extern uid_$t;

{ Routine headings, in map order: UID_$HASH (the map's UID_$HASH
  segment, 0x1C bytes, hand-written, WIRED_PROC), UID_$GEN (a UID_ code
  segment of 0xE4 bytes, WIRED_PROC), UID_$INIT (a UID_ code segment of
  0x20 bytes, OS_INIT_PROC).  The bodies of the last two repeat the full
  heading (ref 7.3.4, Method 2). }

{ UID_$HASH (hand-written, no Pascal body: uid/README.md).  No
  frame: it reads its two arguments off the stack, folds the UID's two
  longwords and its halves into a word, divides that by the word the
  second argument addresses, and swaps D0 so that the remainder is its
  low word.  Its 16 compiled callers push two addresses (the table size
  in a constant cell or the field of a record), then read D0's word, one
  of them sign-extending it (integer).  So the default convention, both `in'
  (never written), an integer function (the callers keep the word). }
function uid_$hash(in uid: uid_$t; in table_size: integer): integer;
  extern;

{ UID_$GEN - generate a new unique identifier. }
procedure uid_$gen(out uid_ret: uid_$t); extern;

{ UID_$INIT - put this node's ID into the UID generator. }
procedure uid_$init; extern;

{ }

var
  { UNSTRUCT_$UID (map symbol, in UID_LIST; the unstructured file
    type's UID): audit_$open_log passes its address to FILE_$SET_TYPE:
    another unit's variable by address. }
  unstruct_$uid: extern uid_$t;

{ }

var
  { PPO_$NIL_USER_UID and PPO_$NIL_ORG_UID (map symbols, with
    RGYC_$P_NIL_UID and RGYC_$O_NIL_UID at the same addresses, in
    UID_LIST; the UIDs 16#00800000.00000000, 16#00800080.00000000):
    VTOCE_$OLD_TO_NEW copies them into a new VTOCE (the first at +0x48)
    by their absolute addresses: another unit's records. }
  ppo_$nil_user_uid: extern uid_$t;
  ppo_$nil_org_uid: extern uid_$t;

{ }
var
  { OS_WIRED_$UID (map symbol, in UID_LIST): the UID the kernel's canned
    maps name.  OS_$INIT passes its address to MST_$MAP_CANNED_AT (a
    RELOC cell). }
  os_wired_$uid: extern uid_$t;

  { SPECIAL_SEG_$UID (map symbol, in UID_LIST): the UID of the special
    segments' entries; the SAU9's MST_$TOUCH refuses a fault on one. }
  special_seg_$uid: extern uid_$t;

var
  { DISKLESS_$UID (map symbol, in UID_LIST; the UID
    16#00000403.00000000): FILE_$LOCATEI compares a UID's second byte
    with this one's. }
  diskless_$uid: extern uid_$t;

{ }
var
  { SLINK_$UID (map symbol, in UID_LIST; the UID 16#0000031E.00000000),
    the symbolic link's type UID: REM_FILE_$SERVER's
    server_set_attribute compares an attribute-4 value with it, one
    longword at a time. }
  slink_$uid: extern uid_$t;
