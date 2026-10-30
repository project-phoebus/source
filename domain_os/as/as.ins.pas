{ as/as.ins.pas - AS_ (the address-space layout) types, variables and
  routine headings, for the Domain Pascal tree.

  The address-range pair, the layout record AS_$INFO and its size word,
  and the headings of the three AS routines; the module is as/as.pas.
  Apollo's customer insert files of SR10.2 declare none of these.
  Include base/base.ins.pas before it.
}

const
  { The size of AS_$INFO in bytes (0x5C), the value of AS_$INFO_SIZE. }
  as_$info_bytes = 92;

  { AS_$INIT's constants, immediates in its code. }
  m68020_global_a_base = 16#033C0000;
  m68020_global_a_size = 16#00700000;
  m68020_as_offset = 16#02A00000;

type
  { An address range, a base and a size, 8 bytes. }
  as_$addr_range_t = record
    base: integer32;                      { 0x00 }
    size: integer32;                      { 0x04 }
  end;

  { AS_$INFO, 0x5C bytes, in the hand-written AS_ASM block.  The fields
    at the map's nine interior symbols take the map's names; the others
    are named for AS_$INIT's use of them, else by offset.  +0x44, the
    field AS_$INIT adds to, is l_44: the map's AS_$STACK_OFFSET is +0x40.
    The second variant is the record's bytes, as AS_$GET_INFO copies
    them.

    The map's interior symbols make several of the longwords parts of
    larger objects (AS_$CR_REC 24 bytes, AS_$STACK_LOW 8,
    AS_$STACK_OFFSET and AS_$INIT_STACK_FILE_SIZE 12, AS_$GLOBAL_A 16);
    nothing compiled reads them as such, so the fields stay longwords. }
  as_$info_bytes_t = array[1..as_$info_bytes] of char;
  as_$info_t = record
    case integer of
      1: (w_00: integer;                  { 0x00 }
          w_02: integer;                  { 0x02 }
          global_a: as_$addr_range_t;     { 0x04: AS_$GLOBAL_A }
          global_a_m68020: as_$addr_range_t;
                                          { 0x0C: the 68020 copy of
                                            global_a }
          private: integer32;             { 0x14: AS_$PRIVATE }
          stack_file_low: integer32;      { 0x18: AS_$STACK_FILE_LOW }
          cr_rec: integer32;              { 0x1C: AS_$CR_REC }
          l_20: integer32;                { 0x20 }
          cr_rec_end: integer32;          { 0x24 }
          l_28: integer32;                { 0x28 }
          stack_file_high: integer32;     { 0x2C }
          l_30: integer32;                { 0x30 }
          stack_low: integer32;           { 0x34: AS_$STACK_LOW }
          l_38: integer32;                { 0x38 }
          stack_high: integer32;          { 0x3C: AS_$STACK_HIGH }
          stack_offset: integer32;        { 0x40: AS_$STACK_OFFSET }
          l_44: integer32;                { 0x44 }
          l_48: integer32;                { 0x48 }
          init_stack_file_size: integer32;{ 0x4C: AS_$INIT_STACK_FILE_SIZE }
          cr_rec_file: integer32;         { 0x50 }
          l_54: integer32;                { 0x54 }
          cr_rec_file_size: integer32);   { 0x58: AS_$CR_REC_FILE_SIZE }
      2: (bytes: as_$info_bytes_t);       { 0x00..0x5B }
  end;

var
  { AS_$INFO and AS_$INFO_SIZE: map symbols of the hand-written AS_ASM
    data segment in WIRED_DATA. }
  as_$info: extern as_$info_t;
  as_$info_size: extern integer;

{ Routine headings, in map order (the OS_INIT_PROC AS segment, then the
  .TEXT one).  The bodies repeat the full heading (ref 7.3.4, Method
  2). }

{ AS_$INIT - relocate the address-space layout for a 68020. }
procedure as_$init; extern;

{ AS_$GET_INFO - copy the address-space layout to the caller. }
procedure as_$get_info(out buffer: univ as_$info_bytes_t;
                       in req_size: integer;
                       out actual_size: integer);
  extern;

{ AS_$GET_ADDR - return the base and size of an address-space region. }
procedure as_$get_addr(out addr_range: as_$addr_range_t;
                       in region: integer);
  extern;

var
  { AS_$GLOBAL_A, AS_$PRIVATE, AS_$STACK_LOW (map symbols in AS's
    block): address-space bounds. }
  as_$global_a: extern linteger;
  as_$private: extern linteger;
  as_$stack_low: extern linteger;
  { AS_$STACK_HIGH (map symbol in AS's block): the stack address OS_$INIT
    gives process 2 as its USP. }
  as_$stack_high: extern linteger;

  { AS_$PROTECTION (map symbol, the longword after AS_$INFO_SIZE in
    AS's hand-written block; 16#00CC0000 in the SAU2 image): the lowest
    address an eventcount may not lie at (EC2_$WAIT). }
  as_$protection: extern linteger;

{ AS_$GET_ADDR's regions.  No Apollo insert declares them. }
const
  as_$region_private_a = 0;
  as_$region_global_a = 1;
  as_$region_private_b = 2;
  as_$region_global_b = 3;
