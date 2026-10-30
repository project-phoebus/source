{ suma/suma.pas - the BITPAD module, the Summagraphics bitpad driver.

  Image addresses:
    sau2  0x00E2DD88  BITPAD data (WIRED_DATA, 0x2C bytes)

  One compilation unit, in two code sections and one data section: the
  map's BITPAD code segments in WIRED_PROC (0x1B8 bytes, SUMA_$RCV) and
  in OS_INIT_PROC (0x28 bytes, SUMA_$INIT), and its BITPAD data segment
  in WIRED_DATA (0x2C bytes), with no map symbol inside it.

  The module name: the map names the three segments BITPAD, the
  compilation unit's module name (as LOG_, KBD, TPAD, TTY and
  DXM_WIRED_ show), so the module is `bitpad', whatever its routines'
  prefix.  The directory, suma/, is kept for the files.

  The data, 0x2C bytes, all zero in the image:

    +0x00  suma_$last_time    4     the last complete packet's time
    +0x04  suma_$prev         0x10  the previous sample
    +0x14  suma_$cur          0x10  the sample being assembled

    +0x24  suma_$tpad_buffer  4     addr(term_$tpad_buffer), the datum
                                    of the deferred TERM_$ENQUEUE_TPAD
    +0x28  suma_$rcv_state    2     the next byte's position, 0..4
    +0x2A  suma_$threshold    2     the movement threshold

  These are module-level variables (the LOG, KBD and TPAD model), used
  by both routines, so the heading names wired_proc and wired_data;
  SUMA_$INIT, in OS_INIT_PROC, is headed `[section(os_init_proc,
  os_init_data)]' (ref 5.7.1) and reaches the block by its address.

  The block is six variables, not one record, as TPAD's globals became its
  scalars (tpad/tpad.pas): no routine treats the 0x2C bytes as one
  object.

  The routines live in one fragment file each, included below in image
  order.

  Build: dpc -I domain_os domain_os/suma/suma.pas.  Check:
  tools/pascal_check.sh.
}
module bitpad, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'time/time.ins.pas';
%include 'dxm/dxm.ins.pas';
%include 'smd/smd.ins.pas';
%include 'suma/suma.ins.pas';
%include 'term/term.ins.pas';
%include 'kbd/kbd.ins.pas';

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  suma_$rcv;
  suma_$init;

{ The module's variables, in the order of the block, all zero in the
  image (uninitialized, as LOG_'s block, log/log.pas). }
var
  suma_$last_time: integer32;             { +0x00 }
  suma_$prev: suma_sample_t;              { +0x04: the previous sample }
  suma_$cur: suma_sample_t;               { +0x14: the sample being
                                            assembled }
  suma_$tpad_buffer: tpad_buffer_ptr_t;   { +0x24 }
  suma_$rcv_state: integer;               { +0x28: the next byte's
                                            position in the packet, 0..4 }
  suma_$threshold: pinteger;              { +0x2A }

{ ---- WIRED_PROC ---- }
%include 'suma/rcv.pas';                    { SUMA_$RCV          }

{ ---- OS_INIT_PROC ---- }
%include 'suma/init.pas';                   { SUMA_$INIT         }
