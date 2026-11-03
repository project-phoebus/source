{ mono/mono_dcte.pas - the MONO_DCTE module, the MONO units'
  descriptors, and the driver's wired data.

  Image addresses:
    sau8  0x03C30440  MONO_DCTE data (WIRED_DATA, 0x100 bytes)
    sau8  0x03CA6008  MONO_$WIRED_DATA overlay (0x2D8 bytes)
    sau8  0x03CA62E0  MONO_END_DATA overlay (0x4 bytes)

  A map module of data only, `module mono_dcte, , wired_data;' (the
  form of color4/color4_dcte.pas): the map's MONO_DCTE segment in
  WIRED_DATA, after MONO's own block, with the four units' DCTEs,
  MONO_$UNIT_BIG1, MONO_$UNIT_SMALL1, MONO_$UNIT_SMALL1A and
  MONO_$UNIT_SMALL2, which io/dctes.pas's DEV_DCTES lists.  And the
  contents of the overlay section MONO_$WIRED_DATA (the map's load
  section, no module segment in it; ref 3.14), which the DCTEs point
  into: the driver's areas, the two forms' routine vectors (the small
  form's first), four units' state and seven I/O map requests; and the
  overlay section MONO_END_DATA after it, 4 zero bytes, the end of the
  driver's data area.  Which unit gave the overlays their bytes is not
  known; the descriptors are what name them.

  The units: BIG1 (the big form, 256 pages of display memory) and
  SMALL1 (the small one, 128 pages) share one CSR request (DISP1, bus
  address 16#3B0) and the memory at DISP1_MEM, each with its own state;
  SMALL1A (cnum 1) has the CSR pages at DISP_ALT2 and the memory at
  DISP_ALT_MEM, the same bus addresses, and shares SMALL1's state (the
  first of the two IO_$INIT finds claims it); SMALL2 (cnum 1) is the
  board at the bus addresses 16#3D0 and 16#A0000, at DISP_ALT2 and
  DISP_ALT_MEM.  Each memory request's first longword is its CSR
  request's address.  The fourth state record is named by no DCTE.  All
  on the AT bus (bus 3).

  With the part mono_driver (base/config.ins.pas), empty elsewhere.

  Check: tools/pascal_check.sh (which finds this file by its module
  heading).
}
module mono_dcte, , wired_data;

%include 'base/base.ins.pas';
%if mono_driver %then
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'io/io.ins.pas';
%include 'smd/smd.ins.pas';
%include 'mono/mono.ins.pas';

type
  { A request as the image holds it: io_$acquire_rec_t with its link and
    the CSR pages' address as pointers (dpc takes `addr' for a univ_ptr
    cell), and the pad word that makes it 0x20 bytes (io/io_desc.pas's
    form). }
  mono_req_csr_t = record
    va: univ_ptr;                         { 0x00 }
    pa: linteger;                         { 0x04 }
    pages: integer;                       { 0x08 }
    has_csr: boolean;                     { 0x0A }
    unused_0b: char;                      { 0x0B }
  end;
  mono_req_t = record
    next: univ_ptr;                       { 0x00 }
    int: io_$int_info_t;                  { 0x04 }
    csr: mono_req_csr_t;                  { 0x0C }
    tag: integer;                         { 0x18 }
    bus: integer;                         { 0x1A }
    attrs: io_$attr_t;                    { 0x1C }
    unused_1e: integer;                   { 0x1E }
  end;

  { The overlay section MONO_$WIRED_DATA's contents, 0x2D8 bytes: the
    driver's areas, the small and the big form's vectors, four units'
    state, and the requests: the first controller's CSR pages, its
    memory for the small and the big form, the second controller's CSR
    pages and memory at 16#3B0, and at 16#3D0. }
  mono_wired_data_t = record
    areas: mono_$areas_t;                 { 0x000 }
    small_hdm: mono_$hdm_t;               { 0x010 }
    big_hdm: mono_$hdm_t;                 { 0x094 }
    info: array[1..4] of mono_$info_t;    { 0x118 }
    csr_1: mono_req_t;                    { 0x1F8 }
    memory_small1: mono_req_t;            { 0x218 }
    memory_big1: mono_req_t;              { 0x238 }
    csr_1a: mono_req_t;                   { 0x258 }
    memory_small1a: mono_req_t;           { 0x278 }
    csr_2: mono_req_t;                    { 0x298 }
    memory_small2: mono_req_t;            { 0x2B8 }
  end;

var
  { The I/O pages the requests name (map symbols of IODEFS).  Only their
    addresses are used. }
  disp1: extern char;
  disp_alt2: extern char;
  disp_alt_mem: extern char;

{ The overlay sections, the variables named after them
  (ring/ringlog.ins.pas's form), with the image's bytes. }
var (mono_end_data)
  mono_end_data: integer32 := 0;

var (mono_$wired_data)
  mono_$wired_data: mono_wired_data_t :=
    [areas := [[start_va := addr(mono_$wired_data),
                end_va := addr(mono_end_data)],
               [start_va := addr(mono_$copy_font_md_hdm),
                end_va := addr(mono_$end_wired_proc)]],
     small_hdm := [field_00 := 1,
                   video_ctl := addr(mono_$video_ctl),
                   copy_font_md_hdm := addr(mono_$copy_font_md_hdm),
                   lock_display := addr(mono_$lock_display),
                   blink_cursor := addr(mono_$blink_cursor),
                   xor_cursor := addr(mono_$xor_cursor),
                   rel_disp := addr(mono_$rel_disp),
                   map_display_memory := addr(mono_$map_display_memory),
                   unmap_display_memory :=
                     addr(mono_$unmap_display_memory),
                   install_disp_mem := addr(mono_$install_disp_mem),
                   lights := addr(mono_$lights),
                   assoc_csrs := addr(mono_$assoc_csrs),
                   dissoc := addr(mono_$dissoc),
                   clear_screen := addr(mono_$clear_screen),
                   putc := addr(mono_$putc),
                   display_logo := addr(mono_$display_logo),
                   hw_uid := [high := 16#3CA7C380, low := 16#F0007FB7],
                   disp_type := mono_$small_display,
                   line_bits := 1024,
                   word_74 := 1024,
                   width := 1024,
                   height := 800,
                   n_areas := 2,
                   areas := addr(mono_$wired_data.areas)],
     big_hdm := [field_00 := 1,
                 video_ctl := addr(mono_$video_ctl),
                 copy_font_md_hdm := addr(mono_$copy_font_md_hdm),
                 lock_display := addr(mono_$lock_display),
                 blink_cursor := addr(mono_$blink_cursor),
                 xor_cursor := addr(mono_$xor_cursor),
                 rel_disp := addr(mono_$rel_disp),
                 map_display_memory := addr(mono_$map_display_memory),
                 unmap_display_memory := addr(mono_$unmap_display_memory),
                 install_disp_mem := addr(mono_$install_disp_mem),
                 lights := addr(mono_$lights),
                 assoc_csrs := addr(mono_$assoc_csrs),
                 dissoc := addr(mono_$dissoc),
                 clear_screen := addr(mono_$clear_screen),
                 putc := addr(mono_$putc),
                 display_logo := addr(mono_$display_logo),
                 hw_uid := [high := 16#34768C74, low := 16#00002640],
                 disp_type := mono_$big_display,
                 line_bits := 2048,
                 word_74 := 1024,
                 width := 1280,
                 height := 1024,
                 n_areas := 2,
                 areas := addr(mono_$wired_data.areas)],
     csr_1 := [next := nil,
               csr := [va := addr(disp1), pa := 16#3B0, pages := 2,
                       has_csr := true],
               tag := 1, bus := 3],
     memory_small1 := [next := addr(mono_$wired_data.csr_1),
                       csr := [va := addr(disp1_mem), pa := 16#FA0000,
                               pages := 128, has_csr := true],
                       tag := 1, bus := 3],
     memory_big1 := [next := addr(mono_$wired_data.csr_1),
                     csr := [va := addr(disp1_mem), pa := 16#FA0000,
                             pages := 256, has_csr := true],
                     tag := 1, bus := 3],
     csr_1a := [next := nil,
                csr := [va := addr(disp_alt2), pa := 16#3B0, pages := 2,
                        has_csr := true],
                tag := 1, bus := 3],
     memory_small1a := [next := addr(mono_$wired_data.csr_1a),
                        csr := [va := addr(disp_alt_mem), pa := 16#FA0000,
                                pages := 128, has_csr := true],
                        tag := 1, bus := 3],
     csr_2 := [next := nil,
               csr := [va := addr(disp_alt2), pa := 16#3D0, pages := 2,
                       has_csr := true],
               tag := 1, bus := 3],
     memory_small2 := [next := addr(mono_$wired_data.csr_2),
                       csr := [va := addr(disp_alt_mem), pa := 16#A0000,
                               pages := 128, has_csr := true],
                       tag := 1, bus := 3]];

{ The descriptors (map symbols, defined here; ref 7.2.1, Method 1), in the
  order of the block. }
var
  mono_$unit_big1: define mono_$dcte_t :=        { +0x00 }
    [kind := mono_$dcte_kind, length := 64, ctype := mono_$dcte_ctype,
     cnum := 0, nextp := nil, csrsytr := addr(mono_$ioinit),
     hdm := addr(mono_$wired_data.big_hdm),
     info := addr(mono_$wired_data.info[3]),
     config := addr(mono_$wired_data.memory_big1)];
  mono_$unit_small1: define mono_$dcte_t :=      { +0x40 }
    [kind := mono_$dcte_kind, length := 64, ctype := mono_$dcte_ctype,
     cnum := 0, nextp := nil, csrsytr := addr(mono_$ioinit),
     hdm := addr(mono_$wired_data.small_hdm),
     info := addr(mono_$wired_data.info[1]),
     config := addr(mono_$wired_data.memory_small1)];
  mono_$unit_small1a: define mono_$dcte_t :=     { +0x80 }
    [kind := mono_$dcte_kind, length := 64, ctype := mono_$dcte_ctype,
     cnum := 1, nextp := nil, csrsytr := addr(mono_$ioinit),
     hdm := addr(mono_$wired_data.small_hdm),
     info := addr(mono_$wired_data.info[1]),
     config := addr(mono_$wired_data.memory_small1a)];
  mono_$unit_small2: define mono_$dcte_t :=      { +0xC0 }
    [kind := mono_$dcte_kind, length := 64, ctype := mono_$dcte_ctype,
     cnum := 1, nextp := nil, csrsytr := addr(mono_$ioinit),
     hdm := addr(mono_$wired_data.small_hdm),
     info := addr(mono_$wired_data.info[2]),
     config := addr(mono_$wired_data.memory_small2)];
%endif
