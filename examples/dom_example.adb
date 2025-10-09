------------------------------------------------------------------------------
--  DOM Example: Build, Modify, and Serialize SML Documents
--  Demonstrates SML.DOM.Builder and SML.DOM.Writer usage
------------------------------------------------------------------------------

with Ada.Text_IO;
with SML.DOM;
with SML.DOM.Builder;
with SML.DOM.Writer;
with SML.DOM.Parser;

procedure DOM_Example is
   use Ada.Text_IO;

   --  Example 1: Create DOM programmatically
   procedure Example_Build_From_Scratch is
      Doc    : SML.DOM.Document;
      Item1  : SML.DOM.Node_Id;
      Item2  : SML.DOM.Node_Id;
      Text1  : SML.DOM.Node_Id;
      Text2  : SML.DOM.Node_Id;
      Output : String (1 .. 10_000);
   begin
      Put_Line ("=== Example 1: Build DOM from scratch ===");

      --  Create document with root element
      Doc := SML.DOM.Builder.Create_Document ("catalog");

      --  Add first item
      SML.DOM.Builder.Add_Child_Element
        (Doc, SML.DOM.Root (Doc), "item", Item1);
      SML.DOM.Builder.Add_Text_Node (Doc, Item1, "Book", Text1);

      --  Add second item
      SML.DOM.Builder.Add_Child_Element
        (Doc, SML.DOM.Root (Doc), "item", Item2);
      SML.DOM.Builder.Add_Text_Node (Doc, Item2, "Pen", Text2);

      --  Serialize and display
      Put_Line ("Compact output:");
      Output := SML.DOM.Writer.Serialize (Doc);
      Put_Line (Output);

      New_Line;
      Put_Line ("Formatted output:");
      Output := SML.DOM.Writer.Serialize_Formatted (Doc);
      Put_Line (Output);
      New_Line;
   end Example_Build_From_Scratch;

   --  Example 2: Parse, modify, and re-serialize
   procedure Example_Parse_And_Modify is
      Input  : constant String := "<root><old>Keep</old><temp>Delete</temp></root>";
      Result : constant SML.DOM.Parser.Parse_Result :=
        SML.DOM.Parser.Parse (Input);
      Doc    : SML.DOM.Document;
      Root   : SML.DOM.Node_Id;
      Temp   : SML.DOM.Node_Id;
      New_El : SML.DOM.Node_Id;
      Output : String (1 .. 10_000);
   begin
      Put_Line ("=== Example 2: Parse, modify, serialize ===");

      if not Result.Success then
         Put_Line ("Parse failed!");
         return;
      end if;

      Doc := Result.Doc;
      Root := SML.DOM.Root (Doc);

      Put_Line ("Original:");
      Put_Line (Input);
      New_Line;

      --  Find and delete the 'temp' element (second child)
      if SML.DOM.Child_Count (Doc, Root) >= 2 then
         Temp := SML.DOM.Child_At (Doc, Root, 2);
         Put_Line ("Deleting node: " & SML.DOM.Name (Doc, Temp));
         SML.DOM.Builder.Delete_Node (Doc, Temp);
      end if;

      --  Add a new element
      SML.DOM.Builder.Add_Child_Element (Doc, Root, "new", New_El);

      --  Serialize modified document
      Put_Line ("Modified (temp deleted, new added):");
      Output := SML.DOM.Writer.Serialize (Doc);
      Put_Line (Output);
      New_Line;
   end Example_Parse_And_Modify;

   --  Example 3: Round-trip test
   procedure Example_Round_Trip is
      Input   : constant String := "<data><item>Test &amp; verify</item></data>";
      Result1 : constant SML.DOM.Parser.Parse_Result :=
        SML.DOM.Parser.Parse (Input);
      Output  : String (1 .. 10_000);
      Result2 : SML.DOM.Parser.Parse_Result;
   begin
      Put_Line ("=== Example 3: Round-trip test ===");

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
         Put_Line ("Round-trip successful!");
         Put_Line ("Entities properly encoded and decoded.");
      else
         Put_Line ("Round-trip failed!");
      end if;

      New_Line;
   end Example_Round_Trip;

begin
   Example_Build_From_Scratch;
   Example_Parse_And_Modify;
   Example_Round_Trip;

   Put_Line ("All examples completed successfully!");
end DOM_Example;
