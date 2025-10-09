------------------------------------------------------------------------------
--  SML.DOM.Writer Package Body
--  DOM Serialization Implementation
--  SPARK Ada Implementation with Formal Verification Support
------------------------------------------------------------------------------

with SML.Entities;

package body SML.DOM.Writer
  with SPARK_Mode => On
is

   ---------------------------------------------------------------------------
   --  Size Estimation
   ---------------------------------------------------------------------------

   function Calculate_Max_Size (Doc : SML.DOM.Document) return Natural is
      pragma Unreferenced (Doc);
   begin
      --  Conservative estimate: max possible size
      --  Each node: max 200 chars (tags + content with entities)
      --  This is a simplified implementation
      return 100_000;  -- Reasonable upper bound
   end Calculate_Max_Size;

   ---------------------------------------------------------------------------
   --  Serialization
   ---------------------------------------------------------------------------

   function Serialize (Doc : SML.DOM.Document) return String is
      Max_Size : constant Natural := Calculate_Max_Size (Doc);
      Result   : String (1 .. Max_Size) := [others => ' '];
      Pos      : Natural := 0;

      procedure Write_Char (C : Character) is
      begin
         if Pos < Max_Size then
            Pos := Pos + 1;
            Result (Pos) := C;
         end if;
      end Write_Char;

      procedure Write_String (S : String) is
      begin
         for I in S'Range loop
            Write_Char (S (I));
         end loop;
      end Write_String;

      procedure Serialize_Node (Node : SML.DOM.Node_Id) is
         Node_Kind : SML.DOM.Node_Kind;
         Children  : Natural;
         Child     : SML.DOM.Node_Id;
         Count     : Natural := 0;
      begin
         if Node = SML.DOM.Null_Node then
            return;
         end if;

         Node_Kind := SML.DOM.Kind (Doc, Node);

         if Node_Kind = SML.DOM.Element then
            --  Write opening tag
            Write_Char ('<');
            Write_String (SML.DOM.Name (Doc, Node));
            Write_Char ('>');

            --  Serialize children
            Children := SML.DOM.Child_Count (Doc, Node);

            if Children > 0 then
               Child := SML.DOM.First_Child (Doc, Node);

               while Child /= SML.DOM.Null_Node and then Count < Children loop
                  pragma Loop_Variant (Increases => Count);

                  Serialize_Node (Child);

                  Child := SML.DOM.Next_Sibling (Doc, Child);
                  Count := Count + 1;
               end loop;
            end if;

            --  Write closing tag
            Write_String ("</");
            Write_String (SML.DOM.Name (Doc, Node));
            Write_Char ('>');

         else
            --  Text node - encode entities
            declare
               Text_Content : constant String :=
                 SML.DOM.Text_Value (Doc, Node);
               Encoded      : constant String :=
                 SML.Entities.Encode_Entities (Text_Content);
            begin
               Write_String (Encoded);
            end;
         end if;
      end Serialize_Node;

   begin
      --  Start serialization from root
      Serialize_Node (SML.DOM.Root (Doc));

      --  Return actual content
      return Result (1 .. Pos);
   end Serialize;

   function Serialize_Formatted
     (Doc           : SML.DOM.Document;
      Indent_Spaces : Natural := 2) return String
   is
      Max_Size : constant Natural := Calculate_Max_Size (Doc) * 2;
      Result   : String (1 .. Max_Size) := [others => ' '];
      Pos      : Natural := 0;
      Depth    : Natural := 0;

      procedure Write_Char (C : Character) is
      begin
         if Pos < Max_Size then
            Pos := Pos + 1;
            Result (Pos) := C;
         end if;
      end Write_Char;

      procedure Write_String (S : String) is
      begin
         for I in S'Range loop
            Write_Char (S (I));
         end loop;
      end Write_String;

      procedure Write_Newline is
      begin
         Write_Char (ASCII.LF);
      end Write_Newline;

      procedure Write_Indent is
         Total_Spaces : constant Natural := Depth * Indent_Spaces;
      begin
         for I in 1 .. Total_Spaces loop
            pragma Loop_Variant (Increases => I);
            Write_Char (' ');
         end loop;
      end Write_Indent;

      procedure Serialize_Node_Formatted (Node : SML.DOM.Node_Id) is
         Node_Kind : SML.DOM.Node_Kind;
         Children  : Natural;
         Child     : SML.DOM.Node_Id;
         Count     : Natural := 0;
      begin
         if Node = SML.DOM.Null_Node then
            return;
         end if;

         Node_Kind := SML.DOM.Kind (Doc, Node);

         if Node_Kind = SML.DOM.Element then
            --  Write opening tag with indent
            Write_Indent;
            Write_Char ('<');
            Write_String (SML.DOM.Name (Doc, Node));
            Write_Char ('>');
            Write_Newline;

            --  Serialize children with increased depth
            Children := SML.DOM.Child_Count (Doc, Node);

            if Children > 0 and then Depth < 100 then
               Depth := Depth + 1;
               Child := SML.DOM.First_Child (Doc, Node);

               while Child /= SML.DOM.Null_Node and then Count < Children loop
                  pragma Loop_Variant (Increases => Count);

                  Serialize_Node_Formatted (Child);

                  Child := SML.DOM.Next_Sibling (Doc, Child);
                  Count := Count + 1;
               end loop;

               Depth := Depth - 1;
            end if;

            --  Write closing tag with indent
            Write_Indent;
            Write_String ("</");
            Write_String (SML.DOM.Name (Doc, Node));
            Write_Char ('>');
            Write_Newline;

         else
            --  Text node - encode entities, with indent
            declare
               Text_Content : constant String :=
                 SML.DOM.Text_Value (Doc, Node);
               Encoded      : constant String :=
                 SML.Entities.Encode_Entities (Text_Content);
            begin
               Write_Indent;
               Write_String (Encoded);
               Write_Newline;
            end;
         end if;
      end Serialize_Node_Formatted;

   begin
      --  Start serialization from root
      Serialize_Node_Formatted (SML.DOM.Root (Doc));

      --  Return actual content
      return Result (1 .. Pos);
   end Serialize_Formatted;

end SML.DOM.Writer;
