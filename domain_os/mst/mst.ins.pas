{ mst/mst.ins.pas - MST_ (the segment tables: mapping and wiring), for the
  Domain Pascal tree.

  The entry points, statuses and segment words other units use.  No
  customer insert file declares these kernel entry points.  Include
  base/base.ins.pas before it.
}

{ MST_$MAPS - map an object into a given address space, searching from
  the top. }
function mst_$maps(asid: integer; direction: boolean; var uid: uid_$t;
                   start_va: integer32; length: integer32; area_id: integer;
                   area_size: integer32; access: boolean;
                   var map_info: integer32;
                   var status: status_$t): univ_ptr;
  options(extern, val_param);

{ MST_$UNMAP_PRIVI - unmap a range of segments of an address space. }
procedure mst_$unmap_privi(mode: integer; want_uid: uid_$t;
                           start: integer32; size: integer32;
                           asid: integer; out status: status_$t);
  options(extern, val_param);

{ MST_$WIRE - wire the page of a virtual address, touching it in if it
  is not resident. }
function mst_$wire(vpn: integer32; out status: status_$t): integer32;
  options(extern, val_param);

{ MST_$MAP, MST_$MAP_TOP, MST_$MAP_GLOBAL - map an object anywhere in the
  current address space, from the top, or in global A space. }
function mst_$map(in uid: uid_$t; in start: integer32;
                  in length: integer32; in mode: integer;
                  in extend: integer32; in concur: boolean;
                  out map_info: integer32;
                  out status_ret: status_$t): univ_ptr;
  extern;

{ MST_$MAP, MST_$MAP_TOP, MST_$MAP_GLOBAL - map an object anywhere in the
  current address space, from the top, or in global A space. }
function mst_$map_top(in uid: uid_$t; in start: integer32;
                      in length: integer32; in mode: integer;
                      in extend: integer32; in concur: boolean;
                      out map_info: integer32;
                      out status_ret: status_$t): univ_ptr;
  extern;

function mst_$map_global(in uid: uid_$t; in start: integer32;
                         in length: integer32; in mode: integer;
                         in extend: integer32; in concur: boolean;
                         out map_info: integer32;
                         out status_ret: status_$t): univ_ptr;
  extern;

{ MST_$GROW_AREA - change the virtual size of the VM area an address lies
  in, mapping or unmapping its segments to match. }
procedure mst_$grow_area(in va: integer32; in new_virt_size: linteger;
                         in new_commit_size: linteger;
                         out status: status_$t);
  extern;

{ MST_$UNMAP - unmap a range of the current address space's segments
  mapped to an object. }
procedure mst_$unmap(in uid: uid_$t; in start: integer32;
                     in map_info: integer32; out status_ret: status_$t);
  extern;

{ MST_$MAP_SPECIAL - map an object's special segments into an address
  space (the SAU9's; its caller MONO9_$ASSOC).  Every argument by
  address: the segment and the count words, the UID, the ASID word
  (zero crashes the system) and the status; the address in A0.  The
  segment is a pinteger: the body widens it unsigned for the address
  (mst/map_special.pas). }
function mst_$map_special(in seg: pinteger; in count: integer;
                          in obj_uid: uid_$t; in asid: integer;
                          out status_ret: status_$t): univ_ptr;
  extern;

{ MST_$MAP_AT - map an object at a caller-supplied address in the
  current address space. }
procedure mst_$map_at(in va: integer32; in uid: uid_$t; in start: integer32;
                      in length: integer32; in mode: integer;
                      in extend: integer32; in concur: boolean;
                      out map_info: integer32;
                      out status_ret: status_$t);
  extern;

type
  { The page handles MST_$WIRE_AREA stores: an array of longwords of the
    caller's length, `univ'. }
  mst_$page_list_t = array[1..1] of integer32;

{ MST_$WIRE_AREA - wire every page of an address range and list their
  page numbers. }
procedure mst_$wire_area(in start_va: univ_ptr; in end_va: univ_ptr;
                         out page_list: univ mst_$page_list_t;
                         in max_pages: integer;
                         out page_count: integer);
  extern;

%if large_address_space %then
const
  { The address space's regions, in 32 KB segments: private A from 0,
    global A from 30336 (256 segments), private B from 30592 (128),
    global B from 30720 (2048), the segment numbers' end at 32768.
    Constants here (no MST_WIRED variables in the map; AS_$GET_ADDR
    and MST_$VA_TO_SEGNO compile them as immediates). }
  mst_$global_b_size = 2048;
  mst_$seg_global_b = 30720;
  mst_$seg_private_b = 30592;
  mst_$private_a_size = 30336;
  mst_$seg_global_a = 30336;
  mst_$global_a_size = 256;
%else
var
  { The segment numbers and sizes AS_$GET_ADDR reads, map symbols of
    MST_WIRED's block (WIRED_DATA), words.  AS_$GET_ADDR reads each
    zero-extended into a longword and shifts it by 15: pinteger.  The
    names are the map's. }
  mst_$global_b_size: extern pinteger;
  mst_$seg_global_b: extern pinteger;
  mst_$seg_private_b: extern pinteger;
  mst_$private_a_size: extern pinteger;
  mst_$seg_global_a: extern pinteger;
  mst_$global_a_size: extern pinteger;
%endif

{ }

const
  { status_$mst_guard_fault, 16#0004000A ("guard fault",
    stcode.db.10.2): XPD_$COPY_MEMORY compares an address space's trace
    status with it. }
  status_$mst_guard_fault = 16#0004000A;

{ }
const
  { status_$mst_object_not_found, 16#00040001 ("object not found",
    stcode.db.10.2): acl_$load_acl_image compares MST_$MAPS' status with
    it. }
  status_$mst_object_not_found = 16#00040001;

{ }

const
  { 16#40004 "reference to illegal address" (stcode.db.10.2):
    OS_$INSTALL_DISPLAY_ASTE crashes with it (a constant cell). }
  status_$reference_to_illegal_address = 16#00040004;
  { 4000F "invalid va for install of io page" and 40011 "asid 0 is
    illegal for this mapping" (MST_$INSTALL_IOPPN). }
  status_$mst_invalid_va_for_io_page = 16#0004000F;
  status_$mst_asid_0_illegal = 16#00040011;

{ MST_$VA_TO_SEGNO - the MST word index of a virtual address. }
function mst_$va_to_segno(virtual_addr: integer32; out segno_out: pinteger;
                          default_result: pinteger): pinteger;
  options(extern, val_param);

{ MST_$TOUCH - fault in the page of a virtual address. }
function mst_$touch(virtual_addr: integer32; out status_ret: status_$t;
                    wire_flag: integer): integer32;
  options(extern, val_param);

{ The canned mappings' flags longword, two words: MST_$MAP_CANNED_AT and
  MST_$MAP_CANNED push them to mst_$set_mstes apart, the low word as the
  touch count and the high word as the protection, and the callers build
  it as one constant: protection 16#16 (MMU_$INSTALL's, mmu/mmu.ins.pas),
  one page touched ahead.  A record of the two words, passed `univ' so
  that the callers' integer constants still go (4 bytes, by value under
  val_param).  The names are mst_$set_mstes's for the two parameters they
  become. }
type
  mst_$canned_flags_t = record
    prot: integer;
    touch_count: integer;
  end;

{ MST_$MAP_CANNED_AT - map a canned (boot-time) object at a fixed
  global address. }
procedure mst_$map_canned_at(va: integer32; in uid: uid_$t;
                             offset: integer32; size: integer32;
                             flags: univ mst_$canned_flags_t;
                             wire: boolean;
                             touch: boolean; desc: integer32;
                             out status: status_$t);
  options(extern, val_param);

{ }

{ MST_$PRE_INIT - the segment layout and each ASID's run of MST words.
  MST_$INIT - the MST words and the first pages of MSTEs, at boot. }
procedure mst_$pre_init; extern;
procedure mst_$init; extern;

var
  { MST_$MST_PAGES_LIMIT (map symbol, MST_UNWIRED's .DATA): the MSTE
    pages' count, read as a signed word (OS_$INIT). }
  mst_$mst_pages_limit: extern integer;

{ MST_$ALLOC_ASID - allocate an address space. }
function mst_$alloc_asid(out status: status_$t): integer; extern;

{ MST_$DISKLESS_INIT - the diskless node's "partner not responding"
  message, and whether the node has a color display. }
procedure mst_$diskless_init(color: boolean; mother_node: integer32;
                             my_node: integer32);
  options(extern, val_param);

{ MST_$REMAP_PRIVI - unmap a range and map the object that backed its
  first segment again, privileged or not. }
function mst_$remap_privi(in flags: integer; in va: integer32;
                          in unmap_len: integer32; in offset: integer32;
                          in length: integer32; out map_info: integer32;
                          var status: status_$t): univ_ptr; extern;

{ MST_$REMAP - unmap a range and map the same object again at an offset,
  unprivileged. }
function mst_$remap(in va: integer32; in unmap_len: integer32;
                    in offset: integer32; in length: integer32;
                    out map_info: integer32;
                    var status: status_$t): univ_ptr; extern;

{ ---- MAP_AREA_AT, MAP_INITIAL_AREA, FREE_ASID, FORK, GET_VA_INFO
  (written for PROC2's translation) and GET_PRIVATE_SIZE (for
  ASKNODE's).  Their bodies' translations re-check them. ---- }

{ MST_$MAP_AREA_AT - create a VM area and map it at a given address. }
procedure mst_$map_area_at(in va: integer32; in virt_size: integer32;
                           in commit_size: integer32;
                           in reversed: boolean;
                           out area_uid: uid_$t;
                           out status_ret: status_$t); extern;

{ MST_$MAP_AREA - create a VM area and map it anywhere in the current
  address space, from the top. }
function mst_$map_area(in virt_size: integer32; in commit_size: integer32;
                       in reversed: boolean; out uid_out: uid_$t;
                       out status: status_$t): univ_ptr; extern;

{ MST_$MAP_INITIAL_AREA - map a new process's initial area, an anonymous
  area of its parent's, into the new address space. }
procedure mst_$map_initial_area(code_desc: integer32; asid: integer;
                                var parent_uid: uid_$t;
                                map_param: integer32;
                                area_kind: integer;
                                touch: boolean;
                                out status: status_$t);
  options(extern, val_param);

{ MST_$FREE_ASID - tear down an address space's mappings and free its
  ASID. }
procedure mst_$free_asid(asid: integer; out status: status_$t);
  options(extern, val_param);

{ MST_$FORK - copy the current address space's segment tables into a new
  ASID, copying its anonymous areas. }
procedure mst_$fork(asid: integer; pid: pinteger; flags: integer32;
                    out status: status_$t);
  options(extern, val_param);

{ MST_$GET_VA_INFO (mst/get_va_info.pas).  The default convention, eight slots,
  every one a pointer: a word read through at entry, checked unsigned
  against 57 (integer here, the type its callers' ASIDs have); a longword
  read through: `in'; the UID's two longwords written: `out'; a longword
  written: `out'; the fifth's address passed on to mst_$va_to_pte, which
  stores a word through it (mst/va_to_pte.pas): `out', the entry's
  protection, `univ pinteger', named prot: the body's store is a word, and
  MST_$GET_UID and _$GET_UID_ASID pass a 2-byte local; PROC2_$FORK passes a
  14-byte object of its frame, which `univ' still takes (proc2/fork.pas);
  two bytes written: booleans, `out'; the status's address, written: `out'.
  PROC2_$FORK calls it twice, the second time with `cr_rec - 1' formed in a
  temporary between the pushes: an expression for an `in' formal. }
type
  { PROC2_$FORK's 14-byte object it passes as MST_$GET_VA_INFO's
    protection (above). }
  mst_$va_extra_t = array[1..14] of char;
procedure mst_$get_va_info(in asid: integer;
                           in va: integer32;
                           out uid: uid_$t;
                           out va_info: integer32;
                           out prot: univ pinteger;
                           out active: boolean;
                           out modified: boolean;
                           out status: status_$t); extern;

{ MST_$GET_UID and MST_$GET_UID_ASID (mst/get_uid.pas,
  mst/get_uid_asid.pas; reached only through their SVC table cells).
  The default convention, every slot an address: MST_$GET_UID pushes its
  four slots on to MST_$GET_VA_INFO unread, with PROC1_$AS_ID's address
  for the ASID: the address, then
  the UID, the offset and the status, the modes of GET_VA_INFO's formals
  they reach.  MST_$GET_UID_ASID copies its first slot's word into its
  frame at entry, and passes the copy's address: `in', copied by the
  body's first statement into a local, not a value parameter: the copy
  is the frame's second object, below the protection word (a value
  parameter's copy would be the first); its other
  four slots are passed on as GET_UID's. }
procedure mst_$get_uid(in va: integer32; out uid: uid_$t;
                       out va_info: integer32;
                       out status: status_$t); extern;
procedure mst_$get_uid_asid(in asid: integer; in va: integer32;
                            out uid: uid_$t; out va_info: integer32;
                            out status: status_$t); extern;

{ MST_$GET_PRIVATE_SIZE - the sizes of an address space's mapped private
  segments. }
procedure mst_$get_private_size(in asid: pinteger;
                                out size_ret: integer32;
                                out rw_size_ret: integer32;
                                out status_ret: status_$t); extern;

{ ---- For MST_WIRED. ---- }

const
  { 16#40005, "reference to out-of-bounds address" (stcode.db.10.2; the
    name from the text, as status_$reference_to_illegal_address's above):
    MST_$FIND crashes with it (a constant cell). }
  status_$reference_to_out_of_bounds_address = 16#00040005;

{ MST_$FIND - the physical page of a virtual address, touching it in if
  it is not resident. }
function mst_$find(virt_addr: integer32; flags: integer): integer32;
  options(extern, val_param);

{ ---- For MST_UNWIRED's OS_INIT_PROC routines. ---- }

const
  { 16#4000E, "virtual memory resources exhausted" (stcode.db.10.2; the
    name from the text, as status_$reference_to_illegal_address's above):
    MST_$INIT's nested mst_init_page crashes with it when MMAP_$ALLOC_FREE
    finds no page (a constant cell). }
  status_$virtual_memory_resources_exhausted = 16#0004000E;

  { 16#40006, "no asid is available" (stcode.db.10.2): MST_$ALLOC_ASID
    returns it when every ASID is in use. }
  status_$no_asid_available = 16#00040006;

  { 16#40003, "no space available" (stcode.db.10.2): MST_$MAP_CANNED and
    MST_$MAP_CANNED_AT store it when the segments asked for are in use;
    MST_$ALLOC_ASID's asid-base search stores it; OS_$INIT crashes with it
    (os/init.pas).  Its one home (os/os.pas includes this insert before
    os/os.ins.pas). }
  status_$mst_no_space_available = 16#00040003;

  { 16#40002, "invalid length" (stcode.db.10.2): mst_$alloc_segs stores
    it for a zero length, an offset past the object or a segment number
    above 16#FFFF. }
  status_$mst_invalid_length = 16#00040002;

  { mst_$lookup_object's translations of FILE_$CHECK_PROT's ACL statuses
    (stcode.db.10.2's texts): 16#40008 "no rights" for
    status_$no_right_to_perform_operation, 16#40009 "insufficient rights"
    for status_$insufficient_rights_to_perform_operation, 16#4000B "wrong
    type - can't map system objects" for status_$acl_wrong_type. }
  status_$mst_no_rights = 16#00040008;
  status_$mst_insufficient_rights = 16#00040009;
  status_$mst_wrong_type = 16#0004000B;

{ MST_$MAP_CANNED - map a canned (boot-time) object at the top of
  global A, wherever it fits. }
function mst_$map_canned(in uid: uid_$t; size: integer32;
                         flags: univ mst_$canned_flags_t; wire: boolean;
                         desc: integer32; out status: status_$t): univ_ptr;
  options(extern, val_param);

{ ---- For MST_UNWIRED's .TEXT from MST_$DEALLOCATE_ASID. ---- }

const
  { 16#40012: MST_$MAP_INITIAL_AREA stores it when the parent's UID is not
    an anonymous area's.  The SR10.2 table has no text for it (OS / MST
    manager ends at 16#40011); SR10.4's is "specified UID is not for a VM
    area". }
  status_$mst_uid_not_vm_area = 16#00040012;

{ MST_$DEALLOCATE_ASID - free an address space ID. }
procedure mst_$deallocate_asid(asid: integer; out status_ret: status_$t);
  options(extern, val_param);

{ MST_$MAPS_AT - map an object at an address in a given address space. }
procedure mst_$maps_at(addr_hint: integer32; asid: integer;
                       in uid: uid_$t; start_va: integer32;
                       length: integer32; prot: integer;
                       area_size: integer32; wired: boolean;
                       out map_info: integer32;
                       out status_ret: status_$t);
  options(extern, val_param);

const
  { MST_$UNMAP_PRIVI's mode, a bit set (its bit tests): 1 the range may
    lie below the private B segments, 2 every segment must be mapped to
    the UID, 4 keep the MSTE, marked, 16#10 only VM areas.
    MST_$CHANGE_RIGHTS passes 2; MST_$MAP_INITIAL_AREA 0. }
  mst_unmap_any_seg = 16#0001;
  mst_unmap_match_uid = 16#0002;
  mst_unmap_keep_entry = 16#0004;
  mst_unmap_areas_only = 16#0010;

{ MST_$CHANGE_RIGHTS - remap a range of the current address space with
  new access rights. }
procedure mst_$change_rights(in va: integer32; in length: integer32;
                             in rights: integer;
                             out status: status_$t);
  extern;

const
  { 16#4000D, "uid mismatch" (stcode.db.10.2): MST_$INVALIDATE stores it
    when a segment of the range is mapped to another object than the
    caller's UID or does not follow its predecessor's object segment. }
  status_$mst_uid_mismatch = 16#0004000D;

{ MST_$INVALIDATE - discard the pages behind a range of private address
  space. }
procedure mst_$invalidate(in va: linteger; in length: integer32;
                          in uid: uid_$t; in zero_flag: boolean;
                          out status: status_$t);
  extern;

const
  { MST_$UNMAP_PRIVI's mode bit 3 (16#8): MST_$UNMAP_GLOBAL passes it with
    bit 1, and nothing else sets it; MST_$UNMAP_PRIVI never tests it (its
    bit tests are of bits 0, 1, 2 and 4 only).  The name is after the
    map's UNMAP_GLOBAL. }
  mst_unmap_global = 16#0008;

  { MST_$PRIV_SET_TOUCH_AHEAD_CNT's special counts, its `case' labels (a
    jump table): -4 one page, -3 the most, 32, -2 the system's count,
    MST_$TOUCH_COUNT, -1 none stored, only the old count returned.  (A
    lead, not evidence:
    Apollo's ms.ins.pas ms_$access_t has ms_$normal, ms_$random and
    ms_$sequential, which MS_$ADVICE may map onto three of them.) }
  mst_touch_ahead_one = -4;
  mst_touch_ahead_most = -3;
  mst_touch_ahead_system = -2;
  mst_touch_ahead_query = -1;

{ MST_$PRIV_SET_TOUCH_AHEAD_CNT - set the touch-ahead count of the
  segments covering a range of the current address space. }
procedure mst_$priv_set_touch_ahead_cnt(in privileged: boolean;
                                        in va: integer32;
                                        in length: integer32;
                                        in count: integer;
                                        out old_count: pinteger;
                                        out status: status_$t);
  extern;

{ MST_$SET_TOUCH_AHEAD_CNT - set the touch-ahead count of a range,
  unprivileged. }
procedure mst_$set_touch_ahead_cnt(in va: integer32; in length: integer32;
                                   in count: integer;
                                   out old_count: pinteger;
                                   out status: status_$t);
  extern;

{ MST_$UNMAP_GLOBAL - MST_$UNMAP_PRIVI in the current address space,
  mode mst_unmap_match_uid ! mst_unmap_global.
  MST_$UNMAPS - MST_$UNMAP_PRIVI in the current address space, mode
  0.
  MST_$UNMAP_AND_FREE_AREA - MST_$UNMAP_PRIVI in the current address
  space, mode mst_unmap_match_uid ! mst_unmap_areas_only.
  MST_$UNMAPS_AND_FREE_AREA - MST_$UNMAP_PRIVI in the current address
  space, mode mst_unmap_areas_only.
  MST_$UNMAP_ALL - unmap every private A segment of the current address
  space.
  MST_$SET_GUARD - MST_$UNMAP_PRIVI in the current address space, mode
  mst_unmap_match_uid ! mst_unmap_keep_entry. }
procedure mst_$unmap_global(in uid: uid_$t; in start: integer32;
                            in length: integer32;
                            out status_ret: status_$t);
  extern;
procedure mst_$unmaps(in start: integer32; in length: integer32;
                      out status_ret: status_$t);
  extern;
procedure mst_$unmap_and_free_area(in uid: uid_$t; in start: integer32;
                                   in length: integer32;
                                   out status_ret: status_$t);
  extern;
procedure mst_$unmaps_and_free_area(in start: integer32;
                                    in length: integer32;
                                    out status_ret: status_$t);
  extern;
procedure mst_$unmap_all(out status_ret: status_$t);
  extern;
procedure mst_$set_guard(in uid: uid_$t; in start: integer32;
                         in length: integer32;
                         out status_ret: status_$t);
  extern;

{ ---- For MST_$UNMAP_PRIVI .. MST_$FREE_ASID. ---- }

const
  { 16#40007: MST_$UNMAP_PRIVI stores it when mode's match_uid bit is set
    and a segment is not mapped to the UID.  stcode.db.10.2's text
    "object is not mapped". }
  status_$mst_object_is_not_mapped = 16#00040007;

  { 16#4000C: MST_$WIRE_AREA crashes the system with it when the page
    count passes the caller's maximum (a constant cell).  stcode.db.10.2's
    text "ppn list overflow". }
  status_$ppn_list_overflow = 16#0004000C;

{ ---- The forward page tables' MST_ routines (the large VM layout). ---- }

type
  { An ASTE's page-map thread link (ast/ast.ins.pas ast_$pmap_link_t, MST's
    own type so that this file needs no AST_ insert): an address space
    and a segment, 16#FFFF in the first word for none. }
  mst_$pmap_link_t = record
    asid: integer;                        { 0x00 }
    seg: pinteger;                        { 0x02 }
  end;

{ MST_$UNTHREAD_PMAP (map symbol of the SAU6..SAU9 MST code): clear the
  segment-table entries of every MST entry on a page map's thread, and end
  the thread; the link by address, read and then set to none. }
procedure mst_$unthread_pmap(in out link: univ mst_$pmap_link_t); extern;

{ MST_$BST_TO_VA (map symbol of the SAU7..SAU9 MST code): the virtual
  address of a segment that an address space maps through a page map's
  thread; the link by value, the ASID a word by value, the segment's
  address and the ASID that maps it (0 for a global segment) out
  (`val_param'); true when one was found. }
function mst_$bst_to_va(link: univ mst_$pmap_link_t; asid: integer;
                        out va: integer32; out found_asid: integer):
  boolean; options(extern, val_param);

{ MST_$ASSOC, MST_$INSTALL_IOPPN, MST_$REMOVE_IOPPN (map symbols of the
  SAU6..SAU9 MST code): associate a physical page with the page of a
  virtual address (AST_$PMAP_ASSOC), map an I/O page there
  (AST_$ASSOC_IOPPN), and unmap it (AST_$REMOVE_IOPPN).  MST_$ASSOC
  takes its arguments by address; the other two by value
  (`val_param'). }
procedure mst_$assoc(in va: integer32; in ppn: integer32;
                     out status: status_$t); extern;
procedure mst_$install_ioppn(ppn: integer32; va: integer32;
                             out status: status_$t);
  options(extern, val_param);
procedure mst_$remove_ioppn(va: integer32); options(extern, val_param);
