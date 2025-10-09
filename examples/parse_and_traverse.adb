------------------------------------------------------------------------------
--  SML Parser Example: Parse and Traverse DOM
--  Demonstrates parsing SML and navigating the resulting DOM tree
------------------------------------------------------------------------------

with Ada.Text_IO;
with SML.DOM;
with SML.DOM.Parser;

procedure Parse_And_Traverse is
   use Ada.Text_IO;
   use type SML.DOM.Node_Id;
   use type SML.DOM.Node_Kind;

   --  Example SML document
   Sample_SML : constant String :=
     "<document>" &
     "  <metadata>" &
     "    <title>Sample Document</title>" &
     "    <author>SPARK Verified Parser</author>" &
     "  </metadata>" &
     "  <content>" &
     "    <section>" &
     "      <heading>Introduction</heading>" &
     "      <paragraph>This is &lt;example&gt; text with entities.</paragraph>" &
     "    </section>" &
     "    <section>" &
     "      <heading>Conclusion</heading>" &
     "      <paragraph>SML parsing complete!</paragraph>" &
     "    </section>" &
     "  </content>" &
     "</document>";

   --  Recursive traversal procedure (for display)
   procedure Print_Node (Doc : SML.DOM.Document;
                        Node : SML.DOM.Node_Id;
                        Indent : Natural := 0) is
      Spaces : constant String (1 .. Indent * 2) := (others => ' ');
      Child : SML.DOM.Node_Id;
   begin
      case SML.DOM.Kind (Doc, Node) is
         when SML.DOM.Element =>
            Put_Line (Spaces & "<" & SML.DOM.Name (Doc, Node) & ">");

            --  Traverse children
            Child := SML.DOM.First_Child (Doc, Node);
            while Child /= SML.DOM.Null_Node loop
               Print_Node (Doc, Child, Indent + 1);
               Child := SML.DOM.Next_Sibling (Doc, Node => Child);
            end loop;

            Put_Line (Spaces & "</" & SML.DOM.Name (Doc, Node) & ">");

         when SML.DOM.Text =>
            Put_Line (Spaces & "[Text: " &
              SML.DOM.Text_Value (Doc, Node) & "]");
      end case;
   end Print_Node;

   --  Extract text content from all descendants
   procedure Extract_All_Text (Doc : SML.DOM.Document;
                               Node : SML.DOM.Node_Id) is
      Child : SML.DOM.Node_Id;
   begin
      case SML.DOM.Kind (Doc, Node) is
         when SML.DOM.Element =>
            --  Process children
            Child := SML.DOM.First_Child (Doc, Node);
            while Child /= SML.DOM.Null_Node loop
               Extract_All_Text (Doc, Child);
               Child := SML.DOM.Next_Sibling (Doc, Node => Child);
            end loop;

         when SML.DOM.Text =>
            Put (SML.DOM.Text_Value (Doc, Node) & " ");
      end case;
   end Extract_All_Text;

   Result : constant SML.DOM.Parser.Parse_Result :=
     SML.DOM.Parser.Parse (Sample_SML);

begin
   Put_Line ("=== SML Parser Example ===");
   New_Line;

   if Result.Success then
      Put_Line ("✓ Parse succeeded!");
      New_Line;

      Put_Line ("--- Document Structure ---");
      Print_Node (Result.Doc, SML.DOM.Root (Result.Doc));
      New_Line;

      Put_Line ("--- Extracted Text Content ---");
      Extract_All_Text (Result.Doc, SML.DOM.Root (Result.Doc));
      New_Line;
      New_Line;

      --  Demonstrate specific queries
      Put_Line ("--- Specific Queries ---");
      declare
         Root : constant SML.DOM.Node_Id := SML.DOM.Root (Result.Doc);
         Metadata : SML.DOM.Node_Id;
         Title : SML.DOM.Node_Id;
      begin
         Put_Line ("Root element: <" & SML.DOM.Name (Result.Doc, Root) & ">");
         Put_Line ("Child count: " &
           Natural'Image (SML.DOM.Child_Count (Result.Doc, Root)));

         --  Access metadata section
         Metadata := SML.DOM.First_Child (Result.Doc, Root);
         if Metadata /= SML.DOM.Null_Node and then
           SML.DOM.Kind (Result.Doc, Metadata) = SML.DOM.Element
         then
            Put_Line ("First section: <" &
              SML.DOM.Name (Result.Doc, Metadata) & ">");

            --  Get title
            Title := SML.DOM.First_Child (Result.Doc, Metadata);
            if Title /= SML.DOM.Null_Node then
               Put_Line ("  Contains: <" &
                 SML.DOM.Name (Result.Doc, Title) & ">");

               --  Get title text
               declare
                  Title_Text_Node : constant SML.DOM.Node_Id :=
                    SML.DOM.First_Child (Result.Doc, Title);
               begin
                  if Title_Text_Node /= SML.DOM.Null_Node then
                     Put_Line ("  Title text: " &
                       SML.DOM.Text_Value (Result.Doc, Title_Text_Node));
                  end if;
               end;
            end if;
         end if;
      end;

   else
      Put_Line ("✗ Parse failed!");
      Put_Line ("Error kind: " & SML.DOM.Parser.Error_Kind'Image (Result.Error.Kind));
      Put_Line ("Position: " & Natural'Image (Result.Error.Position));
      Put_Line ("Line: " & Positive'Image (Result.Error.Line));
      Put_Line ("Column: " & Positive'Image (Result.Error.Column));
      Put_Line ("Message: " & Result.Error.Message (1 .. Result.Error.Msg_Length));
   end if;

   New_Line;
   Put_Line ("=== Example Complete ===");
end Parse_And_Traverse;
