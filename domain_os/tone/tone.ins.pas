{ tone/tone.ins.pas - TONE_ (the speaker tone) routine headings, for the
  Domain Pascal tree.

  TONE_$TIME is the TONE module (tone/tone.pas); TONE_$ENABLE is a
  routine of the OS_TERM_INIT module (tone/enable.pas,
  tone/README.md).  Apollo's customer insert files of SR10.2
  declare neither.  Include base/base.ins.pas before it.
}

{ TONE_$TIME - sound the speaker for a time. }
procedure tone_$time(duration: time_$clock_t); extern;

{ TONE_$ENABLE - turn the speaker tone on or off. }
procedure tone_$enable(in enable: boolean); extern;
