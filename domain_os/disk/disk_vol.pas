{ disk/disk_vol.pas - the DISK_ module's third unit: the volumes.

  Image addresses:
    sau2  0x00E826C4  DISK_ data (.DATA, 0x64 bytes)

  One compilation unit: the map's third DISK_ code segment (.TEXT,
  0x1AF0 bytes: disk_$diskless_init, AS_IO_SETUP ..
  DISK_$LVUID_TO_VOLX) and its third data segment (.DATA, 0x64 bytes).
  The heading is the module's name, `module disk_;', as the other two
  units' (disk/README.md).

  The data, 0x64 bytes, disk_$pv_mount_internal's statics (declared in
  disk/pv_mount_internal.pas):

    +0x00  vol_template  0x48  a volume descriptor (disk_$volume_t):
                               addr_start 1, sec_per_track 1, num_heads 2,
                               blocks_per_cyl 4, bat_step 1, num_parts 1,
                               the rest zero
    +0x48  log2_table    0x14  ten words 0 0 1 0 2 0 0 0 3 0
    +0x5C  pow2_table    0x08  four words 1 2 4 0, indexed by a code

  The routines live in one fragment file each (disk/<name>.pas),
  included below in image order.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/disk/disk_vol.pas.  Check: tools/pascal_check.sh.
}
module disk_;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'uid/uid.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'acl/acl.ins.pas';
%include 'mst/mst.ins.pas';
%include 'wp/wp.ins.pas';
%include 'mmap/mmap.ins.pas';
%include 'cache/cache.ins.pas';
%include 'os/os.ins.pas';
%include 'pmap/pmap.ins.pas';
%include 'io/io.ins.pas';
%include 'disk/disk.ins.pas';
%include 'dbuf/dbuf.ins.pas';
%include 'node/node.ins.pas';
%include 'fm/fm.ins.pas';
%include 'vtoc/vtoc.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'network/network.ins.pas';
%include 'bat/bat.ins.pas';
%include 'audit/audit.ins.pas';

{ TODO(pascal) the unit's frames against their locals

  Several of the unit's routines reserve frame bytes that their locals,
  result variables and `with' temporaries do not fill and that nothing
  addresses.  The frame model does not
  settle where value parameters' copies and the result variable go; no
  stand-ins are declared. }

define
  as_io_setup;
  disk_$read_mfg_badspots;
  disk_$as_read;
  disk_$as_write;
  disk_$as_xfer_multi;
  disk_$diag_io;
  disk_$unassign;
  disk_$unassign_all;
  disk_$get_mnt_info;
  disk_$revalidate;
  disk_$get_error_info;
  disk_$as_options;
  disk_$pv_assign_n;
  disk_$pv_assign;
  disk_$pv_mount;
  disk_$lv_mount;
  disk_$lv_uid;
  disk_$lv_assign;
  disk_$dismount;
  disk_$lvuid_to_volx;

{ ---- .TEXT ---- }
%include 'disk/diskless_init.pas';          { disk_$diskless_init     }
%include 'disk/as_io_setup.pas';            { AS_IO_SETUP             }
%include 'disk/read_mfg_badspots.pas';      { DISK_$READ_MFG_BADSPOTS }
%include 'disk/as_read.pas';                { DISK_$AS_READ           }
%include 'disk/as_write.pas';               { DISK_$AS_WRITE          }
%include 'disk/as_xfer_multi.pas';          { DISK_$AS_XFER_MULTI     }
%include 'disk/diag_io.pas';                { DISK_$DIAG_IO           }
%include 'disk/unassign.pas';               { DISK_$UNASSIGN          }
%include 'disk/unassign_all.pas';           { DISK_$UNASSIGN_ALL      }
%include 'disk/get_mnt_info.pas';           { DISK_$GET_MNT_INFO      }
%include 'disk/revalidate.pas';             { DISK_$REVALIDATE        }
%include 'disk/get_error_info.pas';         { DISK_$GET_ERROR_INFO    }
%include 'disk/as_options.pas';             { DISK_$AS_OPTIONS        }
%include 'disk/pv_mount_internal.pas';      { disk_$pv_mount_internal,
                                              its nested
                                              disk_$pvmi_find_slot and
                                              disk_$validate_pv_label }
%include 'disk/pv_assign_n.pas';            { DISK_$PV_ASSIGN_N       }
%include 'disk/pv_assign.pas';              { DISK_$PV_ASSIGN         }
%include 'disk/pv_mount.pas';               { DISK_$PV_MOUNT          }
%include 'disk/lv_mount.pas';               { DISK_$LV_MOUNT          }
%include 'disk/lv_uid.pas';                 { DISK_$LV_UID            }
%include 'disk/lv_assign.pas';              { DISK_$LV_ASSIGN         }
%include 'disk/dismount.pas';               { DISK_$DISMOUNT          }
%include 'disk/lvuid_to_volx.pas';          { DISK_$LVUID_TO_VOLX     }
