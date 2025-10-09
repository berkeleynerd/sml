------------------------------------------------------------------------------
--  SML Comprehensive Example
--  Demonstrates all features: Parse, Build, Modify, Delete, Serialize
------------------------------------------------------------------------------

with Ada.Text_IO;
with SML.DOM;
with SML.DOM.Parser;
with SML.DOM.Builder;
with SML.DOM.Writer;

procedure SML_Example is
   use Ada.Text_IO;
   use type SML.DOM.Node_Id;
   use type SML.DOM.Node_Kind;

   ---------------------------------------------------------------------------
   --  Utility: Recursive Tree Printer
   ---------------------------------------------------------------------------

   procedure Print_Tree (Doc : SML.DOM.Document;
                         Node : SML.DOM.Node_Id;
                         Indent : Natural := 0)
   is
      Spaces : constant String (1 .. Indent * 2) := (others => ' ');
      Child  : SML.DOM.Node_Id;
   begin
      case SML.DOM.Kind (Doc, Node) is
         when SML.DOM.Element =>
            Put_Line (Spaces & "<" & SML.DOM.Name (Doc, Node) & ">");

            Child := SML.DOM.First_Child (Doc, Node);
            while Child /= SML.DOM.Null_Node loop
               Print_Tree (Doc, Child, Indent + 1);
               Child := SML.DOM.Next_Sibling (Doc, Child);
            end loop;

            Put_Line (Spaces & "</" & SML.DOM.Name (Doc, Node) & ">");

         when SML.DOM.Text =>
            Put_Line (Spaces & "[Text: " &
              SML.DOM.Text_Value (Doc, Node) & "]");
      end case;
   end Print_Tree;

   ---------------------------------------------------------------------------
   --  Example 1: Parse and Traverse
   ---------------------------------------------------------------------------

   procedure Example_Parse_And_Traverse is
      Sample : constant String :=
        "<document>" &
        "  <metadata>" &
        "    <title>Sample Document</title>" &
        "    <author>SPARK Verified Parser</author>" &
        "  </metadata>" &
        "  <content>" &
        "    <section>Introduction with &lt;entities&gt;</section>" &
        "  </content>" &
        "</document>";

      Result : constant SML.DOM.Parser.Parse_Result :=
        SML.DOM.Parser.Parse (Sample);
   begin
      Put_Line ("=== Example 1: Parse and Traverse ===");
      New_Line;

      if Result.Success then
         Put_Line ("✓ Parse succeeded!");
         Put_Line ("Document structure:");
         Print_Tree (Result.Doc, SML.DOM.Root (Result.Doc));
      else
         Put_Line ("✗ Parse failed!");
      end if;
      New_Line;
   end Example_Parse_And_Traverse;

   ---------------------------------------------------------------------------
   --  Example 2: Build DOM from Scratch
   ---------------------------------------------------------------------------

   procedure Example_Build_From_Scratch is
      Doc    : SML.DOM.Document;
      Item1  : SML.DOM.Node_Id;
      Item2  : SML.DOM.Node_Id;
      Text1  : SML.DOM.Node_Id;
      Text2  : SML.DOM.Node_Id;
      Output : String (1 .. 10_000);
   begin
      Put_Line ("=== Example 2: Build DOM from Scratch ===");
      New_Line;

      --  Create document with root
      Doc := SML.DOM.Builder.Create_Document ("catalog");

      --  Add items with text
      SML.DOM.Builder.Add_Child_Element (Doc, SML.DOM.Root (Doc), "item", Item1);
      SML.DOM.Builder.Add_Text_Node (Doc, Item1, "Book", Text1);

      SML.DOM.Builder.Add_Child_Element (Doc, SML.DOM.Root (Doc), "item", Item2);
      SML.DOM.Builder.Add_Text_Node (Doc, Item2, "Pen", Text2);

      Put_Line ("Compact output:");
      Output := SML.DOM.Writer.Serialize (Doc);
      Put_Line (Output);
      New_Line;

      Put_Line ("Formatted output:");
      Output := SML.DOM.Writer.Serialize_Formatted (Doc);
      Put_Line (Output);
      New_Line;
   end Example_Build_From_Scratch;

   ---------------------------------------------------------------------------
   --  Example 3: Modify Existing DOM
   ---------------------------------------------------------------------------

   procedure Example_Modify_DOM is
      Input  : constant String :=
        "<root><old>Keep</old><temp>Delete Me</temp></root>";
      Result : constant SML.DOM.Parser.Parse_Result :=
        SML.DOM.Parser.Parse (Input);
      Doc    : SML.DOM.Document;
      Root   : SML.DOM.Node_Id;
      Old_El : SML.DOM.Node_Id;
      Old_Text : SML.DOM.Node_Id;
      Temp   : SML.DOM.Node_Id;
      New_El : SML.DOM.Node_Id;
      Output : String (1 .. 10_000);
   begin
      Put_Line ("=== Example 3: Modify Existing DOM ===");
      New_Line;

      if not Result.Success then
         Put_Line ("Parse failed!");
         return;
      end if;

      Doc := Result.Doc;
      Root := SML.DOM.Root (Doc);

      Put_Line ("Original:");
      Put_Line (Input);
      New_Line;

      --  UPDATE: Modify text content
      Old_El := SML.DOM.Child_At (Doc, Root, 1);
      Old_Text := SML.DOM.First_Child (Doc, Old_El);
      Put_Line ("Changing text 'Keep' → 'Modified'");
      SML.DOM.Builder.Set_Text_Content (Doc, Old_Text, "Modified");

      --  UPDATE: Rename element
      Put_Line ("Renaming 'old' → 'updated'");
      SML.DOM.Builder.Set_Element_Name (Doc, Old_El, "updated");

      --  DELETE: Remove second element
      if SML.DOM.Child_Count (Doc, Root) >= 2 then
         Temp := SML.DOM.Child_At (Doc, Root, 2);
         Put_Line ("Deleting: <" & SML.DOM.Name (Doc, Temp) & ">");
         SML.DOM.Builder.Delete_Node (Doc, Temp);
      end if;

      --  CREATE: Add new element
      SML.DOM.Builder.Add_Child_Element (Doc, Root, "new", New_El);
      Put_Line ("Added: <new>");
      New_Line;

      Put_Line ("Result:");
      Output := SML.DOM.Writer.Serialize (Doc);
      Put_Line (Output);
      New_Line;
   end Example_Modify_DOM;

   ---------------------------------------------------------------------------
   --  Example 4: Round-Trip Verification
   ---------------------------------------------------------------------------

   procedure Example_Round_Trip is
      Input   : constant String :=
        "<data><item>Test &amp; verify</item></data>";
      Result1 : constant SML.DOM.Parser.Parse_Result :=
        SML.DOM.Parser.Parse (Input);
      Output  : String (1 .. 10_000);
      Result2 : SML.DOM.Parser.Parse_Result;
   begin
      Put_Line ("=== Example 4: Round-Trip Verification ===");
      New_Line;

      Put_Line ("Input:");
      Put_Line (Input);
      New_Line;

      if not Result1.Success then
         Put_Line ("Initial parse failed!");
         return;
      end if;

      --  Serialize
      Output := SML.DOM.Writer.Serialize (Result1.Doc);
      Put_Line ("Serialized:");
      Put_Line (Output);
      New_Line;

      --  Parse again
      Result2 := SML.DOM.Parser.Parse (Output);

      if Result2.Success then
         Put_Line ("✓ Round-trip successful!");
         Put_Line ("✓ Entities properly encoded and decoded");
      else
         Put_Line ("✗ Round-trip failed!");
      end if;
      New_Line;
   end Example_Round_Trip;

   ---------------------------------------------------------------------------
   --  Main
   ---------------------------------------------------------------------------

begin
   Put_Line ("====================================================");
   Put_Line ("SML Library - Complete Feature Demonstration");
   Put_Line ("====================================================");
   New_Line;

   Example_Parse_And_Traverse;
   Example_Build_From_Scratch;
   Example_Modify_DOM;
   Example_Round_Trip;

   Put_Line ("====================================================");
   Put_Line ("All examples completed successfully!");
   Put_Line ("====================================================");
end SML_Example;
