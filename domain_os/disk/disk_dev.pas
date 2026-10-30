{ disk/disk_dev.pas - the DISK_ module's second unit: the driver table.

  Image addresses:
    sau2  0x00E7AD5C  DISK_ data (.DATA, 0x198 bytes)

  One compilation unit: the map's second DISK_ code segment (.TEXT,
  0x2A8 bytes: DISK_$REGISTER .. DISK_$SHUTDOWN) and its second data
  segment (.DATA, 0x198 bytes).  The heading is the module's name,
  `module disk_;', as the other two units' (disk/README.md).

  The data, 0x198 bytes, all zero in the image:

    +0x000  disk_$devices   32 * 0xC  the registered drivers
    +0x180  stats_template  0x16      DISK_$GET_STATS' static, the zero
                                       block it hands out first
    +0x196  (2 bytes: the block's rounding to 4)

  The routines live in one fragment file each (disk/<name>.pas),
  included below in image order.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/disk/disk_dev.pas.  Check: tools/pascal_check.sh.
}
module disk_;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'time/time.ins.pas';
%include 'disk/disk.ins.pas';

{ TODO(pascal) the unit's frames against their locals

  Eight of the nine routines reserve frame bytes that none of their
  objects explains; DISK_$DO_IO,
  _$ERROR_QUE, _$REVALID, _$SHUTDOWN and _$MNT_DINIT make one call
  through the driver's jump table and have no local.  Two compiler
  temporaries for each call through a converted routine pointer would
  explain those five (a
  lead).  No stand-ins are declared. }

{ The module's own variable (ref 7.2.2), at the block's start. }
var
  disk_$devices: array[1..32] of disk_$device_entry_t;   { +0x000, zero }

define
  disk_$register;
  disk_$get_drte;
  disk_$mnt_dinit;
  disk_$do_io;
  disk_$error_que;
  disk_$spin_down;
  disk_$revalid;
  disk_$get_stats;
  disk_$shutdown;

{ ---- .TEXT ---- }
%include 'disk/register.pas';               { DISK_$REGISTER  }
%include 'disk/get_drte.pas';               { DISK_$GET_DRTE  }
%include 'disk/mnt_dinit.pas';              { DISK_$MNT_DINIT }
%include 'disk/do_io.pas';                  { DISK_$DO_IO     }
%include 'disk/error_que.pas';              { DISK_$ERROR_QUE }
%include 'disk/spin_down.pas';              { DISK_$SPIN_DOWN }
%include 'disk/revalid.pas';                { DISK_$REVALID   }
%include 'disk/get_stats.pas';              { DISK_$GET_STATS }
%include 'disk/shutdown.pas';               { DISK_$SHUTDOWN  }
