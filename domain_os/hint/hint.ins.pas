{ hint/hint.ins.pas - HINT_ (the hint file and the local hint cache), for
  the Domain Pascal tree.

  The hint file's layout, the cache entry, the hint pair and its list,
  the three variables of other segments and the map-global routines'
  headings, in map order.  The modules are hint/hint.pas and
  hint/hint_wired.pas.  Include base/base.ins.pas, ml/ml.ins.pas and
  uid/uid.ins.pas before it.
}

type
  { A hint, one (flags, node) pair, 8 bytes.  HINT_$ADD builds one in its
    frame; the module-local hint_$add_internal compares node_id, copies
    the pair whole, and compares flags with the port's network.  node_id
    is linteger: hint_$add_internal stores it unmasked into the reverse
    UID's 20-bit packed field, which is the form for a type with no
    negative values (dpc masks an
    integer32 value there), as UID_$INIT's and BAT_$MOUNT's NODE_$ME
    (uid/uid.ins.pas, bat/bat.ins.pas) and PKT's node parameters
    (pkt/pkt.ins.pas, the PKT review).  Every other use is a test for 0,
    a compare for equality or a copy, the same code either way. }
  hint_$addr_t = record
    flags: integer32;                     { 0x00 }
    node_id: linteger;                    { 0x04 }
  end;

  { The hints HINT_$GET_HINTS writes: at most three from the slot, one
    for the object's own node and the local node's, so five.
    HINT_$ADDU's list is 0x28 bytes, its whole frame; HINT_$GET_HINTS
    indexes it from 1. }
  hint_$addr_list_t = array[1..5] of hint_$addr_t;

  { A slot of a hint-file bucket, 0x1C bytes: the masked UID key and
    three hints from 1.  hint_$add_internal reaches slot s of its bucket
    through a pointer stepped by 0x1C.  The key is the UID's low longword
    masked to 20 bits, compared unsigned where it is compared for order
    (HINT_$GET_HINTS): linteger. }
  hint_$slot_t = record
    uid_low_masked: linteger;             { 0x00 }
    addrs: array[1..3] of hint_$addr_t;   { 0x04 }
  end;

  { A bucket, three slots from 1, 0x54 bytes. }
  hint_$bucket_t = record
    slots: array[1..3] of hint_$slot_t;   { 0x00 }
  end;

  { The mapped hint file, 0x1560 bytes.  The header: the version, 7 when
    the file is initialized, 1 when it is uninitialized (HINT_$INIT);
    the network the file was written for, a longword HINT_$INIT copies into
    ROUTE_$PORT[0]'s network; and the port's type and socket words,
    compared one by one with those of ROUTE_$PORTP[0]^ (HINT_$INIT,
    HINT_$GET_NET), hence route_$port_t's two types.  The copies move the
    two words as one longword (see the TODO(pascal) in
    hint/clear_hintfile.pas), the compares one by one.  The two words' names
    are route_$port_t's.  The buckets: 65 from 0, one more than the hash
    selects, as HINT_$clear_hintfile clears them. }
  hint_$file_t = record
    version: integer32;                   { 0x00 }
    net_port: integer32;                  { 0x04 }
    port_type: integer;                   { 0x08 }
    socket: pinteger;                     { 0x0A }
    buckets: array[0..64] of hint_$bucket_t;  { 0x0C }
  end;
  hint_$file_ptr_t = ^hint_$file_t;

  { An entry of the local cache, 0x0C bytes: when it was made
    (TIME_$CLOCKH, HINT_$ADD_CACHE), the answer, a byte its callers read
    as a boolean (FILE_$PRIV_LOCK), and the key at +0x08.  The bytes at
    +0x05..+0x07 are a pad. }
  hint_$cache_entry_t = record
    timestamp: time_$clockh_t;            { 0x00 }
    result: boolean;                      { 0x04 }
    unused_05: char;                      { 0x05 }
    unused_06: integer;                   { 0x06 }
    uid_low_masked: linteger;             { 0x08 }
  end;

  { A UID whose low longword is also seen as uid/uid.ins.pas's packed
    uid_$gen_low_t.  hint_$add_internal builds the UID of the node it
    passes to itself in its frame by storing the node into the low
    longword's low 20 bits only, the form of a store into a packed field
    crossing a word (UID_$INIT, uid/uid.ins.pas), and passes the whole
    UID.  high and low are uid_$t's. }
  hint_$uid_t = record
    case integer of
      1: (uid: uid_$t);                   { 0x00..0x07 }
      2: (high: integer32;                { 0x00 }
          low: uid_$gen_low_t);           { 0x04 }
  end;

var
  { HINT_$EXCLUSION_LOCK (the map's HINT_WIRED data segment, its only
    symbol; hint/hint_wired.pas defines it): the lock every .TEXT routine
    but HINT_$SHUTDN, _$GET_HINTS, _$GET_NET and the module-local
    hint_$add_internal (whose callers hold it) takes, another unit's
    variable by address; HINT_$INIT_CACHE initializes it. }
  hint_$exclusion_lock: extern ml_$exclusion_t;

  { HINT_$HINTFILE_PTR (map symbol, the first of the hand-written NET_ASM
    data segment, with REM_FILE_$2LONG1 and NETWORK_$2LONG1;
    node/node.ins.pas's NODE_$ME is in the same run): the hint file as
    the routines outside HINT_$INIT use it.  HINT_$INIT clears it and
    publishes the mapped file in it; the .TEXT routines test it and reach
    the file through it. }
  hint_$hintfile_ptr: extern hint_$file_ptr_t;

  { HINT_$HINTFILE_UID (map symbol, +0x18 of HINT_'s data segment;
    hint/hint.pas defines it): the hint file's UID.  HINT_$INIT sets it
    to UID_$NIL and then to the resolved UID; HINT_$clear_hintfile and
    HINT_$SHUTDN pass it by address. }
  hint_$hintfile_uid: extern uid_$t;

{ Routine headings, in map order. }

{ HINT_$INIT - open, map and lock the hint file. }
procedure hint_$init; extern;

{ HINT_$INIT_CACHE - initialize the hint lock and the local cache. }
procedure hint_$init_cache; extern;

{ HINT_$SHUTDN - unmap and unlock the hint file. }
procedure hint_$shutdn; extern;

{ HINT_$GET_HINTS - list the hints for an object. }
function hint_$get_hints(in uid: uid_$t;
                         out addresses: hint_$addr_list_t): integer;
  extern;

{ HINT_$ADDI - record a hint pair under the hint lock. }
procedure hint_$addi(in uid: uid_$t; in addresses: hint_$addr_t);
  extern;

{ HINT_$ADD - record a hint for a node under the hint lock. }
procedure hint_$add(in uid: uid_$t; in node_id: linteger); extern;

{ HINT_$ADDU - record one object's hints for another under the hint
  lock. }
procedure hint_$addu(in target_uid: uid_$t; in source_uid: uid_$t);
  extern;

{ HINT_$ADD_NET - record the network port in the hint file's header. }
procedure hint_$add_net(port: integer32); options(extern, val_param);

{ HINT_$GET_NET - the network port the hint file records. }
procedure hint_$get_net(out port_ret: integer32); extern;

{ HINT_$LOOKUP_CACHE - look a key up in the local hint cache. }
procedure hint_$lookup_cache(in uid_low_masked: linteger;
                             out result: boolean);
  extern;

{ HINT_$ADD_CACHE - put a key's answer into the local hint cache. }
procedure hint_$add_cache(in uid_low_masked: linteger; in result: boolean);
  extern;
