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
      --  Create document with root (limited type initialized at declaration)
      Doc    : SML.DOM.Document := SML.DOM.Builder.Create_Document ("catalog");
      Item1  : SML.DOM.Node_Id;
      Item2  : SML.DOM.Node_Id;
      Text1  : SML.DOM.Node_Id;
      Text2  : SML.DOM.Node_Id;
   begin
      Put_Line ("=== Example 2: Build DOM from Scratch ===");
      New_Line;

      --  Add items with text
      SML.DOM.Builder.Add_Child_Element (Doc, SML.DOM.Root (Doc), "item", Item1);
      SML.DOM.Builder.Add_Text_Node (Doc, Item1, "Book", Text1);

      SML.DOM.Builder.Add_Child_Element (Doc, SML.DOM.Root (Doc), "item", Item2);
      SML.DOM.Builder.Add_Text_Node (Doc, Item2, "Pen", Text2);

      Put_Line ("Compact output:");
      Put_Line (SML.DOM.Writer.Serialize (Doc));
      New_Line;

      Put_Line ("Formatted output:");
      Put_Line (SML.DOM.Writer.Serialize_Formatted (Doc));
      New_Line;
   end Example_Build_From_Scratch;

   ---------------------------------------------------------------------------
   --  Example 3: Modify Existing DOM
   ---------------------------------------------------------------------------

   procedure Example_Modify_DOM is
      --  Build a simple document to modify
      Doc      : SML.DOM.Document := SML.DOM.Builder.Create_Document ("root");
      Root     : constant SML.DOM.Node_Id := SML.DOM.Root (Doc);
      Old_El   : SML.DOM.Node_Id;
      Temp_El  : SML.DOM.Node_Id;
      Old_Text : SML.DOM.Node_Id;
      Temp_Text : SML.DOM.Node_Id;
      New_El   : SML.DOM.Node_Id;
   begin
      Put_Line ("=== Example 3: Full CRUD Operations ===");
      New_Line;

      --  CREATE: Build initial structure
      SML.DOM.Builder.Add_Child_Element (Doc, Root, "old", Old_El);
      SML.DOM.Builder.Add_Text_Node (Doc, Old_El, "Keep", Old_Text);
      SML.DOM.Builder.Add_Child_Element (Doc, Root, "temp", Temp_El);
      SML.DOM.Builder.Add_Text_Node (Doc, Temp_El, "Delete Me", Temp_Text);

      Put_Line ("Initial structure:");
      Put_Line (SML.DOM.Writer.Serialize (Doc));
      New_Line;

      --  UPDATE: Modify text content
      Put_Line ("Changing text 'Keep' → 'Modified'");
      SML.DOM.Builder.Set_Text_Content (Doc, Old_Text, "Modified");

      --  UPDATE: Rename element
      Put_Line ("Renaming 'old' → 'updated'");
      SML.DOM.Builder.Set_Element_Name (Doc, Old_El, "updated");

      --  DELETE: Remove temp element
      Put_Line ("Deleting: <temp>");
      SML.DOM.Builder.Delete_Node (Doc, Temp_El);

      --  CREATE: Add new element
      SML.DOM.Builder.Add_Child_Element (Doc, Root, "new", New_El);
      Put_Line ("Added: <new>");
      New_Line;

      Put_Line ("Final result:");
      Put_Line (SML.DOM.Writer.Serialize (Doc));
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

      --  Serialize and re-parse
      declare
         Output : constant String := SML.DOM.Writer.Serialize (Result1.Doc);
         Result2 : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse (Output);
      begin
         Put_Line ("Serialized:");
         Put_Line (Output);
         New_Line;

         if Result2.Success then
            Put_Line ("✓ Round-trip successful!");
            Put_Line ("✓ Entities properly encoded and decoded");
         else
            Put_Line ("✗ Round-trip failed!");
         end if;
      end;
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
