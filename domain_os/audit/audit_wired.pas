{ audit/audit_wired.pas - the AUDIT_WIRED module, AUDIT's two wired flags.

  Image addresses:
    sau2  0x00E2E09C  AUDIT_WIRED data (WIRED_DATA, 0x4 bytes)

  A map module of data only: the map's AUDIT_WIRED data segment in
  WIRED_DATA (4 bytes, map symbols AUDIT_$CORRUPTED and AUDIT_$ENABLED),
  after the AUDIT module's own WIRED_DATA block and before
  NET_PORT_TABLE.

  Its two objects are booleans (audit/audit.ins.pas), a byte each at the
  high byte of a word, zero in the image.  Every routine names them by
  their absolute address, never through A5: they are globals this unit
  defines, as hint/hint_wired.pas's.

  The heading: `module audit_wired, , wired_data;' (ref 2.2.1 p. 2-10's
  `name, , data_section' form, as hint/hint_wired.pas).

  Check: tools/pascal_check.sh.
}
module audit_wired, , wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'acl/acl.ins.pas';
%include 'audit/audit.ins.pas';

define
  audit_$corrupted;                                { +0x00, zero }
  audit_$enabled;                                  { +0x02, zero }
