{ hint/hint.pas - the HINT_ module, the hint file and the local hint
  cache.

  Image addresses:
    sau2  0x00E7DB50  HINT_ data (.DATA, 0x28 bytes)

  One compilation unit: the map's HINT_ code segments in OS_INIT_PROC
  (0x278 bytes, HINT_$INIT, HINT_$INIT_CACHE) and .TEXT (0x540 bytes,
  HINT_$SHUTDN .. HINT_$ADD_CACHE), and its data segment in .DATA (0x28
  bytes).  HINT_$EXCLUSION_LOCK is hint/hint_wired.pas's;
  HINT_$HINTFILE_PTR is a cell of the hand-written NET_ASM segment.

  The heading: `module hint_;'; the OS_INIT_PROC routines are headed
  `[section(os_init_proc, os_init_data)]'.

  The data, 0x28 bytes (zero but the word at +0x26, 1):

    +0x00  hint_$cache             0x18  two cache entries from 1
    +0x18  HINT_$HINTFILE_UID      8     defined; the file's UID
    +0x20  hint_$data_hintfile_ptr 4     the file as HINT_$INIT maps it
    +0x24  hint_$cache_index       2     the cache's round-robin index
    +0x26  hint_$bucket_index      2     the buckets' round-robin index

  The routines live in one fragment file each (hint/<name>.pas),
  included below in image order.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/hint/hint.pas.  Check: tools/pascal_check.sh.
}
module hint_;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'uid/uid.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'mst/mst.ins.pas';
%include 'name/name.ins.pas';
%include 'node/node.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'route/route.ins.pas';
%include 'hint/hint.ins.pas';

{ The module's own variables and the global it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above), the routines in
  map order. }
var
  hint_$cache: array[1..2] of hint_$cache_entry_t;  { +0x00, zero }

define
  hint_$hintfile_uid;                              { +0x18, zero }

var
  hint_$data_hintfile_ptr: hint_$file_ptr_t;       { +0x20, zero }
  hint_$cache_index: integer;                      { +0x24, zero }
  hint_$bucket_index: integer := 1;                { +0x26: 1 }

define
  hint_$init;
  hint_$init_cache;
  hint_$shutdn;
  hint_$get_hints;
  hint_$addi;
  hint_$add;
  hint_$addu;
  hint_$add_net;
  hint_$get_net;
  hint_$lookup_cache;
  hint_$add_cache;

{ ---- OS_INIT_PROC ---- }
%include 'hint/clear_hintfile.pas';     { HINT_$clear_hintfile }
%include 'hint/init.pas';               { HINT_$INIT }
%include 'hint/init_cache.pas';         { HINT_$INIT_CACHE }

{ ---- .TEXT ---- }
%include 'hint/shutdn.pas';             { HINT_$SHUTDN }
%include 'hint/get_hints.pas';          { HINT_$GET_HINTS }
%include 'hint/add_internal.pas';       { HINT_$add_internal }
%include 'hint/addi.pas';               { HINT_$ADDI }
%include 'hint/add.pas';                { HINT_$ADD }
%include 'hint/addu.pas';               { HINT_$ADDU }
%include 'hint/add_net.pas';            { HINT_$ADD_NET }
%include 'hint/get_net.pas';            { HINT_$GET_NET }
%include 'hint/lookup_cache.pas';       { HINT_$LOOKUP_CACHE }
%include 'hint/add_cache.pas';          { HINT_$ADD_CACHE }
