{ suma/suma.ins.pas - the tablet (SUMA_, map module BITPAD) sample types,
  constants and routine headings, for the Domain Pascal tree.

  The 16-byte tablet sample, the circular buffer of six samples that
  TERM_$TPAD_BUFFER is, the bitpad's thresholds and the headings of the
  two SUMA_$ routines.  The buffer itself is a variable of the KBD
  module (in KBD's data segment), declared in kbd/kbd.ins.pas.  The
  BITPAD module is suma/suma.pas.  Include base/base.ins.pas before it.

  Apollo's customer insert files of SR10.2 declare none of these
  (tpad.ins.pas has only the user routines and the mode types;
  sio.ins.pas names the line's sio_$bp_enable, nothing of the driver).
}

const
  { The samples of the buffer.  Every producer (KBD_$RCV, SUMA_$RCV)
    wraps the head at 6; the consumer TERM_$ENQUEUE_TPAD the tail. }
  suma_$tpad_buffer_size = 6;

  { The bitpad's movement threshold: SUMA_$RCV compares its high byte
    with the differences of the coordinates' low six bits, x_high and
    y_high (the names are inverted, suma_sample_t below).  The initial
    value, the maximum, and the step it grows by. }
  suma_initial_threshold = 16#200;
  suma_max_threshold = 16#0A00;
  suma_threshold_increment = 16#10;

type
  { A byte of a sample read as an unsigned 8-bit integer (ref 3.15.5,
    size attributes: "[byte] 0..255 corresponds to the unsigned char data
    type in Domain/C"), the form of tpad/tpad.ins.pas's tpad_$byte_t:
    SUMA_$RCV masks its received byte (a char has no `&', ref 4.3.4). }
  suma_$byte_t = [byte] 0..255;

  { The identification word of a sample, bytes 0x0A..0x0B: a packed
    record of 16 bits (ref 3.10.7: at least one word; fields from the
    most significant bit), the first byte a char and the second three
    bit fields.  SUMA_$RCV clears bits 7..6 and 1..0 of the second byte
    and merges the identifier into bits 5..2.  A packed record is word
    aligned, so it starts at 0x0A and its first 8 bits are the byte
    there, a char (SUMA_$INIT and KBD_$RCV store it whole).  The
    consumer, TPAD_$DATA, reads the same four bits as the bitpad's
    button state (tpad_$button_state), so the name `id' is not what the
    field holds; it is kept. }
  suma_$id_bits_t = packed record
    byte_0a: char;                        { bits 0..7: the byte at 0x0A }
    bits_7_6: 0..3;                       { bits 8..9: byte 0x0B, 16#C0 }
    id: 0..15;                            { bits 10..13: byte 0x0B,
                                            16#3C }
    bits_1_0: 0..3;                       { bits 14..15: byte 0x0B,
                                            16#03 }
  end;

  { One tablet sample, 16 bytes, copied whole (KBD_$RCV, SUMA_$RCV).
    timestamp, at 4, is a time_$clock_t; KBD_$RCV and SUMA_$RCV read its
    low32.

    The six bytes from 0x0A are read two ways, so they are a variant
    part (ref 3.10.3; both arms start at 0x0A, where the fixed part
    ends).  KBD_$RCV stores chars at 0x0A and, through
    `addr(kbd.sample.reserved_0b)', at 0x0B .. 0x0D (kbd/rcv.pas): the
    first arm.  SUMA_$RCV reads 0x0B as the bit fields of
    suma_$id_bits_t, the second arm: a packed field cannot have its
    address taken (ref 3.10.3 p. 3-21), so the two readings are two
    arms, not one type.  TPAD reads the same 16 bytes with its own type
    (tpad/tpad.ins.pas tpad_$data_packet_t), whose bitpad arm makes x
    byte 0x0D shifted by 6 plus byte 0x0C, and y likewise of 0x0F, 0x0E:
    x_high and y_high (0x0C, 0x0E) are the coordinates' low six bits and
    x_low and y_low their high parts.  The names are kept. }
  suma_sample_t = record
    delta_time: integer32;                { 0x00 }
    timestamp: time_$clock_t;             { 0x04 }
    case integer of
      1: (id_flags: char;                 { 0x0A }
          reserved_0b: char;              { 0x0B }
          x_high: suma_$byte_t;           { 0x0C }
          x_low: suma_$byte_t;            { 0x0D }
          y_high: suma_$byte_t;           { 0x0E }
          y_low: suma_$byte_t);           { 0x0F }
      2: (id_bits: suma_$id_bits_t);      { 0x0A..0x0B }
  end;

  { The circular buffer of samples, 100 bytes; the samples from index 0
    at +4. }
  tpad_buffer_t = record
    head: integer;                        { 0x00: the producer's index }
    tail: integer;                        { 0x02: the consumer's index }
    samples: array[0..suma_$tpad_buffer_size-1] of suma_sample_t;
                                          { 0x04..0x63 }
  end;

  { A pointer to the buffer, as a KBD descriptor holds it (kbd/kbd.ins.pas,
    tpad_buffer at 0x30) and BITPAD's suma_$tpad_buffer (suma/suma.pas),
    and a pointer to such a pointer, the argument TERM_$ENQUEUE_TPAD reads
    (term/term.ins.pas). }
  tpad_buffer_ptr_t = ^tpad_buffer_t;
  tpad_buffer_ptr_ptr_t = ^tpad_buffer_ptr_t;

{ Routine headings, in map order (BITPAD's WIRED_PROC segment, then its
  OS_INIT_PROC one).  The bodies repeat the full heading (ref 7.3.4,
  Method 2). }

{ SUMA_$RCV - a bitpad line's receive handler: one byte of a packet. }
procedure suma_$rcv(param_1: univ_ptr; data_byte: suma_$byte_t);
  options(extern, val_param);

{ SUMA_$INIT - initialize the bitpad driver's state. }
procedure suma_$init; extern;
