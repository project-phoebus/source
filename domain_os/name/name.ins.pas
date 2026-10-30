{ name/name.ins.pas - NAME_ (the naming server), for the Domain Pascal
  tree.

  Only what the Pascal files use.  The status codes are Apollo's where
  the SR10.2 customer name.ins.pas ("name.ins.pas -- /sys/ins -- phl --
  06/15/87") has them; the routines' headings are read off the image.

  Include base/base.ins.pas before it.
}

const
  { The entry types of the old (pre-SR10) directory format and of
    DIR_$GET_ENTRYU's entry: Apollo's `name_$file = 1; name_$link = 3;'
    (customer name.ins.pas, "Type values for ENTTYPE in the directory
    list"), and 0, an unused slot or no entry (name_$resolve_internal's,
    dir_$old_read_linku's and dir_$old_unlink_entry's `case'): the name
    name_$entry_none is new. }
  name_$entry_none = 0;
  name_$file = 1;
  name_$link = 3;
  { Apollo's `name_$not_found = 16#000E0007' (customer name.ins.pas).
    LOG_$INIT compares the status of NAME_$RESOLVE with it; NAME_$RESOLVE
    stores it in place of 16#000E0020. }
  name_$not_found = 16#000E0007;

  { Apollo's `name_$already_exists = 16#000E0003' (customer name.ins.pas
    line 24).  flop_$mount_floppy compares DIR_$ADDU's status with it. }
  name_$already_exists = 16#000E0003;

  { Apollo's `name_$directory_full = 16#000E0002' (customer name.ins.pas
    line 23).  VOLX_$MOUNT compares DIR_$ADD_MOUNT's status with it. }
  name_$directory_full = 16#000E0002;

  { Apollo's `name_$bad_pathname = 16#000E0004' (customer name.ins.pas
    line 25).  REM_NAME_$GET_ENTRY_BY_NAME stores it for a name longer
    than 32; REM_NAME_$GET_ENTRY compares with it.  (REM_NAME addition.) }
  name_$bad_pathname = 16#000E0004;

  { Four naming statuses the customer name.ins.pas does not declare
    (the SR10.2 status database's texts: "cannot find entry in
    replicated root", "last entry in replicated root returned", "name
    server helper sent packet with errors", "cant find name server
    helper").  REM_NAME's routines compare and store them
    (REM_NAME_$DIR_READU, _$READ_DIR, _$GET_INFO, LOCATE_SERVER). }
  status_$naming_cannot_find_entry_in_replicated_root = 16#000E0019;
  status_$naming_last_entry_in_replicated_root_returned = 16#000E001A;
  status_$naming_helper_sent_packets_with_errors = 16#000E001C;
  status_$naming_cant_find_name_server_helper = 16#000E001E;

{ NAME_$RESOLVE - resolve a pathname to the UID of the object it names. }
procedure name_$resolve(in path: univ name_$long_pname_t;
                        in path_len: integer;
                        out resolved_uid: uid_$t;
                        out status: status_$t);
  extern;

{ NAME_$CR_FILE - create a file and enter it under a pathname. }
procedure name_$cr_file(in path: univ name_$long_pname_t;
                        in path_len: integer;
                        out file_ret: uid_$t;
                        out status: status_$t);
  extern;

{ NAME_$GET_NODE_UID (compiled, global, A5 loaded): a function whose
  UID result goes through a hidden address: it stores the node's UID
  through its one argument, and its compiled callers (flop_$mount_floppy,
  name_$resolve_internal, ASKNODE_$INTERNET_INFO) pass a frame
  temporary and copy out of it, never the destination itself. }
function name_$get_node_uid: uid_$t; extern;

{ NAME_$CLEANUP - clean up after a failed naming operation. }
procedure name_$cleanup; extern;

{ }

const
  { Apollo's (customer name.ins.pas: `name_$file_not_directory    =
    16#000E000e;', `name_$no_rights             = 16#000E0013;',
    `name_$insufficient_rights   = 16#000E0014;'): what
    NAME_CONVERT_ACL_STATUS stores. }
  name_$file_not_directory = 16#000E000E;
  name_$no_rights = 16#000E0013;
  name_$insufficient_rights = 16#000E0014;

{ NAME_CONVERT_ACL_STATUS - turn three ACL statuses into naming ones. }
procedure name_convert_acl_status(in out status: status_$t); extern;

{ }

{ NAME_$DROP - drop a pathname's leaf from its directory. }
procedure name_$drop(in path: univ name_$long_pname_t;
                     in path_len: integer;
                     var file_uid: uid_$t;
                     out status: status_$t);
  extern;

{ }

const
  { The start-path types NAME_$VALIDATE stores and name_$resolve_internal
    dispatches on (its jump table has entries for 1..5, 2 to the join).
    No customer insert file declares them;  Plain integer constants, not
    an enumeration: no name is known for 2. }
  start_path_$error = 0;
  start_path_$relative = 1;
  start_path_$absolute = 3;
  start_path_$network = 4;
  start_path_$node_data = 5;

  { 16#000E0020, "directory not found in pathname", and 16#000E0025,
    "internal error" (the status database's texts; the customer
    name.ins.pas has neither).  name_$resolve_dir_and_leaf and
    NAME_$RESOLVE replace the first by name_$not_found; name_$map_dir
    crashes with the second (a constant cell). }
  status_$naming_directory_not_found_in_pathname = 16#000E0020;
  status_$naming_internal_error = 16#000E0025;

  { The address spaces NAME keeps a working and a naming directory for:
    NAME_$INIT's loop count, 58 elements. }
  name_$max_asids = 58;

type
  { A directory's mapping as NAME keeps it, 16 bytes: name_$map_dir sets
    active and clears it, clears reserved_02, stores MST_$MAPS' address
    into first_base, 1 into entry_count and first_base + 16#8000 into
    second_base; name_$unmap_dir_buffers tests active and compares
    first_base + 16#8000 with second_base.  The bases are integer32:
    added to and compared as numbers, and passed as MST_$UNMAP_PRIVI's
    longword start.  The byte at 0x01 is the alignment of reserved_02. }
  name_$mapped_info_t = record
    active: boolean;                      { 0x00 }
    reserved_02: integer;                 { 0x02 }
    first_base: integer32;                { 0x04 }
    reserved_08: integer;                 { 0x08 }
    entry_count: integer;                 { 0x0A }
    second_base: integer32;               { 0x0C }
  end;

  { The event UID NAME_$SET_WDIRUS and NAME_$SET_NDIRUS build for
    AUDIT_$LOG_EVENT: UID_$NIL copied in, then the byte at 0x01 and the
    word at 0x02 stored, the event 16#00040027 (or 16#00040028) 00000000.
    The byte store says the class is a byte at 0x01
    (audit/audit.ins.pas's audit_$event_uid_t, built by DIR's event
    loggers, stores the same class as a word at 0x00).  The second
    variant's field names are that type's. }
  name_$event_uid_t = record
    case integer of
      1: (uid: uid_$t);                   { 0x00 }
      2: (unused_00: [byte] 0..255;       { 0x00 }
          event_class: [byte] 0..255;     { 0x01 }
          audit_subtype: integer;         { 0x02 }
          reserved: integer32);           { 0x04 }
  end;

var
  { The objects of NAME's .DATA block, every one a map symbol, defined in
    name/name.pas, in the block's order (+0x000, +0x008, +0x018, +0x020,
    +0x030, +0x038, +0x040, +0x3E0, +0x5B0, +0x950).  The four
    per-address-space arrays are indexed by the address space from 0:
    NAME_$GET_WDIR_UID indexes with no bias, the map symbol the element
    of address space 0; NAME_$INIT's loop starts at the symbols. }
  name_$node_data_uid: extern uid_$t;
  name_$com_mapped_info: extern name_$mapped_info_t;
  name_$com_uid: extern uid_$t;
  name_$node_mapped_info: extern name_$mapped_info_t;
  name_$node_uid: extern uid_$t;
  name_$root_uid: extern uid_$t;
  name_$ndir_mapped_info: extern array[0..name_$max_asids - 1] of
                                   name_$mapped_info_t;
  name_$ndir_uid: extern array[0..name_$max_asids - 1] of uid_$t;
  name_$wdir_mapped_info: extern array[0..name_$max_asids - 1] of
                                   name_$mapped_info_t;
  name_$wdir_uid: extern array[0..name_$max_asids - 1] of uid_$t;

  { NAME_$CANNED_ROOT_UID (map symbol in UID_LIST, the read-only UID
    table; 16#00000308.00000000): NAME_$GET_CANNED_ROOT_UID copies it,
    and NAME_$INIT passes its address to FILE_$SET_DIRPTR.  Defined by
    UID_LIST, not by a NAME unit. }
  name_$canned_root_uid: extern uid_$t;

{ NAME_$INIT - initialize the naming server. }
procedure name_$init(in vol_root_uid: uid_$t; in vol_node_uid: uid_$t);
  extern;

{ NAMEQ - compare two names, trailing blanks ignored. }
function nameq(in str1: univ name_$long_pname_t; in len1: pinteger;
               in str2: univ name_$long_pname_t; in len2: pinteger): boolean;
  extern;

{ NAME_$VALIDATE - classify how a pathname begins. }
function name_$validate(in path: univ name_$long_pname_t;
                        in path_len: pinteger;
                        in out consumed: integer;
                        out start_path_type: integer): boolean;
  extern;

{ NAME_$SET_WDIR - set the working directory from a pathname. }
procedure name_$set_wdir(in path: univ name_$long_pname_t;
                         in path_len: integer;
                         out status: status_$t);
  extern;

{ NAME_$SET_ACL - set an object's ACL. }
procedure name_$set_acl(in uid: uid_$t; in acl: uid_$t;
                        out status: status_$t);
  extern;

{ NAME_$SET_WDIRUS - make a directory the working directory.
  NAME_$SET_NDIRUS - make a directory the naming directory. }
procedure name_$set_wdirus(in uid: uid_$t; out status: status_$t); extern;
procedure name_$set_ndirus(in uid: uid_$t; out status: status_$t); extern;

{ NAME_$READ_DIRS_PS - read a process's working and naming directories. }
procedure name_$read_dirs_ps(in proc_uid: uid_$t; out wdir_uid: uid_$t;
                             out ndir_uid: uid_$t; out status: status_$t);
  extern;

{ The UID getters (compiled, global; SVC entries): each copies a UID
  through its one argument, never reading it.  NAME_$GET_ROOT_UID and
  NAME_$GET_NODE_DATA_UID are functions, as NAME_$GET_NODE_UID (its
  heading is above): their compiled callers (name_$resolve_internal,
  ASKNODE_$INTERNET_INFO) pass a frame temporary as the hidden result
  address.  The others, called only through the SVC table, are `out'
  procedures (the same code). }
procedure name_$get_wdir_uid(out wdir_uid: uid_$t); extern;
procedure name_$get_ndir_uid(out ndir_uid: uid_$t); extern;
function name_$get_root_uid: uid_$t; extern;
function name_$get_node_data_uid: uid_$t; extern;
procedure name_$get_canned_root_uid(out canned_root_uid: uid_$t); extern;

{ NAME_$INIT_ASID - give a new address space its directories.
  NAME_$FORK - give a child address space its parent's directories.
  NAME_$FREE_ASID - release an address space's directories. }
procedure name_$init_asid(in new_asid: integer; out status: status_$t);
  extern;
procedure name_$fork(in parent_asid: integer; in child_asid: integer);
  extern;
procedure name_$free_asid(in asid: integer); extern;

{ 16#000E0016, "directory is in use (locked)" (the status database's
  text; the customer name.ins.pas does not have it): dir_$lock_obj's
  status until the lock is granted. }
const
  status_$naming_directory_locked = 16#000E0016;

{ 16#000E0033, "directory object not found" (stcode.db.10.2):
  dir_$validate_handle's status for a missing or remote directory. }
const
  status_$naming_directory_object_not_found = 16#000E0033;

{ 16#000E0031, "write-protected volume prevents recovery of a damaged
  directory" (stcode.db.10.2): dir_$open_dir's status when a directory
  to repair lies on a read-only volume. }
const
  status_$naming_cant_recovery_dir_on_ro_vol = 16#000E0031;

{ 16#000E002B, "directory not local" (stcode.db.10.2): one of the
  statuses dir_$is_retryable_status takes as a reason to retry. }
const
  status_$naming_directory_not_local = 16#000E002B;

{ Apollo's `name_$bad_leaf = 16#000E000b' (customer name.ins.pas):
  dir_$do_op_resolve's status for a component longer than 255, and
  DIR_$GET_ENTRYU's for a name length of 0 or above 255. }
const
  name_$bad_leaf = 16#000E000B;

{ Apollo's `name_$not_link = 16#000E0006' and `name_$pathname_truncated
  = 16#000E002C' (customer name.ins.pas): dir_$do_op_read_linku's
  statuses for an entry that is not a soft link, and for a link text cut
  to the caller's buffer.  16#000E002E, "bad buffer size"
  (stcode.db.10.2): DIR_$READ_LINKU's status for a buffer length of 0 or
  less. }
const
  name_$not_link = 16#000E0006;
  name_$pathname_truncated = 16#000E002C;
  status_$naming_bad_buffer_size = 16#000E002E;

{ NAME_$CANNED_REP_ROOT_UID (map symbol in UID_LIST, the read-only UID
  table, beside NAME_$CANNED_ROOT_UID; 16#00000404.00000000):
  DIR_$DIR_READU and its nested dir_$dir_readu_fallback compare the
  directory's UID with it, as DIR_$OLD_DIR_READU does.  Defined by
  UID_LIST, not by a NAME unit. }
var
  name_$canned_rep_root_uid: extern uid_$t;

{ Apollo's `name_$leaf_truncated = 16#000E002D' (customer name.ins.pas,
  line 40): dir_$find_uid_internal stores it when the name found is
  longer than the caller's buffer. }
const
  name_$leaf_truncated = 16#000E002D;

{ 16#000E0022 "cache entry is stale", 16#000E0023 "cache entry was stale
  and was updated" and 16#000E0032 "too many hard links exist to file"
  (stcode.db.10.2; Apollo's customer name.ins.pas has none of them):
  dir_$do_op_validate_root_entry stores the first two and tests the
  second; dir_$do_op_add_link stores the third. }
const
  status_$naming_cache_entry_stale = 16#000E0022;
  status_$naming_cache_entry_stale_and_updated = 16#000E0023;
  status_$naming_too_many_hard_links = 16#000E0032;

{ Apollo's `name_$bad_link = 16#000E0005', `name_$ill_link_op =
  16#000E000a' and `name_$not_file = 16#000E0010' (customer
  name.ins.pas, lines 26, 29, 35; stcode.db.10.2 "invalid link
  operation", "name is not a file"): DIR_$ADD_LINKU stores the first;
  dir_$do_op_add_bak the second and third. }
const
  name_$bad_link = 16#000E0005;
  name_$ill_link_op = 16#000E000A;
  name_$not_file = 16#000E0010;

{ 16#000E0012, "bad type" (stcode.db.10.2): dir_$read_def_prot stores it
  for an ACL type other than ACL_$DIR_ACL and ACL_$FILE_ACL. }
const
  status_$naming_bad_type = 16#000E0012;

{ Apollo's `name_$directory_not_empty = 16#000E000f;' (customer
  name.ins.pas; stcode.db.10.2 "directory is not empty"):
  dir_$do_op_drop_dir stores it. }
const
  name_$directory_not_empty = 16#000E000F;

{ 16#000E0011, "illegal directory operation" (stcode.db.10.2; Apollo's
  name.ins.pas has none for it): DIR_$OLD_READ_INFOBLK and
  DIR_$OLD_WRITE_INFOBLK store it for a page that is not the old format;
  DIR_$OLD_SET_DEFAULT_ACL for a remote node's bad reply. }
const
  status_$naming_illegal_directory_operation = 16#000E0011;

{ 16#000E002F, "object is not an acl object" (stcode.db.10.2):
  DIR_$OLD_SET_DEFAULT_ACL stores it when the replaced default ACL's
  object is not of sub-type 3. }
const
  status_$naming_object_is_not_an_acl_object = 16#000E002F;

{ 16#000E001F, "directory must be root" (stcode.db.10.2):
  DIR_$OLD_ROOT_ADDU stores it for a directory other than
  NAME_$ROOT_UID. }
const
  status_$naming_directory_must_be_root = 16#000E001F;

{ 16#000E0026, "bad request header version", and 16#000E0028, "bad
  request body version" (stcode.db.10.2): DIR_$SERVER stores them when a
  remote request's header or body version is newer than this node's. }
const
  status_$naming_bad_request_header_version = 16#000E0026;
  status_$naming_bad_request_body_version = 16#000E0028;

{ NAME_'s statuses that FILE_ stores (stcode.db.10.2, OS / naming server):
  - 16#000E0030, "volume has been mounted read-only": FILE_$PRIV_CREATE
    for a directory or link on a read-only volume;
  - 16#000E000D, "bad directory": FILE_$PRIV_LOCK for a non-empty
    directory locked for delete; DIR's routines test and store it too
    (dir/open_dir.pas, dir/validate_handle.pas, the DIR_$<op>U
    fallbacks). }
const
  status_$naming_vol_mounted_read_only = 16#000E0030;
  status_$naming_bad_directory = 16#000E000D;
