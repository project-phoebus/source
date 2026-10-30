{ volx/volx.ins.pas - VOLX_ (volume mounting), for the Domain Pascal
  tree.

  Only what the Pascal files use.  No customer insert file declares
  these kernel entry points.  Include base/base.ins.pas before it.
}

const
  { 16#0014FFFF, "Warning: disk is write protected" (stcode.db.10.2).
    flop_$mount_floppy compares VOLX_$MOUNT's status with it
    (flop/boot.pas). }
  status_$volume_disk_is_write_protected = 16#0014FFFF;

  { The volume manager's codes the VOLX routines store (stcode.db.10.2,
    OS / volume manager): VOLX_$DISMOUNT's and VOLX_$MOUNT's. }
  status_$volume_unable_to_dismount_boot_volume = 16#00140002;
  status_$volume_logical_vol_not_mounted = 16#00140003;
  status_$volume_entry_directory_not_on_logical_volume = 16#00140004;
  status_$volume_physical_vol_replaced_since_mount = 16#00140005;
  status_$volx_volume_table_full = 16#00140006;
  status_$volx_directory_in_use = 16#00140007;

  { The mount table's entries: the scans run six times from index 1, and
    6 * 0x20 is the data segment's 0xC0 bytes. }
  volx_max_volumes = 6;

type
  { A mount table entry, 0x20 bytes.  The fields carry the prefix e_ (as
    netlog/netlog.ins.pas's entry): FIND_VOLX and VOLX_$MOUNT reach them
    inside a `with', where unprefixed names would hide their parameters
    dev, bus, ctlr, lv_num. }
  volx_$entry_t = record
    e_dir_uid: uid_$t;                    { 0x00 }
    e_lv_uid: uid_$t;                     { 0x08 }
    e_parent_uid: uid_$t;                 { 0x10 }
    e_dev: integer;                       { 0x18 }
    e_bus: integer;                       { 0x1A }
    e_ctlr: integer;                      { 0x1C }
    e_lv_num: integer;                    { 0x1E }
  end;

{ FIND_VOLX (volx/find_volx.pas): global, the name without `$'
  notwithstanding. }
function find_volx(dev: integer; bus: integer; ctlr: integer;
                   lv_num: integer): integer;
  options(extern, val_param);

{ VOLX_$MOUNT - mount a logical volume. }
procedure volx_$mount(in dev: integer; in bus: integer; in ctlr: integer;
                      in lv_num: integer; salvage_ok: boolean;
                      in write_prot: boolean; parent_uid: uid_$t;
                      out dir_uid_ret: uid_$t; out status: status_$t);
  extern;

{ VOLX_$DISMOUNT - dismount a logical volume. }
procedure volx_$dismount(dev: integer; bus: integer; ctlr: integer;
                         lv_num: integer; entry_uid: uid_$t;
                         in force: boolean; out status: status_$t);
  extern;

{ VOLX_$SHUTDOWN - dismount every mounted volume. }
function volx_$shutdown: integer32; extern;

{ VOLX_$GET_INFO - a volume's free and total blocks and its directory. }
procedure volx_$get_info(vol_idx: integer; out dir_uid_ret: uid_$t;
                         out free_blocks: integer32;
                         out total_blocks: integer32;
                         out status: status_$t); extern;

{ VOLX_$GET_UIDS - the UIDs of the volume at a physical location. }
procedure volx_$get_uids(dev: integer; bus: integer; ctlr: integer;
                         lv_num: integer; out lv_uid_ret: uid_$t;
                         out dir_uid_ret: uid_$t; out status: status_$t);
  extern;

{ VOLX_$REC_ENTRY - record a volume's entry directory. }
procedure volx_$rec_entry(in vol_idx: integer; in dir_uid: uid_$t); extern;
