------------------------------------------------------------------------------
--  SML.DOM.Parser Package Body
--  Parser Implementation for Simple Markup Language (SML)
--  SPARK Ada Implementation with Formal Verification Support
--  Child Package with Privileged Access to DOM Internals
------------------------------------------------------------------------------

with SML.UTF8;
with SML.Entities;
with SML.Memory_Model;
use type SML.Memory_Model.Node_Kind;

package body SML.DOM.Parser
  with SPARK_Mode => On
is

   ---------------------------------------------------------------------------
   --  Internal Types and Constants
   ---------------------------------------------------------------------------

   --  Maximum tag name length (for stack allocation)
   Max_Tag_Name_Length : constant := 100;

   --  Exception for carrying parse error information
   Parse_Failed : exception;

   --  Element stack entry for tracking open tags
   type Element_Stack_Entry is record
      Name         : String (1 .. Max_Tag_Name_Length);
      Name_Length  : Natural;
      Node         : Node_Id;              -- This element's node index
      Last_Child   : Node_Id;        -- Last child added (for sibling linking)
      Num_Children : Natural;      -- Number of children added so far
   end record;

   --  Element stack for tree building
   type Element_Stack is array (1 .. Max_Tree_Depth) of Element_Stack_Entry;

   --  Parser state for tracking position and context (no access types)
   type Parser_Context (Input_First, Input_Last : Natural) is record
      Position    : Natural;
      Line        : Positive;
      Column      : Positive;
      Stack       : Element_Stack;
      Stack_Depth : Natural;
   end record;

   ---------------------------------------------------------------------------
   --  Helper Functions for Character Classification
   ---------------------------------------------------------------------------

   --  Check if character is XML whitespace
   function Is_Whitespace (C : Character) return Boolean
   is (C = ' ' or else C = ASCII.HT or else C = ASCII.CR or else C = ASCII.LF)
   with Inline;

   --  Check if character is valid at start of XML name
   function Is_Name_Start_Char (C : Character) return Boolean
   is ((C >= 'A' and then C <= 'Z')
       or else (C >= 'a' and then C <= 'z')
       or else C = '_'
       or else C = ':')
   with Inline;

   --  Check if character is valid in XML name
   function Is_Name_Char (C : Character) return Boolean
   is (Is_Name_Start_Char (C)
       or else (C >= '0' and then C <= '9')
       or else C = '-'
       or else C = '.')
   with Inline;

   ---------------------------------------------------------------------------
   --  Helper Functions for Error Creation
   ---------------------------------------------------------------------------

   function Make_Error
     (Kind     : Error_Kind;
      Position : Natural;
      Line     : Positive;
      Column   : Positive;
      Message  : String) return Parse_Error
   is
      Error   : Parse_Error;
      Msg_Len : constant Natural := Natural'Min (Message'Length, 256);
   begin
      Error.Kind := Kind;
      Error.Position := Position;
      Error.Line := Line;
      Error.Column := Column;
      Error.Message := (others => ' ');
      Error.Message (1 .. Msg_Len) :=
        Message (Message'First .. Message'First + Msg_Len - 1);
      Error.Msg_Length := Msg_Len;
      return Error;
   end Make_Error;

   function Make_Error_At_Context
     (Ctx : Parser_Context; Kind : Error_Kind; Message : String)
      return Parse_Error
   is (Make_Error (Kind, Ctx.Position, Ctx.Line, Ctx.Column, Message))
   with Inline;

   ---------------------------------------------------------------------------
   --  Position Tracking Helpers
   ---------------------------------------------------------------------------

   --  Advance position and update line/column
   procedure Advance
     (Input_Str : String; Ctx : in out Parser_Context; Count : Positive := 1)
   with
     Pre =>
       Ctx.Position >= Input_Str'First
       and then Ctx.Position <= Input_Str'Last + 1
       and then Ctx.Position <= Natural'Last - Count,
     Post =>
       Ctx.Position <= Ctx.Position'Old + Count
       and then Ctx.Position <= Input_Str'Last + 1
   is
   begin
      for I in 1 .. Count loop
         pragma Loop_Variant (Increases => I);
         pragma Loop_Invariant (Ctx.Position <= Input_Str'Last + 1);
         pragma Loop_Invariant (Ctx.Position >= Ctx.Position'Loop_Entry);

         if Ctx.Position <= Input_Str'Last then
            if Input_Str (Ctx.Position) = ASCII.LF then
               Ctx.Line := Ctx.Line + 1;
               Ctx.Column := 1;
            else
               Ctx.Column := Ctx.Column + 1;
            end if;
            Ctx.Position := Ctx.Position + 1;
         end if;
      end loop;
   end Advance;

   --  Peek at current character without advancing
   function Peek (Input_Str : String; Ctx : Parser_Context) return Character
   is (if Ctx.Position <= Input_Str'Last then Input_Str (Ctx.Position)
       else ASCII.NUL)
   with Inline;

   --  Check if at end of input
   function At_End (Input_Str : String; Ctx : Parser_Context) return Boolean
   is (Ctx.Position > Input_Str'Last)
   with Inline;

   --  Check if we can look ahead N characters
   function Can_Lookahead
     (Input_Str : String; Ctx : Parser_Context; N : Positive) return Boolean
   is (Ctx.Position + N - 1 <= Input_Str'Last)
   with Inline;

   ---------------------------------------------------------------------------
   --  Whitespace Handling
   ---------------------------------------------------------------------------

   --  Skip whitespace and update position
   procedure Skip_Whitespace (Input_Str : String; Ctx : in out Parser_Context)
   with
     Pre =>
       Ctx.Position >= Input_Str'First
       and then Ctx.Position <= Input_Str'Last + 1,
     Post =>
       Ctx.Position >= Ctx.Position'Old
       and then Ctx.Position <= Input_Str'Last + 1
       and then (Ctx.Position > Input_Str'Last
                 or else not Is_Whitespace (Input_Str (Ctx.Position)))
   is
   begin
      while not At_End (Input_Str, Ctx)
        and then Is_Whitespace (Peek (Input_Str, Ctx))
      loop
         pragma Loop_Variant (Increases => Ctx.Position);
         pragma Loop_Invariant (Ctx.Position >= Input_Str'First);
         pragma Loop_Invariant (Ctx.Position <= Input_Str'Last + 1);

         Advance (Input_Str, Ctx);
      end loop;
   end Skip_Whitespace;

   ---------------------------------------------------------------------------
   --  Tag Name Parsing
   ---------------------------------------------------------------------------

   --  Result type for name parsing
   type Parse_Name_Result is record
      Success     : Boolean;
      Name        : String (1 .. Max_Tag_Name_Length);
      Name_Length : Natural;
   end record;

   --  Parse an element name (procedure for SPARK compliance)
   procedure Parse_Name
     (Input_Str  : String;
      Ctx        : in out Parser_Context;
      Max_Length : Natural;
      Result     : out Parse_Name_Result)
   with
     Pre =>
       Ctx.Position >= Input_Str'First
       and then Ctx.Position <= Input_Str'Last + 1
       and then Max_Length <= Max_Tag_Name_Length,
     Post =>
       Ctx.Position >= Ctx.Position'Old
       and then Ctx.Position <= Input_Str'Last + 1
       and then Result.Name_Length <= Max_Length
       and then (if Result.Success then Result.Name_Length > 0)
   is
      C : Character;
   begin
      Result.Success := False;
      Result.Name_Length := 0;
      Result.Name := (others => ' ');

      --  First character must be name start char
      if At_End (Input_Str, Ctx)
        or else not Is_Name_Start_Char (Peek (Input_Str, Ctx))
      then
         return;
      end if;

      --  Collect name characters
      while not At_End (Input_Str, Ctx)
        and then Result.Name_Length < Max_Length
      loop
         pragma Loop_Variant (Increases => Ctx.Position);
         pragma Loop_Invariant (Ctx.Position >= Input_Str'First);
         pragma Loop_Invariant (Ctx.Position <= Input_Str'Last + 1);
         pragma Loop_Invariant (Result.Name_Length <= Max_Length);
         pragma Loop_Invariant (Result.Name_Length < Max_Length);

         C := Peek (Input_Str, Ctx);

         if not Is_Name_Char (C) then
            exit;
         end if;

         Result.Name_Length := Result.Name_Length + 1;
         Result.Name (Result.Name_Length) := C;
         Advance (Input_Str, Ctx);
      end loop;

      Result.Success := (Result.Name_Length > 0);
   end Parse_Name;

   ---------------------------------------------------------------------------
   --  Tag Parsing
   ---------------------------------------------------------------------------

   --  Result type for tag parsing
   type Parse_Tag_Result is record
      Success          : Boolean;
      Is_Empty_Element : Boolean;  -- For <name/> self-closing tags
      Is_Closing       : Boolean;         -- For </name> closing tags
      Name             : String (1 .. Max_Tag_Name_Length);
      Name_Length      : Natural;
      Err_Kind         : Error_Kind;
      Error_Msg        : String (1 .. 256);
      Error_Msg_Len    : Natural;
   end record;

   --  Helper to safely copy error message
   procedure Set_Error_Message (Target : in out Parse_Tag_Result; Msg : String)
   is
      Len : constant Natural := Natural'Min (Msg'Length, 256);
   begin
      Target.Error_Msg := (others => ' ');
      Target.Error_Msg (1 .. Len) := Msg (Msg'First .. Msg'First + Len - 1);
      Target.Error_Msg_Len := Len;
   end Set_Error_Message;

   --  Parse opening tag <name> or <name/> or closing tag </name>
   procedure Parse_Tag
     (Input_Str : String;
      Ctx       : in out Parser_Context;
      Result    : out Parse_Tag_Result)
   with
     Pre =>
       Ctx.Position >= Input_Str'First
       and then Ctx.Position <= Input_Str'Last + 1,
     Post =>
       Ctx.Position >= Ctx.Position'Old
       and then Ctx.Position <= Input_Str'Last + 1
       and then (if Result.Success
                 then
                   Result.Name_Length > 0
                   and then Result.Name_Length <= Max_Tag_Name_Length)
   is
      C           : Character;
      Name_Result : Parse_Name_Result;
   begin
      Result.Success := False;
      Result.Is_Empty_Element := False;
      Result.Is_Closing := False;
      Result.Name := (others => ' ');
      Result.Name_Length := 0;
      Result.Err_Kind := Malformed_Structure;  -- Default error kind
      Result.Error_Msg := (others => ' ');
      Result.Error_Msg_Len := 0;

      --  Must start with <
      if At_End (Input_Str, Ctx) or else Peek (Input_Str, Ctx) /= '<' then
         Result.Err_Kind := Malformed_Structure;
         Set_Error_Message (Result, "Expected '<' to start tag");
         return;
      end if;

      Advance (Input_Str, Ctx);  -- consume '<'

      --  Check for closing tag </
      if not At_End (Input_Str, Ctx) and then Peek (Input_Str, Ctx) = '/' then
         Result.Is_Closing := True;
         Advance (Input_Str, Ctx);  -- consume '/'

      end if;

      --  Check for disallowed constructs
      if not At_End (Input_Str, Ctx) then
         C := Peek (Input_Str, Ctx);

         if C = '?' then
            Result.Err_Kind := Disallowed_Construct;
            Set_Error_Message
              (Result, "Processing instructions not allowed in SML");
            return;
         elsif C = '!' then
            Result.Err_Kind := Disallowed_Construct;
            if Can_Lookahead (Input_Str, Ctx, 3)
              and then Input_Str (Ctx.Position + 1 .. Ctx.Position + 2) = "--"
            then
               Set_Error_Message (Result, "Comments not allowed in SML");
            elsif Can_Lookahead (Input_Str, Ctx, 7)
              and then Input_Str (Ctx.Position .. Ctx.Position + 6) = "![CDATA"
            then
               Set_Error_Message (Result, "CDATA sections not allowed in SML");
            elsif Can_Lookahead (Input_Str, Ctx, 8)
              and then Input_Str (Ctx.Position .. Ctx.Position + 7)
                       = "!DOCTYPE"
            then
               Set_Error_Message
                 (Result, "DOCTYPE declarations not allowed in SML");
            else
               Set_Error_Message (Result, "Invalid declaration in SML");
            end if;
            return;
         end if;
      end if;

      --  Parse tag name
      Parse_Name (Input_Str, Ctx, Max_Tag_Name_Length, Name_Result);

      if not Name_Result.Success or else Name_Result.Name_Length = 0 then
         Result.Err_Kind := Malformed_Structure;
         Set_Error_Message (Result, "Invalid or missing element name");
         return;
      end if;

      Result.Name := Name_Result.Name;
      Result.Name_Length := Name_Result.Name_Length;

      --  Skip whitespace after name
      Skip_Whitespace (Input_Str, Ctx);

      --  Check for attributes (not allowed in SML)
      if not At_End (Input_Str, Ctx)
        and then Peek (Input_Str, Ctx) /= '>'
        and then Peek (Input_Str, Ctx) /= '/'
      then
         Result.Err_Kind := Disallowed_Construct;
         Set_Error_Message (Result, "Attributes not allowed in SML");
         return;
      end if;

      --  Check for self-closing tag
      if not At_End (Input_Str, Ctx) and then Peek (Input_Str, Ctx) = '/' then
         if Result.Is_Closing then
            Result.Err_Kind := Malformed_Structure;
            Set_Error_Message (Result, "Invalid tag syntax: </name/>");
            return;
         end if;
         Result.Is_Empty_Element := True;
         Advance (Input_Str, Ctx);  -- consume '/'

      end if;

      --  Must end with >
      if At_End (Input_Str, Ctx) or else Peek (Input_Str, Ctx) /= '>' then
         Result.Err_Kind := Malformed_Structure;
         Set_Error_Message (Result, "Expected '>' to close tag");
         return;
      end if;

      Advance (Input_Str, Ctx);  -- consume '>'
      Result.Success := True;
   end Parse_Tag;

   ---------------------------------------------------------------------------
   --  Tag Matching Helper
   ---------------------------------------------------------------------------

   --  Compare two tag names for equality
   function Tags_Match
     (Name1 : String; Len1 : Natural; Name2 : String; Len2 : Natural)
      return Boolean
   with Pre => Len1 <= Name1'Length and then Len2 <= Name2'Length
   is
   begin
      if Len1 /= Len2 then
         return False;
      end if;

      for I in 1 .. Len1 loop
         pragma Loop_Invariant (I <= Len1);
         if Name1 (Name1'First + I - 1) /= Name2 (Name2'First + I - 1) then
            return False;
         end if;
      end loop;

      return True;
   end Tags_Match;

   ---------------------------------------------------------------------------
   --  Node Linking Helpers
   ---------------------------------------------------------------------------

   --  Link a child node to its parent
   procedure Link_Child_To_Parent
     (Doc          : in out Document;
      Parent_Index : SML.Memory_Model.Node_Index;
      Child_Index  : SML.Memory_Model.Node_Index;
      Is_First     : Boolean)
   with
     Pre =>
       SML.Memory_Model.Valid_Node_Index (Doc.Pool, Parent_Index)
       and then SML.Memory_Model.Valid_Node_Index (Doc.Pool, Child_Index)
   is
      Parent_Node : SML.Memory_Model.Node :=
        SML.Memory_Model.Get_Node (Doc.Pool, Parent_Index);
      Child_Node  : SML.Memory_Model.Node :=
        SML.Memory_Model.Get_Node (Doc.Pool, Child_Index);
   begin
      --  Set child's parent
      Child_Node.Parent_Index := Parent_Index;

      if Is_First then
         --  This is the first child
         Parent_Node.First_Child_Index := Child_Index;
         Child_Node.Next_Sibling_Index := SML.Memory_Model.No_Node_Index;
      else
         --  Link as next sibling (caller must have updated prev sibling)
         Child_Node.Next_Sibling_Index := SML.Memory_Model.No_Node_Index;
      end if;

      --  Increment parent's child count
      if Parent_Node.Kind = SML.Memory_Model.Element then
         Parent_Node.Num_Children := Parent_Node.Num_Children + 1;
      end if;

      --  Store updated nodes
      SML.Memory_Model.Set_Node (Doc.Pool, Parent_Index, Parent_Node);
      SML.Memory_Model.Set_Node (Doc.Pool, Child_Index, Child_Node);
   end Link_Child_To_Parent;

   --  Update previous sibling's Next_Sibling_Index
   procedure Link_Siblings
     (Doc                : in out Document;
      Prev_Sibling_Index : SML.Memory_Model.Node_Index;
      Next_Sibling_Index : SML.Memory_Model.Node_Index)
   with
     Pre =>
       SML.Memory_Model.Valid_Node_Index (Doc.Pool, Prev_Sibling_Index)
       and then SML.Memory_Model.Valid_Node_Index
                  (Doc.Pool, Next_Sibling_Index)
   is
      Prev_Node : SML.Memory_Model.Node :=
        SML.Memory_Model.Get_Node (Doc.Pool, Prev_Sibling_Index);
   begin
      Prev_Node.Next_Sibling_Index := Next_Sibling_Index;
      SML.Memory_Model.Set_Node (Doc.Pool, Prev_Sibling_Index, Prev_Node);
   end Link_Siblings;

   ---------------------------------------------------------------------------
   --  Text Content Parsing
   ---------------------------------------------------------------------------

   --  Result type for text content parsing
   type Parse_Text_Result is record
      Success      : Boolean;
      Has_Content  : Boolean;  -- True if non-whitespace content found
      Start_Pos    : Natural;    -- Start of text in input
      End_Pos      : Natural;      -- End of text in input
      Has_Entities : Boolean; -- True if text contains entity references
   end record;

   --  Parse text content until we hit '<'
   --  Returns position information (caller handles allocation)
   procedure Parse_Text_Content
     (Input_Str : String;
      Ctx       : in out Parser_Context;
      Result    : out Parse_Text_Result)
   with
     Pre =>
       Ctx.Position >= Input_Str'First
       and then Ctx.Position <= Input_Str'Last + 1,
     Post =>
       Ctx.Position >= Ctx.Position'Old
       and then Ctx.Position <= Input_Str'Last + 1
       and then (if Result.Success and then Result.Has_Content
                 then
                   Result.Start_Pos >= Input_Str'First
                   and then Result.End_Pos <= Input_Str'Last
                   and then Result.Start_Pos <= Result.End_Pos)
   is
      Start      : constant Natural := Ctx.Position;
      Has_Non_WS : Boolean := False;
   begin
      Result.Success := False;
      Result.Has_Content := False;
      Result.Start_Pos := Start;
      Result.End_Pos := Start;
      Result.Has_Entities := False;

      --  Collect text until we see '<'
      while not At_End (Input_Str, Ctx) and then Peek (Input_Str, Ctx) /= '<'
      loop
         pragma Loop_Variant (Increases => Ctx.Position);
         pragma Loop_Invariant (Ctx.Position >= Start);
         pragma Loop_Invariant (Ctx.Position <= Input_Str'Last + 1);

         declare
            C : constant Character := Peek (Input_Str, Ctx);
         begin
            --  Check for entity reference
            if C = '&' then
               Result.Has_Entities := True;
            end if;

            --  Check for non-whitespace
            if not Is_Whitespace (C) then
               Has_Non_WS := True;
            end if;

            Advance (Input_Str, Ctx);
         end;
      end loop;

      --  Set result
      if Ctx.Position > Start then
         Result.End_Pos := Ctx.Position - 1;
         Result.Has_Content := Has_Non_WS;
         Result.Success := True;
      end if;
   end Parse_Text_Content;

   ---------------------------------------------------------------------------
   --  Main Parsing Functions
   ---------------------------------------------------------------------------

   function Parse (Input : String) return Parse_Result is
      Default_Options : constant Parse_Options :=
        (Whitespace      => Preserve_All,
         Expand_Entities => True,
         Max_Depth       => Max_Tree_Depth);
   begin
      return Parse_With_Options (Input, Default_Options);
   end Parse;

   function Validate (Input : String) return Boolean is
      Result : constant Parse_Result := Parse (Input);
   begin
      return Result.Success;
   end Validate;

   function Parse_With_Options
     (Input : String; Options : Parse_Options) return Parse_Result
   is
      pragma Unreferenced (Options);

      --  Local variable for error info (avoids global state)
      Local_Error : Parse_Error;

      --  Helper procedure to build DOM (avoids extended return scope issues)
      procedure Build_DOM
        (Input_Str  : String;
         Doc        : in out Document;
         Had_Error  : out Boolean;
         Error_Info : out Parse_Error)
      is
         Ctx : Parser_Context (Input_Str'First, Input_Str'Last) :=
           (Input_First => Input_Str'First,
            Input_Last  => Input_Str'Last,
            Position    => Input_Str'First,
            Line        => 1,
            Column      => 1,
            Stack_Depth => 0,
            Stack       =>
              (others => (Name         => (others => ' '),
                          Name_Length  => 0,
                          Node         => Null_Node,
                          Last_Child   => Null_Node,
                          Num_Children => 0)));
         Tag_Result : Parse_Tag_Result;
         Root_Index : SML.Memory_Model.Node_Index;
         Name_Ref   : SML.Memory_Model.String_Ref;
      begin
         Had_Error := False;

         --  Initialize Error_Info (only used if Had_Error becomes True)
         Error_Info :=
           (Kind       => Malformed_Structure,
            Position   => 0,
            Line       => 1,
            Column     => 1,
            Message    => (others => ' '),
            Msg_Length => 0);

         --  Initialize arena pool
         SML.Memory_Model.Reset_Arena (Doc.Pool);

         --  Skip leading whitespace
         Skip_Whitespace (Input_Str, Ctx);

         --  Parse root element opening tag
         Parse_Tag (Input_Str, Ctx, Tag_Result);

         if not Tag_Result.Success then
            Had_Error := True;
            Error_Info :=
              Make_Error
                (Kind     => Tag_Result.Err_Kind,
                 Position => Ctx.Position,
                 Line     => Ctx.Line,
                 Column   => Ctx.Column,
                 Message  =>
                   Tag_Result.Error_Msg (1 .. Tag_Result.Error_Msg_Len));
            return;
         end if;

         --  Check for closing tag at root
         if Tag_Result.Is_Closing then
            Had_Error := True;
            Error_Info :=
              Make_Error
                (Kind     => Malformed_Structure,
                 Position => Ctx.Position,
                 Line     => Ctx.Line,
                 Column   => Ctx.Column,
                 Message  => "Document starts with closing tag");
            return;
         end if;

         --  Allocate root element node
         if not SML.Memory_Model.Can_Allocate_Node (Doc.Pool) then
            Had_Error := True;
            Error_Info :=
              Make_Error
                (Kind     => Malformed_Structure,
                 Position => Ctx.Position,
                 Line     => Ctx.Line,
                 Column   => Ctx.Column,
                 Message  =>
                   "Node limit reached. Increase stack or see SML.Memory_Model");
            return;
         end if;

         SML.Memory_Model.Allocate_Node
           (Doc.Pool, SML.Memory_Model.Element, Root_Index);

         --  Allocate and store element name
         declare
            Tag_Name : constant String :=
              Tag_Result.Name (1 .. Tag_Result.Name_Length);
         begin
            if not SML.Memory_Model.Can_Allocate_String
                     (Doc.Pool, Tag_Name'Length)
            then
               Had_Error := True;
               Error_Info :=
                 Make_Error
                   (Kind     => Malformed_Structure,
                    Position => Ctx.Position,
                    Line     => Ctx.Line,
                    Column   => Ctx.Column,
                    Message  =>
                      "String limit reached. Increase stack or see SML.Memory_Model");
               return;
            end if;

            SML.Memory_Model.Allocate_String (Doc.Pool, Tag_Name, Name_Ref);
            SML.Memory_Model.Store_String (Doc.Pool, Name_Ref, Tag_Name);
         end;

         --  Initialize root node
         declare
            Root_Node : SML.Memory_Model.Node (SML.Memory_Model.Element);
         begin
            Root_Node.Parent_Index := SML.Memory_Model.No_Node_Index;
            Root_Node.First_Child_Index := SML.Memory_Model.No_Node_Index;
            Root_Node.Next_Sibling_Index := SML.Memory_Model.No_Node_Index;
            Root_Node.Element_Name_Ref := Name_Ref;
            Root_Node.Num_Children := 0;

            SML.Memory_Model.Set_Node (Doc.Pool, Root_Index, Root_Node);
         end;

         --  Set document root (we have privileged access as child package!)
         Doc.Root_Node := Node_Id (Root_Index);
         Doc.Total_Nodes := 1;

         --  Handle self-closing root element
         if Tag_Result.Is_Empty_Element then
            --  Self-closing root - verify no trailing content
            Skip_Whitespace (Input_Str, Ctx);
            if not At_End (Input_Str, Ctx) then
               Had_Error := True;
               Error_Info :=
                 Make_Error
                   (Kind     => Malformed_Structure,
                    Position => Ctx.Position,
                    Line     => Ctx.Line,
                    Column   => Ctx.Column,
                    Message  => "Content after self-closing root element");
            end if;
            return;
         end if;

         --  Push root to element stack for content parsing
         Ctx.Stack_Depth := 1;
         Ctx.Stack (1).Name := Tag_Result.Name;
         Ctx.Stack (1).Name_Length := Tag_Result.Name_Length;
         Ctx.Stack (1).Node := Node_Id (Root_Index);
         Ctx.Stack (1).Last_Child := Null_Node;
         Ctx.Stack (1).Num_Children := 0;

         --  Main parse loop - iterative stack-based parsing
         declare
            Max_Iterations : constant Natural := Input_Str'Length * 2;
            Iterations     : Natural := 0;
         begin
            while Ctx.Stack_Depth > 0 and then Iterations < Max_Iterations loop
               pragma Loop_Variant (Increases => Iterations);
               pragma Loop_Invariant (Ctx.Stack_Depth <= Max_Tree_Depth);
               pragma Loop_Invariant (Ctx.Stack_Depth >= 0);
               pragma Loop_Invariant (Ctx.Position <= Input_Str'Last + 1);
               pragma Loop_Invariant (Doc.Total_Nodes >= 1);

               Iterations := Iterations + 1;

               --  Check for tag or text content
               if not At_End (Input_Str, Ctx)
                 and then Peek (Input_Str, Ctx) = '<'
               then
                  --  Parse tag (opening or closing)
                  Parse_Tag (Input_Str, Ctx, Tag_Result);

                  if not Tag_Result.Success then
                     Had_Error := True;
                     Error_Info :=
                       Make_Error
                         (Kind     => Tag_Result.Err_Kind,
                          Position => Ctx.Position,
                          Line     => Ctx.Line,
                          Column   => Ctx.Column,
                          Message  =>
                            Tag_Result.Error_Msg
                              (1 .. Tag_Result.Error_Msg_Len));
                     return;
                  end if;

                  if Tag_Result.Is_Closing then
                     --  Closing tag - must match stack top
                     if Ctx.Stack_Depth = 0 then
                        Had_Error := True;
                        Error_Info :=
                          Make_Error
                            (Kind     => Malformed_Structure,
                             Position => Ctx.Position,
                             Line     => Ctx.Line,
                             Column   => Ctx.Column,
                             Message  => "Unexpected closing tag");
                        return;
                     end if;

                     --  Verify tag name matches
                     if not Tags_Match
                              (Ctx.Stack (Ctx.Stack_Depth).Name,
                               Ctx.Stack (Ctx.Stack_Depth).Name_Length,
                               Tag_Result.Name,
                               Tag_Result.Name_Length)
                     then
                        Had_Error := True;
                        Error_Info :=
                          Make_Error
                            (Kind     => Malformed_Structure,
                             Position => Ctx.Position,
                             Line     => Ctx.Line,
                             Column   => Ctx.Column,
                             Message  => "Mismatched closing tag");
                        return;
                     end if;

                     --  Pop stack
                     Ctx.Stack_Depth := Ctx.Stack_Depth - 1;

                  else
                     --  Opening tag - create child element
                     --  Check depth limit
                     if Ctx.Stack_Depth >= Max_Tree_Depth then
                        Had_Error := True;
                        Error_Info :=
                          Make_Error
                            (Kind     => Depth_Exceeded,
                             Position => Ctx.Position,
                             Line     => Ctx.Line,
                             Column   => Ctx.Column,
                             Message  => "Maximum tree depth exceeded");
                        return;
                     end if;

                     --  Check child count limit for parent
                     if Ctx.Stack (Ctx.Stack_Depth).Num_Children
                       >= Max_Children
                     then
                        Had_Error := True;
                        Error_Info :=
                          Make_Error
                            (Kind     => Too_Many_Children,
                             Position => Ctx.Position,
                             Line     => Ctx.Line,
                             Column   => Ctx.Column,
                             Message  => "Too many children for element");
                        return;
                     end if;

                     --  Allocate child node
                     if not SML.Memory_Model.Can_Allocate_Node (Doc.Pool) then
                        Had_Error := True;
                        Error_Info :=
                          Make_Error
                            (Kind     => Malformed_Structure,
                             Position => Ctx.Position,
                             Line     => Ctx.Line,
                             Column   => Ctx.Column,
                             Message  =>
                               "Node limit reached. Increase stack or see SML.Memory_Model");
                        return;
                     end if;

                     declare
                        Child_Index    : SML.Memory_Model.Node_Index;
                        Child_Name_Ref : SML.Memory_Model.String_Ref;
                        Child_Tag_Name : constant String :=
                          Tag_Result.Name (1 .. Tag_Result.Name_Length);
                     begin
                        SML.Memory_Model.Allocate_Node
                          (Doc.Pool, SML.Memory_Model.Element, Child_Index);

                        --  Allocate and store child name
                        if not SML.Memory_Model.Can_Allocate_String
                                 (Doc.Pool, Child_Tag_Name'Length)
                        then
                           Had_Error := True;
                           Error_Info :=
                             Make_Error
                               (Kind     => Malformed_Structure,
                                Position => Ctx.Position,
                                Line     => Ctx.Line,
                                Column   => Ctx.Column,
                                Message  =>
                                  "String limit reached. Increase stack or see SML.Memory_Model");
                           return;
                        end if;

                        SML.Memory_Model.Allocate_String
                          (Doc.Pool, Child_Tag_Name, Child_Name_Ref);
                        SML.Memory_Model.Store_String
                          (Doc.Pool, Child_Name_Ref, Child_Tag_Name);

                        --  Initialize child node
                        declare
                           Child_Node     :
                             SML.Memory_Model.Node (SML.Memory_Model.Element);
                           Parent_Index   :
                             constant SML.Memory_Model.Node_Index :=
                               SML.Memory_Model.Node_Index
                                 (Ctx.Stack (Ctx.Stack_Depth).Node);
                           Is_First_Child : constant Boolean :=
                             (Ctx.Stack (Ctx.Stack_Depth).Num_Children = 0);
                        begin
                           Child_Node.Parent_Index := Parent_Index;
                           Child_Node.First_Child_Index :=
                             SML.Memory_Model.No_Node_Index;
                           Child_Node.Next_Sibling_Index :=
                             SML.Memory_Model.No_Node_Index;
                           Child_Node.Element_Name_Ref := Child_Name_Ref;
                           Child_Node.Num_Children := 0;

                           SML.Memory_Model.Set_Node
                             (Doc.Pool, Child_Index, Child_Node);

                           --  Link to parent
                           Link_Child_To_Parent
                             (Doc, Parent_Index, Child_Index, Is_First_Child);

                           --  Link to previous sibling if not first
                           if not Is_First_Child then
                              Link_Siblings
                                (Doc,
                                 SML.Memory_Model.Node_Index
                                   (Ctx.Stack (Ctx.Stack_Depth).Last_Child),
                                 Child_Index);
                           end if;

                           --  Update stack tracking
                           Ctx.Stack (Ctx.Stack_Depth).Last_Child :=
                             Node_Id (Child_Index);
                           Ctx.Stack (Ctx.Stack_Depth).Num_Children :=
                             Ctx.Stack (Ctx.Stack_Depth).Num_Children + 1;

                           Doc.Total_Nodes := Doc.Total_Nodes + 1;

                           --  Push to stack if not self-closing
                           if not Tag_Result.Is_Empty_Element then
                              Ctx.Stack_Depth := Ctx.Stack_Depth + 1;
                              Ctx.Stack (Ctx.Stack_Depth).Name :=
                                Tag_Result.Name;
                              Ctx.Stack (Ctx.Stack_Depth).Name_Length :=
                                Tag_Result.Name_Length;
                              Ctx.Stack (Ctx.Stack_Depth).Node :=
                                Node_Id (Child_Index);
                              Ctx.Stack (Ctx.Stack_Depth).Last_Child :=
                                Null_Node;
                              Ctx.Stack (Ctx.Stack_Depth).Num_Children := 0;
                           end if;
                        end;
                     end;
                  end if;

               else
                  --  Text content - parse and allocate text node
                  declare
                     Text_Result : Parse_Text_Result;
                  begin
                     Parse_Text_Content (Input_Str, Ctx, Text_Result);

                     --  Only create text node if there's actual content
                     if Text_Result.Success and then Text_Result.Has_Content
                     then
                        --  Extract and expand text
                        declare
                           Raw_Text      : constant String :=
                             Input_Str
                               (Text_Result.Start_Pos .. Text_Result.End_Pos);
                           Expanded_Text : constant String :=
                             SML.Entities.Expand_Entities (Raw_Text);
                        begin
                           --  Allocate text node
                           if not SML.Memory_Model.Can_Allocate_Node (Doc.Pool)
                           then
                              Had_Error := True;
                              Error_Info :=
                                Make_Error
                                  (Kind     => Malformed_Structure,
                                   Position => Ctx.Position,
                                   Line     => Ctx.Line,
                                   Column   => Ctx.Column,
                                   Message  =>
                                     "Node limit reached. Increase stack or see SML.Memory_Model");
                              return;
                           end if;

                           declare
                              Text_Index     : SML.Memory_Model.Node_Index;
                              Text_Ref       : SML.Memory_Model.String_Ref;
                              Parent_Index   :
                                constant SML.Memory_Model.Node_Index :=
                                  SML.Memory_Model.Node_Index
                                    (Ctx.Stack (Ctx.Stack_Depth).Node);
                              Is_First_Child : constant Boolean :=
                                (Ctx.Stack (Ctx.Stack_Depth).Num_Children = 0);
                           begin
                              SML.Memory_Model.Allocate_Node
                                (Doc.Pool, SML.Memory_Model.Text, Text_Index);

                              --  Allocate and store text content
                              if not SML.Memory_Model.Can_Allocate_String
                                       (Doc.Pool, Expanded_Text'Length)
                              then
                                 Had_Error := True;
                                 Error_Info :=
                                   Make_Error
                                     (Kind     => Malformed_Structure,
                                      Position => Ctx.Position,
                                      Line     => Ctx.Line,
                                      Column   => Ctx.Column,
                                      Message  =>
                                        "String limit reached. Increase stack or see SML.Memory_Model");
                                 return;
                              end if;

                              SML.Memory_Model.Allocate_String
                                (Doc.Pool, Expanded_Text, Text_Ref);
                              SML.Memory_Model.Store_String
                                (Doc.Pool, Text_Ref, Expanded_Text);

                              --  Initialize text node
                              declare
                                 Text_Node :
                                   SML.Memory_Model.Node
                                     (SML.Memory_Model.Text);
                              begin
                                 Text_Node.Parent_Index := Parent_Index;
                                 Text_Node.First_Child_Index :=
                                   SML.Memory_Model.No_Node_Index;
                                 Text_Node.Next_Sibling_Index :=
                                   SML.Memory_Model.No_Node_Index;
                                 Text_Node.Text_Content_Ref := Text_Ref;

                                 SML.Memory_Model.Set_Node
                                   (Doc.Pool, Text_Index, Text_Node);

                                 --  Link to parent
                                 Link_Child_To_Parent
                                   (Doc,
                                    Parent_Index,
                                    Text_Index,
                                    Is_First_Child);

                                 --  Link to previous sibling if not first
                                 if not Is_First_Child then
                                    Link_Siblings
                                      (Doc,
                                       SML.Memory_Model.Node_Index
                                         (Ctx.Stack (Ctx.Stack_Depth)
                                            .Last_Child),
                                       Text_Index);
                                 end if;

                                 --  Update stack tracking
                                 Ctx.Stack (Ctx.Stack_Depth).Last_Child :=
                                   Node_Id (Text_Index);
                                 Ctx.Stack (Ctx.Stack_Depth).Num_Children :=
                                   Ctx.Stack (Ctx.Stack_Depth).Num_Children
                                   + 1;

                                 Doc.Total_Nodes := Doc.Total_Nodes + 1;
                              end;
                           end;
                        end;
                     end if;
                  end;
               end if;

               --  Safety: if no progress, break
               if Iterations >= Max_Iterations - 1 then
                  Had_Error := True;
                  Error_Info :=
                    Make_Error
                      (Kind     => Malformed_Structure,
                       Position => Ctx.Position,
                       Line     => Ctx.Line,
                       Column   => Ctx.Column,
                       Message  => "Parse loop iteration limit exceeded");
                  return;
               end if;
            end loop;

            --  Verify all tags were closed
            if Ctx.Stack_Depth /= 0 then
               Had_Error := True;
               Error_Info :=
                 Make_Error
                   (Kind     => Malformed_Structure,
                    Position => Ctx.Position,
                    Line     => Ctx.Line,
                    Column   => Ctx.Column,
                    Message  => "Unclosed element at end of document");
               return;
            end if;

            --  Verify no trailing content
            Skip_Whitespace (Input_Str, Ctx);
            if not At_End (Input_Str, Ctx) then
               Had_Error := True;
               Error_Info :=
                 Make_Error
                   (Kind     => Malformed_Structure,
                    Position => Ctx.Position,
                    Line     => Ctx.Line,
                    Column   => Ctx.Column,
                    Message  => "Content after root element");
               return;
            end if;
         end;
      end Build_DOM;

   begin
      --  Check for empty input
      if Input'Length = 0 then
         return
           (Success => False,
            Error   =>
              Make_Error
                (Kind     => Unexpected_EOF,
                 Position => 0,
                 Line     => 1,
                 Column   => 1,
                 Message  => "Empty input document"));
      end if;

      --  Check if input is too large for current memory limits
      --  Heuristic: input should be at most 1/3 of string storage
      --  (allows for entity expansion and internal overhead)
      if Input'Length > SML.Memory_Model.Max_String_Storage / 3 then
         return
           (Success => False,
            Error   =>
              Make_Error
                (Kind     => Malformed_Structure,
                 Position => 0,
                 Line     => 1,
                 Column   => 1,
                 Message  =>
                   "Input exceeds memory limits. See SML.Memory_Model"));
      end if;

      --  Validate UTF-8 encoding
      if not SML.UTF8.Is_Valid_UTF8 (Input) then
         declare
            UTF8_Result : constant SML.UTF8.UTF8_Validation_Result :=
              SML.UTF8.Validate_UTF8 (Input);
         begin
            return
              (Success => False,
               Error   =>
                 Make_Error
                   (Kind     => Invalid_UTF8,
                    Position => UTF8_Result.Error_Position,
                    Line     => 1,
                    Column   => 1,
                    Message  => "Invalid UTF-8 encoding"));
         end;
      end if;

      --  Validate entity references
      declare
         Entity_Result : constant SML.Entities.Entity_Check_Result :=
           SML.Entities.Check_Entities (Input);
      begin
         if not Entity_Result.Valid then
            return
              (Success => False,
               Error   =>
                 Make_Error
                   (Kind     => Invalid_Entity,
                    Position => Entity_Result.Error_Position,
                    Line     => 1,
                    Column   => 1,
                    Message  => "Invalid entity reference"));
         end if;
      end;

      --  Build DOM tree with privileged access
      --  Build directly in return object due to limited type
      return Result : Parse_Result (Success => True) do
         declare
            Had_Error : Boolean := False;
            Err_Info  : Parse_Error;
         begin
            Build_DOM (Input, Result.Doc, Had_Error, Err_Info);

            if Had_Error then
               --  Store error info and raise exception to return failure result
               Local_Error := Err_Info;
               raise Parse_Failed;
            end if;
         end;
      end return;

   exception
      when Parse_Failed =>
         --  Parse failed, return error result with stored error info
         return (Success => False, Error => Local_Error);
   end Parse_With_Options;

   ---------------------------------------------------------------------------
   --  Ghost Functions for Formal Verification
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

      return True;
   end No_Attributes;

   function No_Processing_Instructions (Input : String) return Boolean is
   begin
      for I in Input'First .. Input'Last - 1 loop
         if Input (I) = '<' and then Input (I + 1) = '?' then
            return False;
         end if;
      end loop;

      return True;
   end No_Processing_Instructions;

   function No_DTD (Input : String) return Boolean is
   begin
      for I in Input'First .. Input'Last - 8 loop
         if Input (I .. I + 8) = "<!DOCTYPE" then
            return False;
         end if;
      end loop;

      return True;
   end No_DTD;

   function No_CDATA (Input : String) return Boolean is
   begin
      for I in Input'First .. Input'Last - 8 loop
         if Input (I .. I + 8) = "<![CDATA[" then
            return False;
         end if;
      end loop;

      return True;
   end No_CDATA;

   function No_Comments (Input : String) return Boolean is
   begin
      for I in Input'First .. Input'Last - 3 loop
         if Input (I .. I + 3) = "<!--" then
            return False;
         end if;
      end loop;

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
      New_State : Parser_State := State;
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

end SML.DOM.Parser;
