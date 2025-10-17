------------------------------------------------------------------------------
--                   Simple Markup Language (SML) Library                   --
--                                                                          --
--                     Common Types Package                                 --
------------------------------------------------------------------------------

package SML_Types
  with SPARK_Mode, Pure
is
   --  Basic types used across multiple packages
   subtype Natural_32 is Natural range 0 .. 2**31 - 1;
   
   --  Configuration constants (duplicated here to avoid dependencies)
   Max_Document_Nodes : constant := 2_000;
   Max_String_Storage : constant := 200_000;  -- 200KB
   Max_Tree_Depth     : constant := 1_000;
   Max_Children       : constant := 10_000;
   
end SML_Types;
