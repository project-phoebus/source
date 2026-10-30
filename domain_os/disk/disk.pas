{ disk/disk.pas - the DISK_ module's first unit: the request layer.

  Image addresses:
    sau2  0x00E7A1CC  DISK_ data (.DATA, 0xB90 bytes)

  One compilation unit: the map's first DISK_ code segment (.TEXT,
  0x1E2C bytes, DISK_$GET_BLOCK .. DISK_$WRITE_PROTECT) and its first
  data segment (.DATA, 0xB90 bytes).  The map's DISK_ module is three
  units of one name (disk/README.md): this one, disk/disk_dev.pas
  and disk/disk_vol.pas.  The heading: `module disk_;'.

  The data, 0xB90 bytes, zero in the image but the words 1 at +0xAF2 and
  +0xAF4:

    +0x000  disk_$ec              0xC   the module's eventcount
    +0x00C  unused_0c             4     a stand-in (below)
    +0x010  disk_$req_queue  64 * 2     the waiting requests' counts, a
                                        ring from 1, indexed by words
    +0x090  disk_$exclusion       0x12  the queue blocks' lock
    +0x0A2  unused_a2, unused_a4  6     stand-ins (below)

    +0x0A8  disk_$exclusion_2     0x12  DISK_IO's lock
    +0x0BA  (2 bytes: the next longword's alignment)
    +0x0BC  disk_$reserve_block   4     the reserved queue block
    +0x0C0  disk_$free_head       4     the free queue blocks' list
    +0x0C4  DISK_$DVTBL      10 * 0x48  defined; the volumes from 1

    +0x394  DISK_BPTBL       64 * 0x1C  defined; the processes' slots
                                        from 1, by PROC1_$CURRENT
    +0xA94  DISK_$ERROR_INFO      0x56  defined
    +0xAEA  (2 bytes: the next longword's alignment)
    +0xAEC  DISK_$RAW_PPN         4     defined; DISK_IO's read-back page
    +0xAF0  disk_$pages_alloc     2     the pool's pages

    +0xAF2  disk_$req_read_idx    2     := 1: the ring's consumer
    +0xAF4  disk_$req_write_idx   2     := 1: the ring's producer
    +0xAF6  disk_$pending_count   2     the waiting requests
    +0xAF8  DISK_$NFBLKS          2     defined; the free blocks
    +0xAFA  disk_$alloc_disabled  2     a boolean
    +0xAFC  disk_$reserve_avail   2     a boolean

    +0xAFE  DISK_$DIAG            2     defined; a boolean
    +0xB00  DISK_$DO_CHKSUM       2     defined; a boolean
    +0xB02  unused_b02, unused_b04 6    stand-ins (below)
    +0xB08  disk_$que_array  34 * 4     DISK_$ADD_QUE's runs

  The routines live in one fragment file each (disk/<name>.pas),
  included below in image order.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/disk/disk.pas.  Check: tools/pascal_check.sh.
}
module disk_;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'log/log.ins.pas';
%include 'wp/wp.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'netlog/netlog.ins.pas';
%include 'chksum/chksum.ins.pas';
%include 'disk/disk.ins.pas';
%include 'dbuf/dbuf.ins.pas';

{ TODO(pascal) the block's three gaps against its other objects

  Nothing addresses +0x0C..+0x0F, +0xA2..+0xA7 or +0xB02..+0xB07; each
  ends where 8-byte alignment from the block's start would put the next
  object (the ring, the second lock, the run array),
  but the volume table at +0xC4 (0x2D0 bytes) and the process slots at
  +0x394 (0x700 bytes) follow longwords with no such gap.  The stand-ins
  unused_0c, unused_a2, unused_a4, unused_b02 and unused_b04 hold the
  places; if the rule is found, they go. }

{ TODO(pascal) the unit's frames against their locals

  The SAU2 frames of disk_$get_qblks_internal, DISK_$INIT,
  disk_$io_error, disk_$wait_io, disk_$map_request,
  disk_$grow_qblk_pool, DISK_$WRITE_MULTI, DISK_$READ_MULTI,
  DISK_$FORMAT and DISK_IO hold more bytes than their declared locals
  explain in some places and fewer in others, so the frames do not
  settle which locals the original declared.  No stand-ins are declared.
  DISK_$ADD_QUE, DISK_$FORMAT_WHOLE and DISK_$ADD_QUE's two merges are
  explained exactly. }

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above). }
var
  disk_$ec: ec_$eventcount_t;                         { +0x000, zero }
  unused_0c: integer32;                               { +0x00C, zero }
  disk_$req_queue: array[1..64] of pinteger;          { +0x010, zero }
  disk_$exclusion: ml_$exclusion_t;                   { +0x090, zero }
  unused_a2: integer;                                 { +0x0A2, zero }
  unused_a4: integer32;                               { +0x0A4, zero }
  disk_$exclusion_2: ml_$exclusion_t;                 { +0x0A8, zero }
  disk_$reserve_block: disk_$io_req_ptr_t;            { +0x0BC, nil }
  disk_$free_head: disk_$io_req_ptr_t;                { +0x0C0, nil }

define
  disk_$dvtbl;                                        { +0x0C4, zero }
  disk_bptbl;                                         { +0x394, zero }
  disk_$error_info;                                   { +0xA94, zero }
  disk_$raw_ppn;                                      { +0xAEC, zero }

var
  disk_$pages_alloc: pinteger;                        { +0xAF0, zero }
  disk_$req_read_idx: pinteger := 1;                  { +0xAF2: 1 }
  disk_$req_write_idx: pinteger := 1;                 { +0xAF4: 1 }
  disk_$pending_count: integer;                       { +0xAF6, zero }

define
  disk_$nfblks;                                       { +0xAF8, zero }

var
  disk_$alloc_disabled: boolean;                      { +0xAFA, false }
  disk_$reserve_avail: boolean;                       { +0xAFC, false }

define
  disk_$diag;                                         { +0xAFE, false }
  disk_$do_chksum;                                    { +0xB00, false }

var
  unused_b02: integer;                                { +0xB02, zero }
  unused_b04: integer32;                              { +0xB04, zero }
  disk_$que_array: array[0..33] of disk_$io_req_ptr_t;  { +0xB08, nil }

define
  disk_$get_block;
  disk_$set_buff;
  disk_$invalidate;
  disk_$get_qblks;
  disk_$rtn_qblks;
  disk_$init;
  disk_$sort;
  disk_$init_que;
  disk_$add_que;
  disk_$wait_que;
  disk_$write;
  disk_$write_multi;
  disk_$read;
  disk_$read_multi;
  disk_$format_whole;
  disk_$format;
  disk_io;
  disk_$write_protect;

{ ---- .TEXT ---- }
%include 'disk/get_block.pas';              { DISK_$GET_BLOCK    }
%include 'disk/set_buff.pas';               { DISK_$SET_BUFF     }
%include 'disk/invalidate.pas';             { DISK_$INVALIDATE   }
%include 'disk/grow_qblk_pool.pas';         { disk_$grow_qblk_pool }
%include 'disk/get_qblks_internal.pas';     { disk_$get_qblks_internal }
%include 'disk/get_qblks.pas';              { DISK_$GET_QBLKS    }
%include 'disk/rtn_qblks_internal.pas';     { disk_$rtn_qblks_internal }
%include 'disk/rtn_qblks.pas';              { DISK_$RTN_QBLKS    }
%include 'disk/init.pas';                   { DISK_$INIT         }
%include 'disk/io_error.pas';               { disk_$io_error     }
%include 'disk/sort.pas';                   { DISK_$SORT, its nested
                                              disk_$sort_swap_entries }
%include 'disk/init_que.pas';               { DISK_$INIT_QUE     }
%include 'disk/add_que.pas';                { DISK_$ADD_QUE, its nested
                                              disk_$add_que_merge_
                                              ascending and _descending }
%include 'disk/wait_io.pas';                { disk_$wait_io      }
%include 'disk/wait_que.pas';               { DISK_$WAIT_QUE     }
%include 'disk/map_request.pas';            { disk_$map_request  }
%include 'disk/write.pas';                  { DISK_$WRITE        }
%include 'disk/set_chain_status.pas';       { disk_$set_chain_status }
%include 'disk/write_multi.pas';            { DISK_$WRITE_MULTI }
%include 'disk/read.pas';                   { DISK_$READ         }
%include 'disk/read_multi.pas';             { DISK_$READ_MULTI   }
%include 'disk/format_whole.pas';           { DISK_$FORMAT_WHOLE }
%include 'disk/format.pas';                 { DISK_$FORMAT       }
%include 'disk/io.pas';                     { DISK_IO            }
%include 'disk/write_protect.pas';          { DISK_$WRITE_PROTECT }
