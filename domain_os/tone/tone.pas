{ tone/tone.pas - the TONE module, the speaker tone.

  One compilation unit, one code segment, no data.  The map's TONE code
  segment (section WIRED_PROC, 0x64 bytes; the SAU9's 0xE8) holds
  TONE_$TIME's code and its three constant cells, which end on a
  longword boundary on the SAU2: no module-end filler (UID_$HASH
  follows); the SAU9's end with the filler word.  The module is the map
  segment's name, TONE.  SUB48 (cal/cal.ins.pas) serves the
  `kbd_tone' form.

  TONE_$ENABLE, the other tone routine, is not part of this module: the
  map has it in the OS_TERM_INIT code segment, and term/os_term_init.pas
  includes its fragment (tone/enable.pas).

  The heading names no section: the module has no data (no TONE block in
  any data section), and TONE_$TIME, in WIRED_PROC, is headed
  `[section(wired_proc, wired_data)]' (the rules, "Choosing a module's
  sections": TTY's WIRED_PROC routines).
  ../domain-pascal/tests/conformance/tone_time.pas has `module tone;' and
  no attribute, its section placed by the conformance manifest.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/tone/tone.pas.  Check: tools/pascal_check.sh.
}
module tone;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'cal/cal.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'tone/tone.ins.pas';

{ The global routine this module defines (ref 7.3.4, Method 2). }
define
  tone_$time;

{ ---- WIRED_PROC ---- }
%include 'tone/time.pas';                   { TONE_$TIME }
