{ PMAP_$UPDATE_CALLBACK - the update timer's callback.

  Image addresses:
    sau2  0x00E143B2  PMAP_$UPDATE_CALLBACK
    sau4  0x0F814C26  PMAP_$UPDATE_CALLBACK
    sau9  0x3C416698  PMAP_$UPDATE_CALLBACK

  - AST_$UPDATE writes the objects' attributes back.

  Status stored: none.
}

procedure pmap_$update_callback;
begin
  ast_$update;
end;
