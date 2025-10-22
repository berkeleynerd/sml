------------------------------------------------------------------------------
--  Omnibus Test Runner for SML
--  Runs both parser and schema test suites
------------------------------------------------------------------------------

with Ada.Text_IO;
with Test_Parser;
with Test_Schema;

procedure Test_All is
   use Ada.Text_IO;
begin
   Put_Line ("=====================================");
   Put_Line ("  SML Omnibus Test Suite");
   Put_Line ("=====================================");
   New_Line;

   Put_Line ("== Parser Tests ==");
   Test_Parser;
   New_Line;

   Put_Line ("== Schema Tests ==");
   Test_Schema;
   New_Line;

   Put_Line ("=====================================");
   Put_Line ("  All Tests Completed");
   Put_Line ("=====================================");
end Test_All;
