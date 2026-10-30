{ vtoc/vtoc.pas - the VTOC_ module, the volume table of contents.

  Image addresses:
    sau2  0x00E784D0  VTOC_ data (.DATA, 0x688 bytes)
    sau2  0x00EB2C00  VTOC_CACHE (overlay section, 0x1940 bytes)

  One compilation unit, `module vtoc_;': the map's VTOC_ code segments
  in WIRED_PROC (VTOCE_$OLD_TO_NEW, headed `[section(wired_proc,
  wired_data)]') and .TEXT (OS_DISK_PROC .. FM_$WRITE, with
  os/disk_proc.pas and fm/read.pas, fm/write.pas), its data segment in
  .DATA (1672 bytes) and the overlay VTOC_CACHE (6464 bytes).

  The data, zero but vtoc_$dirty's 16#FF, the arrays 1-based:
    +0x000  vtoc_$mount_locs   8 * 2 bytes, the volumes' mount words
    +0x010  vtoc_$vols         6 * 100 bytes, the volumes' VTOC records
    +0x268  VTOC_CACH_HITS     4 bytes (defined)
    +0x26C  VTOC_CACH_LOOKUPS  4 bytes (defined)
    +0x270  vtoc_$cach_wp_flag 8 bytes, the write-protect flags

    +0x278  vtoc_$mounted      8 bytes, the mounted flags
    +0x280  vtoc_$format       6 bytes, the new-format flags
    +0x286  vtoc_$dirty        1 byte, the pending OS_DISK_PROC call
    +0x287  (1 byte: the next object's alignment)
    +0x288  vtoc_$free_list    256 * 4 bytes, VTOCE_$TRUNCATE's blocks

  The overlay VTOC_CACHE is the UID cache, 101 buckets of four 16-byte
  entries: `var (vtoc_cache)' (ref 3.14, p. 3-52).

  The routines live in one fragment file each (the UID cache's three in
  one), included below in image order; the nested helpers lie before
  their parents.

  Build: dpc -I domain_os domain_os/vtoc/vtoc.pas.  Check:
  tools/pascal_check.sh.
}

{ TODO(pascal) VTOC_'s frames have bytes no object explains

  Most of the module's routines have frame bytes that no declared local
  explains; the gaps are held by no declared stand-in.  Loop indices
  kept in registers and `with' temporaries would account for some; the
  8-byte alignment of the audit records places them as seen.  Not
  settled. }

module vtoc_;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'node/node.ins.pas';
%include 'uid/uid.ins.pas';
%include 'rgyc/rgyc.ins.pas';
%include 'file/file.ins.pas';
%include 'acl/acl.ins.pas';
%include 'audit/audit.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'disk/disk.ins.pas';
%include 'dbuf/dbuf.ins.pas';
%include 'fm/fm.ins.pas';
%include 'vtoc/vtoc.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'route/route.ins.pas';
%include 'network/network.ins.pas';
%include 'netlog/netlog.ins.pas';
%include 'bat/bat.ins.pas';

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above), the routines in
  map order. }
var
  vtoc_$mount_locs: array[1..8] of vtoc_$mount_loc_t;   { +0x000, zero }
  vtoc_$vols: array[1..6] of vtoc_$vol_t;   { +0x010, zero }

define
  vtoc_cach_hits;                         { +0x268, zero }
  vtoc_cach_lookups;                      { +0x26C, zero }

var
  vtoc_$cach_wp_flag: array[1..8] of boolean;   { +0x270, zero }
  vtoc_$mounted: array[1..8] of boolean;  { +0x278, zero }
  vtoc_$format: array[1..6] of boolean;   { +0x280, zero }
  vtoc_$dirty: boolean := true;           { +0x286: ff }
  vtoc_$free_list: array[1..256] of integer32;   { +0x288, zero }

{ The UID cache, the overlay VTOC_CACHE (above). }
var (vtoc_cache)
  vtoc_$uid_cache: array[0..100] of vtoc_$uid_cache_bucket_t;

define
  vtoce_$old_to_new;
  os_disk_proc;
  vtoce_$new_to_old;
  vtoc_$mount;
  vtoc_$dismount;
  vtoc_$allocate;
  vtoc_$lookup;
  vtoc_$get_uid;
  vtoc_$get_name_dirs;
  vtoc_$set_name_dirs;
  vtoce_$read;
  vtoce_$write;
  vtoce_$lookup_fm;
  vtoce_$truncate;
  fm_$read;
  fm_$write;

{ ---- WIRED_PROC ---- }
%include 'vtoc/old_to_new.pas';             { VTOCE_$OLD_TO_NEW }

{ ---- .TEXT ---- }
%include 'os/disk_proc.pas';                { OS_DISK_PROC }
%include 'vtoc/uid_cache_insert.pas';       { vtoc_$uid_cache_insert }
%include 'vtoc/uid_cache_lookup.pas';       { vtoc_$uid_cache_lookup }
%include 'vtoc/hash_uid.pas';               { vtoc_$hash_uid }
%include 'vtoc/new_to_old.pas';             { VTOCE_$NEW_TO_OLD }
%include 'vtoc/mount.pas';                  { VTOC_$MOUNT }
%include 'vtoc/dismount.pas';               { VTOC_$DISMOUNT }
%include 'vtoc/allocate.pas';               { VTOC_$ALLOCATE }
%include 'vtoc/lookup.pas';                 { VTOC_$LOOKUP }
%include 'vtoc/get_uid.pas';                { VTOC_$GET_UID }
%include 'vtoc/get_name_dirs.pas';          { VTOC_$GET_NAME_DIRS }
%include 'vtoc/set_name_dirs.pas';          { VTOC_$SET_NAME_DIRS }
%include 'vtoc/vtoce_read.pas';             { VTOCE_$READ }
%include 'vtoc/vtoce_write.pas';            { VTOCE_$WRITE }
%include 'vtoc/lookup_fm.pas';              { VTOCE_$LOOKUP_FM, its
                                              nested vtoc_$fm_traverse }
%include 'vtoc/truncate.pas';               { VTOCE_$TRUNCATE, its
                                              nested vtoc_$free_indirect }
%include 'fm/read.pas';                     { FM_$READ }
%include 'fm/write.pas';                    { FM_$WRITE }
