------------------------------------------------------------------------------
--                   Simple Markup Language (SML) Library                   --
--                                                                          --
--                SPARK Proof Support - DOM Parser Package                  --
------------------------------------------------------------------------------

with SML.Entities;

package body SML.DOM.Parser.Proof
with
   SPARK_Mode
is

   ---------------------------------------------------------------------------
   --  Local Helper Functions
   ---------------------------------------------------------------------------

   function Is_Whitespace (C : Character) return Boolean is
     (C = ' ' or else C = ASCII.HT or else C = ASCII.LF or else C = ASCII.CR);

   function Is_Name_Char (C : Character) return Boolean is
     ((C >= 'a' and then C <= 'z')
      or else (C >= 'A' and then C <= 'Z')
      or else (C >= '0' and then C <= '9')
      or else C = '_' or else C = '-' or else C = '.');

   ---------------------------------------------------------------------------
   --  Ghost Function Implementations
   ---------------------------------------------------------------------------

   function Is_Valid_SML (Input : String) return Boolean is
   begin
      return
        Has_Valid_UTF8 (Input)
        and then Has_Valid_Structure (Input)
        and then Has_No_Disallowed_Constructs (Input)
        and then Has_Valid_Entities (Input);
   end Is_Valid_SML;

   function Parses_To (Input : String; Doc : Document) return Boolean is
      Root_Node : constant Node_Id := Root (Doc);
   begin
      --  Tier 1 implementation: Verify root element name matches first tag
      --  Full implementation would verify entire tree structure

      --  Document must have a root
      if Root_Node = Null_Node then
         return False;
      end if;

      --  Find first opening tag in input
      declare
         I         : Natural := Input'First;
         Tag_Start : Natural;
         Tag_End   : Natural;
         Found_Tag : Boolean := False;
      begin
         --  Skip leading whitespace
         while I <= Input'Last and then Is_Whitespace (Input (I)) loop
            pragma Loop_Variant (Increases => I);
            pragma Loop_Invariant (I <= Input'Last + 1);
            I := I + 1;
         end loop;

         --  Should be at opening '<'
         if I > Input'Last or else Input (I) /= '<' then
            return False;
         end if;

         I := I + 1;  -- Skip '<'

         --  Skip any '!' or '?' (disallowed but checked elsewhere)
         if I <= Input'Last and then (Input (I) = '!' or else Input (I) = '?')
         then
            return False;  -- Disallowed construct
         end if;

         --  Extract tag name
         Tag_Start := I;
         while I <= Input'Last and then Is_Name_Char (Input (I)) loop
            pragma Loop_Variant (Increases => I);
            pragma Loop_Invariant (I >= Tag_Start);
            pragma Loop_Invariant (I <= Input'Last + 1);
            I := I + 1;
            Found_Tag := True;
         end loop;

         Tag_End := I - 1;

         if not Found_Tag or else Tag_End < Tag_Start then
            return False;
         end if;

         --  Compare with DOM root element name
         declare
            Input_Tag_Name    : constant String :=
              Input (Tag_Start .. Tag_End);
            Root_Element_Name : constant String := Name (Doc, Root_Node);
         begin
            return Input_Tag_Name = Root_Element_Name;
            --  TODO: Complete implementation would also verify:
            --  - All child elements match
            --  - All text content matches (with entities expanded)
            --  - All input consumed by DOM
         end;
      end;
   end Parses_To;

   function Has_Valid_Structure (Input : String) return Boolean is
      I           : Natural := Input'First;
      Depth       : Natural := 0;
      Seen_Root   : Boolean := False;
      Inside_Root : Boolean := False;
      C           : Character;
   begin
      --  Empty input has no valid structure
      if Input'Length = 0 then
         return False;
      end if;

      --  Skip leading whitespace
      while I <= Input'Last and then Is_Whitespace (Input (I)) loop
         pragma Loop_Variant (Increases => I);
         pragma Loop_Invariant (I <= Input'Last + 1);
         pragma Loop_Invariant (Depth = 0);
         I := I + 1;
      end loop;

      --  Must start with opening tag
      if I > Input'Last or else Input (I) /= '<' then
         return False;
      end if;

      --  Main structure validation loop
      while I <= Input'Last loop
         pragma Loop_Variant (Increases => I);
         pragma Loop_Invariant (Depth <= Max_Tree_Depth);
         pragma Loop_Invariant (I <= Input'Last + 1);

         C := Input (I);

         if C = '<' then
            --  Check for closing tag
            if I + 1 <= Input'Last and then Input (I + 1) = '/' then
               --  Closing tag
               Depth := Depth - 1;

               if Depth < 0 then
                  return False;  -- Closing without opening
               end if;

               if Depth = 0 then
                  Inside_Root := False;
               end if;

               --  Skip to end of closing tag
               while I <= Input'Last and then Input (I) /= '>' loop
                  pragma Loop_Variant (Increases => I);
                  pragma Loop_Invariant (I <= Input'Last + 1);
                  I := I + 1;
               end loop;

            elsif I + 1 <= Input'Last and then Input (I + 1) /= '!' then
               --  Opening tag (not <! which would be disallowed)
               if Depth = 0 and then Seen_Root then
                  return False;  -- Multiple root elements
               end if;

               if Depth = 0 then
                  Seen_Root := True;
                  Inside_Root := True;
               end if;

               Depth := Depth + 1;

               --  Skip to end of opening tag, check for self-closing
               while I <= Input'Last and then Input (I) /= '>' loop
                  pragma Loop_Variant (Increases => I);
                  pragma Loop_Invariant (I <= Input'Last + 1);

                  --  Check for self-closing
                  if Input (I) = '/'
                    and then I + 1 <= Input'Last
                    and then Input (I + 1) = '>'
                  then
                     Depth :=
                       Depth - 1;  -- Self-closing doesn't increase depth
                     if Depth = 0 then
                        Inside_Root := False;
                     end if;
                  end if;

                  I := I + 1;
               end loop;
            end if;

         elsif not Is_Whitespace (C) and then not Inside_Root then
            --  Non-whitespace content outside root element
            return False;
         end if;

         I := I + 1;
      end loop;

      --  Valid structure: all tags closed, saw exactly one root
      return Depth = 0 and then Seen_Root;
   end Has_Valid_Structure;

   function Has_No_Disallowed_Constructs (Input : String) return Boolean is
   begin
      return
        No_Attributes (Input)
        and then No_Processing_Instructions (Input)
        and then No_DTD (Input)
        and then No_CDATA (Input)
        and then No_Comments (Input)
        and then No_Namespaces (Input);
   end Has_No_Disallowed_Constructs;

   function Has_Valid_Entities (Input : String) return Boolean is
   begin
      --  Delegate to SML.Entities which implements the actual validation
      return SML.Entities.All_Entities_Valid (Input);
   end Has_Valid_Entities;

   ---------------------------------------------------------------------------
   --  Detailed Ghost Predicates
   ---------------------------------------------------------------------------

   function No_Attributes (Input : String) return Boolean is
   begin
      --  Look for attribute patterns (space after tag name before >)
      if Input'Length >= 2 then
         for I in Input'First .. Input'Last - 1 loop
            if Input (I) = '<' and then I + 1 <= Input'Last then
               --  Inside a tag - look for attributes
               for J in I + 1 .. Input'Last loop
                  if Input (J) = '>' then
                     exit;  -- End of tag
                  elsif Input (J) = '=' then
                     return False;  -- Found attribute assignment
                  end if;
               end loop;
            end if;
         end loop;
      end if;

      return True;
   end No_Attributes;

   function No_Processing_Instructions (Input : String) return Boolean is
   begin
      if Input'Length >= 2 then
         for I in Input'First .. Input'Last - 1 loop
            if Input (I) = '<' and then Input (I + 1) = '?' then
               return False;
            end if;
         end loop;
      end if;

      return True;
   end No_Processing_Instructions;

   function No_DTD (Input : String) return Boolean is
   begin
      if Input'Length >= 9 then
         --  "<!DOCTYPE" is 9 characters
         for I in Input'First .. Input'Last - 8 loop
            if Input (I .. I + 8) = "<!DOCTYPE" then
               return False;
            end if;
         end loop;
      end if;

      return True;
   end No_DTD;

   function No_CDATA (Input : String) return Boolean is
   begin
      if Input'Length >= 9 then
         --  "<![CDATA[" is 9 characters
         for I in Input'First .. Input'Last - 8 loop
            if Input (I .. I + 8) = "<![CDATA[" then
               return False;
            end if;
         end loop;
      end if;

      return True;
   end No_CDATA;

   function No_Comments (Input : String) return Boolean is
   begin
      if Input'Length >= 4 then
         --  "<!--" is 4 characters
         for I in Input'First .. Input'Last - 3 loop
            if Input (I .. I + 3) = "<!--" then
               return False;
            end if;
         end loop;
      end if;

      return True;
   end No_Comments;

   function No_Namespaces (Input : String) return Boolean is
   begin
      --  Look for xmlns attributes or colons in tag names
      for I in Input'First .. Input'Last loop
         if Input (I) = '<' and then I + 5 <= Input'Last then
            for J in I + 1 .. Input'Last loop
               if Input (J) = '>' then
                  exit;
               elsif Input (J) = ':' then
                  return False;  -- Found namespace prefix
               end if;
            end loop;
         end if;
      end loop;

      return True;
   end No_Namespaces;

   ---------------------------------------------------------------------------
   --  Parser State Ghost Functions
   ---------------------------------------------------------------------------

   function Initial_State return Parser_State is
   begin
      return
        (Position     => 0,
         Stack_Depth  => 0,
         Current_Node => Null_Node,
         Has_Error    => False);
   end Initial_State;

   function Parse_Step
     (State : Parser_State; Input : String; Start_Pos, End_Pos : Natural)
      return Parser_State
   is
      pragma Unreferenced (Input, Start_Pos, End_Pos);
      New_State : constant Parser_State := State;
   begin
      --  Ghost function for specification
      return New_State;
   end Parse_Step;

   function Is_Complete_Parse
     (State : Parser_State; Input : String) return Boolean
   is
      pragma Unreferenced (Input);
   begin
      return State.Stack_Depth = 0 and then not State.Has_Error;
   end Is_Complete_Parse;

   function Partial_DOM (State : Parser_State) return Document is
      pragma Unreferenced (State);
   begin
      --  Ghost function - not callable at runtime
      --  Limited types cannot be returned by value in implementations
      return
        raise Program_Error
          with "Ghost function Partial_DOM is not implemented";
   end Partial_DOM;

   function Is_Valid_Partial_State (State : Parser_State) return Boolean is
   begin
      return not State.Has_Error and then State.Stack_Depth <= Max_Tree_Depth;
   end Is_Valid_Partial_State;

end SML.DOM.Parser.Proof;
