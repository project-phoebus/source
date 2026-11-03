{ TERM_$INIT - set up the terminal lines.

  Image addresses:
    sau2  0x00E32EBA  TERM_$INIT
    sau3  0x00E315A4  TERM_$INIT
    sau4  0x0F836060  TERM_$INIT
    sau8  0x03C3685C  TERM_$INIT
    sau9  0x3C43986C  TERM_$INIT

  - The console line (the SIO6509 path) and the two SIO2681 serial
    lines are built from OS_TERM_INIT's records, the SIO6509 channel and
    the SIO2681 chip initialized.
  - Without `display_driver' there is no console line: the serial
    lines are DTTE 1 and 2 with the first two TTY and SIO descriptors,
    and the SIO6509 channel is not initialized (its vtable and
    configuration stay among the statics).
  - In mode 1 the caller's line gets all-ones baud rates and the ESC
    crash function.  TERM_$MAX_DTTE becomes 3 and the tablet is started
    (SUMA_$INIT).
  - Its statics, the drivers' vtables and configurations, are the map's
    OS_TERM_INIT OS_INIT_DATA segment (92 bytes).
  - With `console_sio2681' the console line and one serial line are the
    SIO2681's channels A and B, both with the serial driver's vtable;
    the chip gets its configuration from the fifth word; channel A's
    flags are set and it is recorded as the console's channel;
    TERM_$MAX_DTTE becomes 2.
  - With `sio2681_four_lines' the console and three serial lines are two
    SIO2681s' channels, each chip set up after its two lines.
  - Then only line 1 or 2 gets the all-ones baud rates in mode 1;
    TERM_$MAX_DTTE becomes 4.
  - With `sio16550_lines' the serial driver sets the lines up (SIO_$INIT
    for each of its ports), and TERM_$INIT only starts the tablet; its
    parameters are not read.

  Status stored: none.
}

{ TODO(pascal) TERM_$INIT's frame has 16 bytes no object accounts for

  In the SAU2 image the locals addressed and the two temporaries leave
  16 bytes, less the `for' index's slot, that no instruction reaches:
  the stand-in unused_30 below.  More pointer locals of the same kind
  (the four lines' records, built the same way) are the lead. }

[section(os_init_proc, os_init_data)]
procedure term_$init(in mode: integer; in line: integer);
%if console_sio2681 %then
var
  serial_vtable: static term_$serial_vtable_t :=
    [nil, nil, nil, nil, nil, addr(sio2681_$xmit), addr(sio2681_$set_line),
     addr(sio2681_$inq_line), addr(sio2681_$set_break)];  { +0x00 }
  sio2681_config: static sio2681_$config_t :=
    [-16#7100, -16#900, -16#7100, 0, -16#1600, -16#900, -16#7100];
                                                          { +0x24 }
  minus_one: integer32;
  drain_p: univ_ptr;
  tty_p: univ_ptr;
  kbd_p: univ_ptr;
  sio_p: sio_$desc_ptr_t;
  dtte_p: dtte_ptr_t;
  sio2_p: univ_ptr;
  sio3_p: univ_ptr;
  i: integer;
  unused_30: array[1..3] of integer32;    { see the TODO }
begin
  minus_one := -1;

  { no line has a descriptor yet }
  for i := 0 to 3 do begin
    dtte[i].handler_ptr := nil;
    dtte[i].alt_handler := nil;
    dtte[i].tty_handler := nil;
    dtte[i].ptr_30 := nil;
  end;

  { ---- the console line, channel A ---- }

  { its keyboard descriptor }
  sio_p := addr(sio_descs[1]);
  drain_p := addr(term_$console_drain[1]);
  dtte_p := addr(dtte[0]);
  tty_p := addr(tty_descs[1]);
  os_term_init(kbd_descs[1], dtte_p^, tty_p, term_$kbd_rcv, sio_p,
               term_$kbd_handlers);

  { its TTY descriptor }
  sio_$init_line(tty_descs[1], dtte_p^, drain_p, term_$console_line_handlers);

  { its output drain record }
  tty_p := addr(tty_descs[1]);
  sio_$init_drain_handler(term_$console_drain[1], dtte_p^,
                          addr(tty_descs[1].output), tty_p);

  { its SIO descriptor }
  kbd_p := addr(kbd_descs[1]);
  sio_$init_desc(sio_p^, term_$console_params, dtte_p^, kbd_p,
                 addr(kbd_descs[1].txbuf), term_$console_handlers,
                 addr(tone_$channel), serial_vtable);

  sio_$init_dtte(dtte_p^, 2);

  { ---- the serial line, channel B ---- }

  dtte_p := addr(dtte[1]);
  sio_p := addr(sio_descs[2]);
  sio_$init_line(tty_descs[2], dtte_p^, sio_p, term_$serial_line_handlers);

  tty_p := addr(tty_descs[2]);
  sio_$init_desc(sio_p^, term_$serial_params, dtte_p^, tty_p,
                 addr(tty_descs[2].output), term_$tty_handlers,
                 addr(term_$serial_chan_b), serial_vtable);
  sio_$init_dtte(dtte_p^, 0);

  { the caller's line's baud rates }
  if mode = 1 then
    sio_descs[line + 1].params.baud_rate := sio_$rates_t(minus_one);

  { the serial chip and its two channels }
  sio3_p := addr(sio_descs[2]);
  sio2_p := addr(sio_descs[1]);
  sio2681_$init(1, 1, tone_$channel, sio2_p, sio_descs[1].params,
                term_$serial_chan_b, sio3_p, sio_descs[2].params,
                term_$sio2681_chip, sio2681_config[5]);

  { channel A's flags, and the console's channel for KBD_$RESET }
  tone_$channel.reserved_14 := [1, 2];
  term_$console_chan_ptr := addr(tone_$channel);

  { the crash key on the caller's line }
  if mode = 1 then
    tty_$i_enable_crash_func(tty_$desc_ptr_t(dtte[line].handler_ptr)^,
                             chr(16#1B), true);

  term_$max_dtte := 2;
  suma_$init;
end;
%elseif sio2681_four_lines %then
var
  serial_vtable: static term_$serial_vtable_t :=
    [nil, nil, nil, nil, nil, addr(sio2681_$xmit), addr(sio2681_$set_line),
     addr(sio2681_$inq_line), addr(sio2681_$set_break)];  { +0x00 }
  sio2681_config: static sio2681_$config_t :=
    [-16#7100, -16#900, -16#7100, 0, -16#7100, -16#900, -16#7100];
                                                          { +0x24 }
  minus_one: integer32;
  drain_p: univ_ptr;
  tty_p: univ_ptr;
  kbd_p: univ_ptr;
  sio_p: sio_$desc_ptr_t;
  dtte_p: dtte_ptr_t;
  sio2_p: univ_ptr;
  sio3_p: univ_ptr;
  i: integer;
  unused_2a: array[1..4] of integer;      { see the TODO }
  int_vec_1: integer;                     { the second chip's }
  int_vec_2: integer;                     { the first chip's }
begin
  minus_one := -1;

  { no line has a descriptor yet }
  for i := 0 to 3 do begin
    dtte[i].handler_ptr := nil;
    dtte[i].alt_handler := nil;
    dtte[i].tty_handler := nil;
    dtte[i].ptr_30 := nil;
  end;
  int_vec_2 := 2;
  int_vec_1 := 1;

  { ---- the console line, the first chip's channel A ---- }

  { its keyboard descriptor }
  sio_p := addr(sio_descs[1]);
  drain_p := addr(term_$console_drain[1]);
  dtte_p := addr(dtte[0]);
  tty_p := addr(tty_descs[1]);
  os_term_init(kbd_descs[1], dtte_p^, tty_p, term_$kbd_rcv, sio_p,
               term_$kbd_handlers);

  { its TTY descriptor }
  sio_$init_line(tty_descs[1], dtte_p^, drain_p, term_$console_line_handlers);

  { its output drain record }
  tty_p := addr(tty_descs[1]);
  sio_$init_drain_handler(term_$console_drain[1], dtte_p^,
                          addr(tty_descs[1].output), tty_p);

  { its SIO descriptor }
  kbd_p := addr(kbd_descs[1]);
  sio_$init_desc(sio_p^, term_$console_params, dtte_p^, kbd_p,
                 addr(kbd_descs[1].txbuf), term_$console_handlers,
                 addr(tone_$channel), serial_vtable);

  sio_$init_dtte(dtte_p^, 2);

  { ---- the first serial line, the first chip's channel B ---- }

  dtte_p := addr(dtte[1]);
  sio_p := addr(sio_descs[2]);
  sio_$init_line(tty_descs[2], dtte_p^, sio_p, term_$serial_line_handlers);

  tty_p := addr(tty_descs[2]);
  sio_$init_desc(sio_p^, term_$serial_params, dtte_p^, tty_p,
                 addr(tty_descs[2].output), term_$tty_handlers,
                 addr(term_$serial_chan_b), serial_vtable);
  sio_$init_dtte(dtte_p^, 0);

  { the caller's line's baud rates, if it is this one }
  if (mode = 1) and then (line = 1) then
    sio_descs[line + 1].params.baud_rate := sio_$rates_t(minus_one);

  { the first chip and its two channels }
  sio3_p := addr(sio_descs[2]);
  sio2_p := addr(sio_descs[1]);
  sio2681_$init(int_vec_2, 1, tone_$channel, sio2_p, sio_descs[1].params,
                term_$serial_chan_b, sio3_p, sio_descs[2].params,
                term_$sio2681_chip, sio2681_config[5]);

  { channel A's flags }
  tone_$channel.reserved_14 := [1, 2];

  { ---- the second serial line, the second chip's channel A ---- }

  dtte_p := addr(dtte[2]);
  sio_p := addr(sio_descs[3]);
  sio_$init_line(tty_descs[3], dtte_p^, sio_p, term_$serial_line_handlers);

  tty_p := addr(tty_descs[3]);
  sio_$init_desc(sio_p^, term_$serial_params, dtte_p^, tty_p,
                 addr(tty_descs[3].output), term_$tty_handlers,
                 addr(term_$serial_chan_a2), serial_vtable);
  sio_$init_dtte(dtte_p^, 0);

  { ---- the third serial line, the second chip's channel B ---- }

  dtte_p := addr(dtte[3]);
  sio_p := addr(sio_descs[4]);
  sio_$init_line(tty_descs[4], dtte_p^, sio_p, term_$serial_line_handlers);

  tty_p := addr(tty_descs[4]);
  sio_$init_desc(sio_p^, term_$serial_params, dtte_p^, tty_p,
                 addr(tty_descs[4].output), term_$tty_handlers,
                 addr(term_$serial_chan_b2), serial_vtable);
  sio_$init_dtte(dtte_p^, 0);

  { the caller's line's baud rates, if it is the second }
  if (mode = 1) and then (line = 2) then
    sio_descs[line + 1].params.baud_rate := sio_$rates_t(minus_one);

  { the second chip and its two channels }
  sio3_p := addr(sio_descs[4]);
  sio2_p := addr(sio_descs[3]);
  sio2681_$init(int_vec_1, 2, term_$serial_chan_a2, sio2_p,
                sio_descs[3].params, term_$serial_chan_b2, sio3_p,
                sio_descs[4].params, term_$sio2681_chip_2, sio2681_config);

  { the crash key on the caller's line }
  if mode = 1 then
    tty_$i_enable_crash_func(tty_$desc_ptr_t(dtte[line].handler_ptr)^,
                             chr(16#1B), true);

  term_$max_dtte := 4;
  suma_$init;
end;
%else
%if not sio16550_lines %then
const
  { the TTY and SIO descriptors of DTTE 1, the first serial line: after
    the console's, when there is one }
%if display_driver %then
  first_serial = 2;
%else
  first_serial = 1;
%endif
var
  console_vtable: static term_$vtable_t :=
    [nil, nil, nil, nil, nil, addr(sio6509_$xmit), addr(sio6509_$set_line),
     addr(sio6509_$inq_line), nil, nil];                  { +0x00 }
  serial_vtable: static term_$serial_vtable_t :=
    [nil, nil, nil, nil, nil, addr(sio2681_$xmit), addr(sio2681_$set_line),
     addr(sio2681_$inq_line), addr(sio2681_$set_break)];  { +0x28 }
  sio2681_config: static sio2681_$config_t :=
    [-16#7100, -16#900, -16#7100, 0, -16#7100, -16#900, -16#7100];
                                                          { +0x4C }
  sio6509_config: static sio6509_$config_t := [chr(3), chr(16#D9)];
                                                          { +0x5A }
  minus_one: integer32;
  drain_p: univ_ptr;
  tty_p: univ_ptr;
  kbd_p: univ_ptr;
  sio_p: sio_$desc_ptr_t;
  dtte_p: dtte_ptr_t;
  sio2_p: univ_ptr;
  sio3_p: univ_ptr;
  i: integer;
  unused_30: array[1..3] of integer32;    { see the TODO }
%endif
begin
%if not sio16550_lines %then
  minus_one := -1;

  { no line has a descriptor yet }
  for i := 0 to 3 do begin
    dtte[i].handler_ptr := nil;
    dtte[i].alt_handler := nil;
    dtte[i].tty_handler := nil;
    dtte[i].ptr_30 := nil;
  end;

%if display_driver %then
  { ---- the console line ---- }

  { its keyboard descriptor }
  sio_p := addr(sio_descs[1]);
  drain_p := addr(term_$console_drain[1]);
  dtte_p := addr(dtte[0]);
  tty_p := addr(tty_descs[1]);
  os_term_init(kbd_descs[1], dtte_p^, tty_p, term_$kbd_rcv, sio_p,
               term_$kbd_handlers);

  { its TTY descriptor }
  sio_$init_line(tty_descs[1], dtte_p^, drain_p, term_$console_line_handlers);

  { its output drain record }
  tty_p := addr(tty_descs[1]);
  sio_$init_drain_handler(term_$console_drain[1], dtte_p^,
                          addr(tty_descs[1].output), tty_p);

  { its SIO descriptor }
  kbd_p := addr(kbd_descs[1]);
  sio_$init_desc(sio_p^, term_$console_params, dtte_p^, kbd_p,
                 addr(kbd_descs[1].txbuf), term_$console_handlers,
                 addr(term_$console_chan), console_vtable);

  sio_$init_dtte(dtte_p^, 2);
  sio6509_$init(1, 2, term_$console_chan, sio_p, sio6509_config);
%endif

  { ---- the first serial line ---- }

  dtte_p := addr(dtte[1]);
  sio_p := addr(sio_descs[first_serial]);
  sio_$init_line(tty_descs[first_serial], dtte_p^, sio_p,
                 term_$serial_line_handlers);

  tty_p := addr(tty_descs[first_serial]);
  sio_$init_desc(sio_p^, term_$serial_params, dtte_p^, tty_p,
                 addr(tty_descs[first_serial].output), term_$tty_handlers,
                 addr(tone_$channel), serial_vtable);
  sio_$init_dtte(dtte_p^, 0);

  { ---- the second serial line ---- }

  dtte_p := addr(dtte[2]);
  sio_p := addr(sio_descs[first_serial + 1]);
  sio_$init_line(tty_descs[first_serial + 1], dtte_p^, sio_p,
                 term_$serial_line_handlers);

  tty_p := addr(tty_descs[first_serial + 1]);
  sio_$init_desc(sio_p^, term_$serial_params, dtte_p^, tty_p,
                 addr(tty_descs[first_serial + 1].output), term_$tty_handlers,
                 addr(term_$serial_chan_b), serial_vtable);
  sio_$init_dtte(dtte_p^, 0);

  { the caller's line's baud rates }
  if mode = 1 then
    sio_descs[line + 1].params.baud_rate := sio_$rates_t(minus_one);

  { the serial chip and its two channels }
  sio3_p := addr(sio_descs[first_serial + 1]);
  sio2_p := addr(sio_descs[first_serial]);
  sio2681_$init(1, 1, tone_$channel, sio2_p, sio_descs[first_serial].params,
                term_$serial_chan_b, sio3_p,
                sio_descs[first_serial + 1].params,
                term_$sio2681_chip, sio2681_config);

  { the crash key on the caller's line }
  if mode = 1 then
    tty_$i_enable_crash_func(tty_$desc_ptr_t(dtte[line].handler_ptr)^,
                             chr(16#1B), true);

  term_$max_dtte := 3;
%endif
  suma_$init;
end;
%endif
