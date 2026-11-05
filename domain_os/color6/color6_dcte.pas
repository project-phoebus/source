{ color6/color6_dcte.pas - the COLOR6_DCTE module, the COLOR6 units'
  descriptors, and the driver's wired data.

  Image addresses:
    sau7  0x3C435A6C  COLOR6_DCTE data (WIRED_DATA, 0xC0 bytes)
    sau7  0x3C4BA488  COLOR6_$WIRED_DATA overlay (0x1A0 bytes)
    sau7  0x3C4BA628  COLOR6_END_DATA overlay (0x4 bytes)

  A map module of data only, `module color6_dcte, , wired_data;': the
  map's COLOR6_DCTE segment in WIRED_DATA, after COLOR6's own block, with
  the three units' DCTEs, COLOR6_$UNIT_1, COLOR6_$UNIT_2 and
  COLOR6_$UNIT_3, which io/dctes.pas's DEV_DCTES lists.  And the contents
  of the overlay section COLOR6_$WIRED_DATA (the map's load section, no
  module segment in it; ref 3.14), which the DCTEs point into: the
  driver's areas, the routine vector, the units' state and the board's
  I/O map requests; and the overlay section COLOR6_END_DATA after it, 4
  zero bytes, the end of the driver's data area.

  The three units are pages of one board (their controller numbers 5,
  3 and 6, color6_set_page), and share the vector and the requests: the
  display memory's, then the CSR page's, the two control pages' and the
  command FIFO's, in the order of the list each request's first longword
  links.  The requests' addresses are the I/O definitions' pages (the
  map's IODEFS symbols): DISP1_MEM, DISP1, DISP_MATROX_CTL1,
  DISP_MATROX_CTL2 and DISP_MATROX_FIFO, on the AT bus (bus 3).

  With the part color6_driver (base/config.ins.pas), empty elsewhere.

  Check: tools/pascal_check.sh (which finds this file by its module
  heading).
}
module color6_dcte, , wired_data;

%include 'base/base.ins.pas';
%if color6_driver %then
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'io/io.ins.pas';
%include 'smd/smd.ins.pas';
%include 'color6/color6.ins.pas';

type
  { A request as the image holds it: io_$acquire_rec_t with its link and
    the pages' address as pointers (dpc takes `addr' for a univ_ptr
    cell), and the pad word that makes it 0x20 bytes
    (color4/color4_dcte.pas's form). }
  color6_req_csr_t = record
    va: univ_ptr;                         { 0x00 }
    pa: linteger;                         { 0x04 }
    pages: integer;                       { 0x08 }
    has_csr: boolean;                     { 0x0A }
    unused_0b: char;                      { 0x0B }
  end;
  color6_req_t = record
    next: univ_ptr;                       { 0x00 }
    int: io_$int_info_t;                  { 0x04 }
    csr: color6_req_csr_t;                { 0x0C }
    tag: integer;                         { 0x18 }
    bus: integer;                         { 0x1A }
    attrs: io_$attr_t;                    { 0x1C }
    unused_1e: integer;                   { 0x1E }
  end;

  { The board's five requests, in the block's order. }
  color6_reqs_t = record
    fifo: color6_req_t;                   { 0x00 }
    ctl2: color6_req_t;                   { 0x20 }
    ctl1: color6_req_t;                   { 0x40 }
    csr: color6_req_t;                    { 0x60 }
    memory: color6_req_t;                 { 0x80 }
  end;

  { The overlay section COLOR6_$WIRED_DATA's contents, 0x1A0 bytes: the
    driver's areas, its vector, the three units' state and the board's
    requests. }
  color6_wired_data_t = record
    areas: color6_$areas_t;               { 0x000 }
    hdm: color6_$hdm_t;                   { 0x010 }
    info: array[1..3] of color6_$info_t;  { 0x094 }
    reqs: color6_reqs_t;                  { 0x100 }
  end;

var
  { The I/O pages the requests name (map symbols of IODEFS).  Only their
    addresses are used. }
  disp1: extern char;
  disp_matrox_ctl1: extern char;
  disp_matrox_ctl2: extern char;
  disp_matrox_fifo: extern char;

{ The overlay sections, the variables named after them
  (ring/ringlog.ins.pas's form), with the image's bytes. }
var (color6_end_data)
  color6_end_data: integer32 := 0;

var (color6_$wired_data)
  color6_$wired_data: color6_wired_data_t :=
    [areas := [[start_va := addr(color6_$wired_data),
                end_va := addr(color6_end_data)],
               [start_va := addr(color6_$start_wired_proc),
                end_va := addr(color6_$end_wired_proc)]],
     hdm := [field_00 := 1,
             video_ctl := addr(color6_$video_ctl),
             load_crsr := addr(color6_$set_crs_pat),
             lock_display := addr(color6_$lock_display),
             blink_cursor := addr(color6_$blink_cursor),
             xor_cursor := addr(color6_$xor_cursor),
             map := addr(color6_$map_disp),
             unmap := addr(color6_$unmap_disp),
             install_disp := addr(color6_$install_disp),
             assoc := addr(color6_$assoc),
             dissoc := addr(color6_$dissoc),
             busy_wait := addr(color6_$busy_wait),
             clear_screen := addr(color6_$clear_screen),
             putc := addr(color6_$putc),
             display_logo := addr(color6_$display_logo),
             device_info := addr(color6_$device_info),
             hw_uid := [high := 16#38197FE5, low := 16#E000FC3F],
             disp_type := 12,               { smd_$color6_display }
             line_bits := 2048,
             word_74 := 1024,
             width := 1280,
             height := 1024,
             n_areas := 2,
             areas := addr(color6_$wired_data.areas)],
     reqs := [fifo := [next := nil,
                       csr := [va := addr(disp_matrox_fifo),
                               pa := 16#D40000, pages := 1,
                               has_csr := true],
                       tag := 1, bus := 3],
              ctl2 := [next := addr(color6_$wired_data.reqs.fifo),
                       csr := [va := addr(disp_matrox_ctl2),
                               pa := 16#DA0000, pages := 1,
                               has_csr := true],
                       tag := 1, bus := 3],
              ctl1 := [next := addr(color6_$wired_data.reqs.ctl2),
                       csr := [va := addr(disp_matrox_ctl1),
                               pa := 16#D80000, pages := 1,
                               has_csr := true],
                       tag := 1, bus := 3],
              csr := [next := addr(color6_$wired_data.reqs.ctl1),
                      csr := [va := addr(disp1), pa := 16#C6000,
                              pages := 1, has_csr := true],
                      tag := 1, bus := 3],
              memory := [next := addr(color6_$wired_data.reqs.csr),
                         csr := [va := addr(disp1_mem), pa := 16#900000,
                                 pages := 256, has_csr := true],
                         tag := 1, bus := 3]]];

{ The descriptors (map symbols, defined here; ref 7.2.1, Method 1), in the
  order of the block. }
var
  color6_$unit_1: define color6_$dcte_t :=      { +0x00 }
    [kind := color6_$dcte_kind, length := 64, ctype := color6_$dcte_ctype,
     cnum := 5, nextp := nil, csrsytr := addr(color6_$ioinit),
     hdm := addr(color6_$wired_data.hdm),
     info := addr(color6_$wired_data.info[1]),
     config := addr(color6_$wired_data.reqs.memory)];
  color6_$unit_2: define color6_$dcte_t :=      { +0x40 }
    [kind := color6_$dcte_kind, length := 64, ctype := color6_$dcte_ctype,
     cnum := 3, nextp := nil, csrsytr := addr(color6_$ioinit),
     hdm := addr(color6_$wired_data.hdm),
     info := addr(color6_$wired_data.info[2]),
     config := addr(color6_$wired_data.reqs.memory)];
  color6_$unit_3: define color6_$dcte_t :=      { +0x80 }
    [kind := color6_$dcte_kind, length := 64, ctype := color6_$dcte_ctype,
     cnum := 6, nextp := nil, csrsytr := addr(color6_$ioinit),
     hdm := addr(color6_$wired_data.hdm),
     info := addr(color6_$wired_data.info[3]),
     config := addr(color6_$wired_data.reqs.memory)];
%endif
