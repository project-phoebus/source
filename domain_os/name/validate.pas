{ NAME_$VALIDATE - classify how a pathname begins.

  Image addresses:
    sau2  0x00E49F4C  NAME_$VALIDATE

  - An empty path, or one not beginning with '/' or '`', is relative;
    '/' absolute, "//" a network path (each '/' counted in consumed).
  - "`node_data" or "`node_data/..." is a node-data path; one over 256
    bytes an error.
  - The result is always true.  consumed is only incremented, never set.

  Status stored: none.
}

function name_$validate(in path: univ name_$long_pname_t;
                        in path_len: pinteger;
                        in out consumed: integer;
                        out start_path_type: integer): boolean;
begin
  if path_len > 256 then
    start_path_type := start_path_$error
  else begin
    start_path_type := start_path_$relative;
    if path_len <> 0 then
      case path[1] of
        '/': begin
               start_path_type := start_path_$absolute;
               consumed := consumed + 1;
               if (path_len >= 2) and then (path[2] = '/') then begin
                 start_path_type := start_path_$network;
                 consumed := consumed + 1;
               end;
             end;
        '`': begin
          if path_len = 10 then begin
            if nameq(path, 10, '`node_data', 10) then
              start_path_type := start_path_$node_data;
          end
          else if path_len > 10 then
            if nameq(path, 11, '`node_data/', 11) then
              start_path_type := start_path_$node_data;
        end;
      end;
  end;

  name_$validate := true;
end;
