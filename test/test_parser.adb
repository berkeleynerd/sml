------------------------------------------------------------------------------
--  Test Program for SML.DOM.Parser
--  Validates parser functionality with various SML inputs
------------------------------------------------------------------------------

with Ada.Text_IO;
with SML.DOM;
with SML.DOM.Parser;

procedure Test_Parser is
   use Ada.Text_IO;
   use type SML.DOM.Node_Id;
   use type SML.DOM.Node_Kind;

   procedure Test_Case (Name : String; Input : String; Should_Succeed : Boolean) is
      Result : constant SML.DOM.Parser.Parse_Result :=
        SML.DOM.Parser.Parse (Input);
   begin
      Put ("[" & Name & "] ");

      if Result.Success = Should_Succeed then
         if Result.Success then
            Put_Line ("✓ Parse succeeded");

            --  Show root element name
            declare
               Root : constant SML.DOM.Node_Id := SML.DOM.Root (Result.Doc);
            begin
               if Root /= SML.DOM.Null_Node then
                  Put_Line ("  Root: <" & SML.DOM.Name (Result.Doc, Root) & ">");

                  --  Show first child if exists
                  declare
                     First_Child : constant SML.DOM.Node_Id :=
                       SML.DOM.First_Child (Result.Doc, Root);
                  begin
                     if First_Child /= SML.DOM.Null_Node then
                        Put ("  First child: ");
                        if SML.DOM.Kind (Result.Doc, First_Child) = SML.DOM.Element
                        then
                           Put_Line ("<" & SML.DOM.Name (Result.Doc, First_Child) & ">");
                        else
                           Put_Line ("[Text: " &
                             SML.DOM.Text_Value (Result.Doc, First_Child) & "]");
                        end if;
                     else
                        Put_Line ("  (no children)");
                     end if;
                  end;
               end if;
            end;
         else
            Put_Line ("✓ Parse failed as expected");
            Put_Line ("  Error: " & Result.Error.Message (1 .. Result.Error.Msg_Length));
         end if;
      else
         Put_Line ("✗ UNEXPECTED RESULT");
         if Result.Success then
            Put_Line ("  Expected failure but got success");
         else
            Put_Line ("  Expected success but got error:");
            Put_Line ("  " & Result.Error.Message (1 .. Result.Error.Msg_Length));
         end if;
      end if;

      New_Line;
   end Test_Case;

begin
   Put_Line ("SML.DOM.Parser Test Suite");
   Put_Line ("========================");
   New_Line;

   --  Test 1: Self-closing root
   Test_Case (
      Name => "Self-closing root",
      Input => "<root/>",
      Should_Succeed => True);

   --  Test 2: Simple element with content
   Test_Case (
      Name => "Simple element",
      Input => "<root>text</root>",
      Should_Succeed => True);

   --  Test 3: Nested elements
   Test_Case (
      Name => "Nested elements",
      Input => "<root><child/></root>",
      Should_Succeed => True);

   --  Test 4: With entities
   Test_Case (
      Name => "Entity references",
      Input => "<root>&lt;hello&gt;</root>",
      Should_Succeed => True);

   --  Test 5: Multiple children
   Test_Case (
      Name => "Multiple children",
      Input => "<root><a/><b/><c/></root>",
      Should_Succeed => True);

   --  Test 6: Deep nesting
   Test_Case (
      Name => "Deep nesting",
      Input => "<a><b><c><d/></c></b></a>",
      Should_Succeed => True);

   --  Test 7: Mismatched tags (should fail)
   Test_Case (
      Name => "Mismatched tags",
      Input => "<root></wrong>",
      Should_Succeed => False);

   --  Test 8: Unclosed tag (should fail)
   Test_Case (
      Name => "Unclosed tag",
      Input => "<root><child></root>",
      Should_Succeed => False);

   --  Test 9: Invalid UTF-8 (should fail)
   Test_Case (
      Name => "Invalid UTF-8",
      Input => "<root>" & Character'Val (16#C0#) & Character'Val (16#80#) & "</root>",
      Should_Succeed => False);

   --  Test 10: Attributes (should fail - not allowed in SML)
   Test_Case (
      Name => "Attributes not allowed",
      Input => "<root attr='value'/>",
      Should_Succeed => False);

   --  Test 11: Comments (should fail)
   Test_Case (
      Name => "Comments not allowed",
      Input => "<root><!-- comment --></root>",
      Should_Succeed => False);

   Put_Line ("Test suite complete!");
end Test_Parser;
