{ pbu/ec2_pbu.pas - the EC2_PBU module, the PBU eventcount pool.

  Image addresses:
    sau2  0x00E88460  EC2_PBU data (PBU_WIRED_DATA, 0x300 bytes)

  One compilation unit, one code segment and one data segment, each in a
  section of its own: the map's EC2_PBU code segment in PBU_WIRED_PROC
  (0x60 bytes, PBU_$ADVANCE_EC_INT) and its EC2_PBU data segment in
  PBU_WIRED_DATA (0x300 bytes, EC2_$PBU_ECS; PBU_$DATA_END one past the
  block).

  The module name is the map segments', EC2_PBU, though its routine is
  PBU_$'s: a module file of its own.  The map's PBU_PAGE is an empty
  section at the same address.

  The data, 0x300 bytes, zero in the image: EC2_$PBU_ECS, 32 records of
  0x18 bytes (pbu/pbu.ins.pas), a map symbol, so the module's defined
  variable (ref 7.2.2, Method 2).  PBU_$DATA_END is a marker.  The
  heading names the two sections.

  Build: dpc -I domain_os domain_os/pbu/ec2_pbu.pas.  Check:
  tools/pascal_check.sh.
}
module ec2_pbu, pbu_wired_proc, pbu_wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'pbu/pbu.ins.pas';

{ The global routine and variable this module defines (ref 7.3.4 and
  7.2.2, Method 2), in map order.  EC2_$PBU_ECS is uninitialized, zero in
  the image. }
define
  pbu_$advance_ec_int;
  ec2_$pbu_ecs;

{ ---- PBU_WIRED_PROC ---- }
%include 'pbu/advance_ec_int.pas';          { PBU_$ADVANCE_EC_INT }
