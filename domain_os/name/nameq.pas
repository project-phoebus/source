{ NAMEQ - compare two names, trailing blanks ignored.

  Image addresses:
    sau2  0x00E49EAC  NAMEQ

  - False when either length is 0; else the common prefix must match and
    the longer name's rest be blanks.  A global without `$'.

  Status stored: none.
}

function nameq(in str1: univ name_$long_pname_t; in len1: pinteger;
               in str2: univ name_$long_pname_t; in len2: pinteger): boolean;
var
  n: pinteger;
  i: pinteger;
begin
  nameq := false;

  if (len1 = 0) or else (len2 = 0) then
    return;

  { the common prefix }
  n := len1;
  if n > len2 then
    n := len2;
  for i := 1 to n do
    if str1[i] <> str2[i] then
      return;

  { the longer name's tail must be blanks }
  if len1 > len2 then begin
    for i := len2 + 1 to len1 do
      if str1[i] <> ' ' then
        return;
  end
  else if len2 > len1 then
    for i := len1 + 1 to len2 do
      if str2[i] <> ' ' then
        return;

  nameq := true;
end;
