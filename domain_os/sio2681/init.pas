{ SIO2681_$INIT - set up a 2681 and its two channels.

  Image addresses:
    sau2  0x00E333DC  SIO2681_$INIT
    sau3  0x00E3192C  SIO2681_$INIT
    sau4  0x0F836684  SIO2681_$INIT
    sau6  0x7803C8FC  SIO2681_$INIT
    sau7  0x3C43C928  SIO2681_$INIT
    sau8  0x03C36C68  SIO2681_$INIT

  - The chip and both channels (A on the block's first half, B on its
    second; each the other's peer) are recorded in the chip's
    SIO2681_$PTRS entry.
  - The channels' receivers and transmitters are enabled and both lines'
    parameters set.
  - The chip's interrupt stub is installed in the vector int_vec; the
    static int_vectors (OS_INIT_DATA's SIO_IO block) holds the two
    stubs' addresses.
  - With `sio2681_pbu_int' the chip's interrupt is then acquired as PBU
    unit 1, the stub's cell its handler, the chip's registers its CSR;
    the acquisition's status is not looked at.
  - With `sio2681_chip_2_pbu_8' the second chip's registers are 16#100
    bytes after the first's, and a chip given vector 2 has its stub in
    SIO_VEC2 and its interrupt acquired as PBU unit 8.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure sio2681_$init(in int_vec: integer; in chip_num: integer;
                        var chan_a: sio2681_$channel_t;
                        in chan_a_callback: univ_ptr;
                        in chan_a_params: sio_$params_t;
                        var chan_b: sio2681_$channel_t;
                        in chan_b_callback: univ_ptr;
                        in chan_b_params: sio_$params_t;
                        var chip: sio2681_$chip_t;
                        in config: univ sio2681_$config_t);
var
  int_vectors: static array[1..sio2681_max_chips] of univ_ptr :=
    [addr(sio2681_$int1_rte),
     addr(sio2681_$int2_rte)];
  line_status: status_$t;
  unused_8: integer32;                    { stand-in }
begin
  { the chip }
%if sio2681_chip_2_pbu_8 %then
  chip.regs := sio2681_$regs_ptr_t(integer32(addr(sio[chip_num]))
                                   + (chip_num - 1) * 224);
%else
  chip.regs := addr(sio[chip_num]);
%endif
  chip.config1.w := config[1];
  chip.config2.w := config[3];
  chip.imr_shadow.s := [1, 5, 7];
  chip.regs^.isr_imr := chr(0);

  { channel A }
  sio2681_$ptrs[chip_num].chip := addr(chip);
  sio2681_$ptrs[chip_num].chan_a := addr(chan_a);
  chan_a.regs := chip.regs;
  chan_a.sio_desc := chan_a_callback;
  chan_a.chan_flags := [1];
  chan_a.int_bit := 0;
  chan_a.peer := addr(chan_b);
  chan_a.chip := addr(chip);
  chan_a.flags := 0;
  chan_a.reserved_14 := [];
  chan_a.baud_support := 0;
  chan_a.regs^.cra := chr(5);

  { channel B }
  sio2681_$ptrs[chip_num].chan_b := addr(chan_b);
  chan_b.regs := addr(chip.regs^.unused_10);
  chan_b.sio_desc := chan_b_callback;
  chan_b.chan_flags := [];
  chan_b.int_bit := 4;
  chan_b.peer := addr(chan_a);
  chan_b.chip := addr(chip);
  chan_b.flags := 0;
  chan_b.reserved_14 := [];
  chan_b.baud_support := 0;
  chan_b.regs^.cra := chr(5);

  sio2681_$set_line(chan_a, chan_a_params, [0..13], line_status);
  sio2681_$set_line(chan_b, chan_b_params, [0..13], line_status);

%if sio2681_chip_2_pbu_8 %then
  if int_vec > 1 then begin
    sio_vec2[int_vec] := int_vectors[chip_num];
    pbu_$acquire_int(8, addr(int_vectors[chip_num]), nil, chip.regs, -1,
                     1, -1, line_status);
  end
  else begin
    sio_vec[int_vec] := int_vectors[chip_num];
    pbu_$acquire_int(1, addr(int_vectors[chip_num]), nil, chip.regs, -1,
                     1, -1, line_status);
  end;
%else
  sio_vec[int_vec] := int_vectors[chip_num];
%if sio2681_pbu_int %then
  pbu_$acquire_int(1, addr(int_vectors[chip_num]), nil, chip.regs, -1, 1,
                   -1, line_status);
%endif
%endif
  chip.regs^.isr_imr := chip.imr_shadow.c;
end;
