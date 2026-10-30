{ ec/ec2.pas - the EC2 module, the level-2 eventcounts.

  Image addresses:
    sau2  0x00E7C06C  EC2 data (.DATA, 0xEA0 bytes)

  One compilation unit, in two code sections and one data section: the
  map's EC2 code segments in .TEXT (0x908 bytes: EC2_$WAIT, _$WAKEUP,
  _$REGISTER_EC1, _$ALLOCATE_EC1, _$GET_EC1_ADDR, _$RELEASE_EC1,
  _$GET_VAL) and in OS_INIT_PROC (0x84 bytes, EC2_$INIT_S), and its EC2
  data segment in .DATA (0xEA0 bytes).

  The other EC_ and EC2 objects are other modules': EC2U (ec/ec2u.pas),
  EC2_PBU (pbu/ec2_pbu.pas), EC2_ASM (hand-written data, EC2_$WAIT_ECS,
  ec/ec.ins.pas), and the level-1 routines in PROC1_ (ec/init.pas,
  ec/read.pas) and PROC1_ASM (hand assembly, ec/m68k/*.s).

  The heading: the block's objects are module variables, in the default
  code and data sections, so `module ec2;'; EC2_$INIT_S is headed
  `[section(os_init_proc, os_init_data)]' and reaches the block by its
  address.

  The data, 0xEA0 bytes, zero in the image:

    +0x000  ec2_waiter_table_base  225 * 0xC  the waiter records
    +0xA8C  ec2_$registered_ec1s  257 * 4  the registered level-1
                                     eventcounts
    +0xE90  ec2_$pbu_pending      4  the PBU eventcounts released while
                                     waited on

    +0xE94  ec2_$pbu_allocated    4  the PBU eventcounts handed out
    +0xE98  ec2_$max_registered   4  the highest registered number
    +0xE9C  ec2_$free_head        2  the waiter free list
    +0xE9E  (2 bytes: the block's rounding to 4)

  The sets: member k is bit k of the longword (ref 3.9.3), one bit per
  pool slot.

  The routines live in one fragment file each (ec/ec2_<name>.pas),
  included below in image order.

  Build: dpc -I domain_os domain_os/ec/ec2.pas.  Check:
  tools/pascal_check.sh.
}
module ec2;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'fim/fim.ins.pas';
%include 'as/as.ins.pas';
%include 'pbu/pbu.ins.pas';

type
  { A waiter record, 12 bytes. }
  ec2_waiter_t = record
    wait_val: integer32;                  { 0x00 }
    next: pinteger;                       { 0x04 }
    prev: pinteger;                       { 0x06 }
    proc_id: pinteger;                    { 0x08 }
    pad: integer;                         { 0x0A }
  end;

{ The module's own variables (ref 7.2.2), in the order of the block
  (above); none is a map symbol. }
var
  ec2_waiter_table_base: array[0..224] of ec2_waiter_t;  { +0x000, zero }
  ec2_$registered_ec1s: array[0..256] of ec_$eventcount_ptr_t;
                                                   { +0xA8C, zero }
  ec2_$pbu_pending: set of 0..31;                  { +0xE90, zero }
  ec2_$pbu_allocated: set of 0..31;                { +0xE94, zero }
  ec2_$max_registered: linteger;                   { +0xE98, zero }
  ec2_$free_head: pinteger;                        { +0xE9C, zero }

define
  ec2_$wait;
  ec2_$wakeup;
  ec2_$register_ec1;
  ec2_$allocate_ec1;
  ec2_$get_ec1_addr;
  ec2_$release_ec1;
  ec2_$get_val;
  ec2_$init_s;

{ ---- .TEXT ---- }
%include 'ec/ec2_wait.pas';                 { EC2_$WAIT          }
%include 'ec/ec2_wakeup.pas';               { EC2_$WAKEUP        }
%include 'ec/ec2_register_ec1.pas';         { EC2_$REGISTER_EC1  }
%include 'ec/ec2_allocate_ec1.pas';         { EC2_$ALLOCATE_EC1  }
%include 'ec/ec2_get_ec1_addr.pas';         { EC2_$GET_EC1_ADDR  }
%include 'ec/ec2_release_ec1.pas';          { EC2_$RELEASE_EC1   }
%include 'ec/ec2_get_val.pas';              { EC2_$GET_VAL       }

{ ---- OS_INIT_PROC ---- }
%include 'ec/ec2_init_s.pas';               { EC2_$INIT_S        }
