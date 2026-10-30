{ name_$validate_leaf - case-map one leaf name and check its characters.

  Image addresses:
    sau2  0x00E54414  name_$validate_leaf

  - MAP_CASE maps the name (at most 32 bytes); the result is true when it
    was not truncated, is 1..32 bytes, its first byte not a backslash
    and in the first-character set, and every later byte in the set.
  - A fragment of OLD_DIR.
  - The two sets are OLD_DIR's module variables, read through the
    callers' A5.

  Status stored: none.
}

function name_$validate_leaf(in name: univ name_$long_name_t;
                             name_len: pinteger;
                             out parsed: univ name_$long_name_t;
                             out parsed_len: pinteger): boolean;
  internal;
var
  truncated: boolean;
  i: integer;
begin
  name_$validate_leaf := false;
  if name_len > 32 then
    return;

  map_case(name, name_len, parsed, 32, parsed_len, truncated);

  if truncated then
    return;
  if parsed_len = 0 then
    return;
  if parsed_len > 32 then
    return;
  if parsed[1] = '\' then
    return;

  if not (parsed[1] in name_$leaf_first_char_set) then
    return;

  for i := 2 to parsed_len do
    if not (parsed[i] in name_$leaf_char_set) then
      return;

  name_$validate_leaf := true;
end;
