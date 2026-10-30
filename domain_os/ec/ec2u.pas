{ ec/ec2u.pas - the EC2U module, the level-2 eventcounts' user entries.

  One compilation unit, one code segment, no data: the map's EC2U code
  segment in .TEXT (0x8C bytes: EC2_$INIT, EC2_$READ, EC2_$ADVANCE),
  `module ec2u;' with no sections named.  The three routines are
  Apollo's user interface (customer ec2.ins.pas: the same three names,
  headings and parameter names; ec/ec.ins.pas).

  The routines live in one fragment file each (ec/ec2_<name>.pas),
  included below in image order.  EC2_$READ calls EC2_$GET_VAL and
  EC2_$ADVANCE calls EC2_$WAKEUP, both EC2's (extern headings in
  ec/ec.ins.pas).

  Build: dpc -I domain_os domain_os/ec/ec2u.pas.  Check:
  tools/pascal_check.sh.
}
module ec2u;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';

define
  ec2_$init;
  ec2_$read;
  ec2_$advance;

{ ---- .TEXT ---- }
%include 'ec/ec2_init.pas';                 { EC2_$INIT          }
%include 'ec/ec2_read.pas';                 { EC2_$READ          }
%include 'ec/ec2_advance.pas';              { EC2_$ADVANCE       }
