{ color4/color4_dcte.pas - the COLOR4_DCTE module, the COLOR4 units'
  descriptors, and the driver's wired data.

  Image addresses:
    sau7  0x3C435B54  COLOR4_DCTE data (WIRED_DATA, 0x80 bytes)
    sau7  0x3C4BA188  COLOR4_$WIRED_DATA overlay (0x174 bytes)
    sau7  0x3C4BA2FC  COLOR4_END_DATA overlay (0x4 bytes)
    sau8  0x03C30300  COLOR4_DCTE data (WIRED_DATA, 0x80 bytes)
    sau8  0x03CA62E4  COLOR4_$WIRED_DATA overlay (0x174 bytes)
    sau8  0x03CA6458  COLOR4_END_DATA overlay (0x4 bytes)

  A map module of data only, `module color4_dcte, , wired_data;': the
  map's COLOR4_DCTE segment in WIRED_DATA, after COLOR4's own block, with
  the two units' DCTEs, COLOR4_$UNIT_2 and COLOR4_$UNIT_1, which
  io/dctes.pas's DEV_DCTES lists.  And the contents of the overlay
  section COLOR4_$WIRED_DATA (the map's load section, no module segment
  in it; ref 3.14), which the DCTEs point into: the driver's areas, the
  routine vector, the units' state and their I/O map requests; and the
  overlay section COLOR4_END_DATA after it, 4 zero bytes, the end of the
  driver's data area.  Which unit gave the overlays their bytes is not
  known; the descriptors are what name them.

  The requests' CSR and memory addresses are the I/O definitions' pages
  (the map's IODEFS symbols): DISP1 and DISP1_MEM for unit 1,
  DISP_ALT2 and DISP_ALT_MEM for unit 2, on the AT bus (bus 3).

  With the part color4_driver (base/config.ins.pas), empty elsewhere.

  Check: tools/pascal_check.sh (which finds this file by its module
  heading).
}
module color4_dcte, , wired_data;

%include 'base/base.ins.pas';
%if color4_driver %then
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'io/io.ins.pas';
%include 'smd/smd.ins.pas';
%include 'color4/color4.ins.pas';

type
  { A request as the image holds it: io_$acquire_rec_t with its link and
    the CSR pages' address as pointers (dpc takes `addr' for a univ_ptr
    cell), and the pad word that makes it 0x20 bytes (io/io_desc.pas's
    form). }
  color4_req_csr_t = record
    va: univ_ptr;                         { 0x00 }
    pa: linteger;                         { 0x04 }
    pages: integer;                       { 0x08 }
    has_csr: boolean;                     { 0x0A }
    unused_0b: char;                      { 0x0B }
  end;
  color4_req_t = record
    next: univ_ptr;                       { 0x00 }
    int: io_$int_info_t;                  { 0x04 }
    csr: color4_req_csr_t;                { 0x0C }
    tag: integer;                         { 0x18 }
    bus: integer;                         { 0x1A }
    attrs: io_$attr_t;                    { 0x1C }
    unused_1e: integer;                   { 0x1E }
  end;

  { A unit's two requests: its CSR pages' and its display memory's. }
  color4_unit_reqs_t = record
    csr: color4_req_t;                    { 0x00 }
    memory: color4_req_t;                 { 0x20 }
  end;

  { The overlay section COLOR4_$WIRED_DATA's contents, 0x174 bytes: the
    driver's areas, its vector, the two units' state and their
    requests. }
  color4_wired_data_t = record
    areas: color4_$areas_t;               { 0x000 }
    hdm: color4_$hdm_t;                   { 0x010 }
    info: array[1..2] of color4_$info_t;  { 0x094 }
    reqs: array[1..2] of color4_unit_reqs_t;  { 0x0F4 }
  end;

var
  { The I/O pages the requests name (map symbols of IODEFS).  Only their
    addresses are used. }
  disp1: extern char;
  disp_alt2: extern char;
  disp_alt_mem: extern char;

{ The overlay sections, the variables named after them
  (ring/ringlog.ins.pas's form), with the image's bytes. }
var (color4_end_data)
  color4_end_data: integer32 := 0;

var (color4_$wired_data)
  color4_$wired_data: color4_wired_data_t :=
    [areas := [[start_va := addr(color4_$wired_data),
                end_va := addr(color4_end_data)],
               [start_va := addr(color4_$copy_font_md_hdm),
                end_va := addr(color4_$end_wired_proc)]],
     hdm := [field_00 := 1,
             video_ctl := addr(color4_$video_ctl),
             copy_font_md_hdm := addr(color4_$copy_font_md_hdm),
             lock_display := addr(color4_$lock_display),
             blink_cursor := addr(color4_$blink_cursor),
             xor_cursor := addr(color4_$xor_cursor),
             rel_disp := addr(color4_$rel_disp),
             map_display_memory := addr(color4_$map_display_memory),
             unmap_display_memory := addr(color4_$unmap_display_memory),
             install_disp_mem := addr(color4_$install_disp_mem),
             lites := addr(color4_$lites),
             assoc_csrs := addr(color4_$assoc_csrs),
             dissoc := addr(color4_$dissoc),
             clear_screen := addr(color4_$clear_screen),
             putc := addr(color4_$putc),
             display_logo := addr(color4_$display_logo),
             set_color_table := addr(color4_$set_color_table),
             hw_uid := [high := 16#34768C74, low := 16#10002640],
             disp_type := 8,                { smd_$color4_display }
             line_bits := 1024,
             word_74 := 1024,
             width := 1024,
             height := 800,
             n_areas := 2,
             areas := addr(color4_$wired_data.areas)],
     reqs := [[csr := [next := nil,
                       csr := [va := addr(disp1), pa := 16#3D0, pages := 2,
                               has_csr := true],
                       tag := 1, bus := 3],
               memory := [next := addr(color4_$wired_data.reqs[1].csr),
                          csr := [va := addr(disp1_mem), pa := 16#A0000,
                                  pages := 128, has_csr := true],
                          tag := 1, bus := 3]],
              [csr := [next := nil,
                       csr := [va := addr(disp_alt2),
                               pa := color4_$lut_unit_csr, pages := 2,
                               has_csr := true],
                       tag := 1, bus := 3],
               memory := [next := addr(color4_$wired_data.reqs[2].csr),
                          csr := [va := addr(disp_alt_mem), pa := 16#E0000,
                                  pages := 128, has_csr := true],
                          tag := 1, bus := 3]]]];

{ The descriptors (map symbols, defined here; ref 7.2.1, Method 1), in the
  order of the block: unit 2's first. }
var
  color4_$unit_2: define color4_$dcte_t :=      { +0x00 }
    [kind := color4_$dcte_kind, length := 64, ctype := color4_$dcte_ctype,
     cnum := 0, nextp := nil, csrsytr := addr(color4_$ioinit),
     hdm := addr(color4_$wired_data.hdm),
     info := addr(color4_$wired_data.info[2]),
     config := addr(color4_$wired_data.reqs[2].memory)];
  color4_$unit_1: define color4_$dcte_t :=      { +0x40 }
    [kind := color4_$dcte_kind, length := 64, ctype := color4_$dcte_ctype,
     cnum := 0, nextp := nil, csrsytr := addr(color4_$ioinit),
     hdm := addr(color4_$wired_data.hdm),
     info := addr(color4_$wired_data.info[1]),
     config := addr(color4_$wired_data.reqs[1].memory)];
%endif
