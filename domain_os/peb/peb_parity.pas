{ peb/peb_parity.pas - the PEB_PARITY module, the board's parity test and
  its global block.

  Image addresses:
    sau2  0x00E24C78  PEB_PARITY data (WIRED_DATA, 0x24 bytes)
    sau9  0x3C428478  PEB_PARITY data (WIRED_DATA, 0x24 bytes)

  One compilation unit: the map's PEB_PARITY code segment in WIRED_PROC
  (0x38 bytes: PEB_$TEST_PARITY_ERR) and its data segment in WIRED_DATA
  (0x24 bytes: PEB_$INFO).  The heading: `module peb_parity,
  wired_proc, wired_data;' (MAC_OS's shape, mac_os/mac_os.pas).
  Without `peb_board' (base/config.ins.pas) the map has the data
  segment only.

  The data, 0x24 bytes, zero in the image: PEB_$INFO, a peb_$info_t of
  0x22 bytes (peb/peb.ins.pas, its layout), the block rounded to 4.

  Build: dpc -I domain_os domain_os/peb/peb_parity.pas.  Check:
  tools/pascal_check.sh.
}
module peb_parity, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'fim/fim.ins.pas';
%include 'peb/peb.ins.pas';

{ The module's one variable, the map symbol PEB_$INFO (+0x00, zero). }
define
  peb_$info;

%if peb_board %then
define
  peb_$test_parity_err;

{ ---- WIRED_PROC ---- }
%include 'peb/test_parity_err.pas';         { PEB_$TEST_PARITY_ERR }
%endif
