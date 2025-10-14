------------------------------------------------------------------------------
--  SML.Schema Package Body
--  Schema validation for Simple Markup Language (SML) documents
--  SPARK Ada Implementation
------------------------------------------------------------------------------

package body SML.Schema
  with SPARK_Mode => On
is

   ---------------------------------------------------------------------------
   --  Schema Construction Implementation
   ---------------------------------------------------------------------------

   procedure Initialize (Schema : out Schema_Document) is
   begin
      Schema.Element_Count := 0;
      Schema.Type_Count := 0;
      Schema.Root_Element := Empty_String;

      --  Initialize arrays to default values
      for I in Schema.Elements'Range loop
         Schema.Elements (I) := (Name => Empty_String,
                                 Type_Name => Empty_String,
                                 Min_Occurs => 1,
                                 Max_Occurs => 1);
      end loop;

      for I in Schema.Simple_Types'Range loop
         Schema.Simple_Types (I) := (Name => Empty_String,
                                     Base_Type => String_Type,
                                     Min_Value => Integer'First,
                                     Max_Value => Integer'Last);
      end loop;
   end Initialize;

   procedure Add_Element (
      Schema  : in out Schema_Document;
      Element : Element_Definition;
      Success : out Boolean)
   is
   begin
      if Schema.Element_Count >= Max_Elements then
         Success := False;
         return;
      end if;

      --  Check for duplicate element name
      for I in 1 .. Schema.Element_Count loop
         if Schema.Elements (I).Name = Element.Name then
            Success := False;
            return;
         end if;
      end loop;

      --  Add the element
      Schema.Element_Count := Schema.Element_Count + 1;
      Schema.Elements (Schema.Element_Count) := Element;
      Success := True;
   end Add_Element;

   procedure Add_Simple_Type (
      Schema    : in out Schema_Document;
      Type_Def  : Simple_Type_Definition;
      Success   : out Boolean)
   is
   begin
      if Schema.Type_Count >= Max_Types then
         Success := False;
         return;
      end if;

      --  Check for duplicate type name
      for I in 1 .. Schema.Type_Count loop
         if Schema.Simple_Types (I).Name = Type_Def.Name then
            Success := False;
            return;
         end if;
      end loop;

      --  Add the type
      Schema.Type_Count := Schema.Type_Count + 1;
      Schema.Simple_Types (Schema.Type_Count) := Type_Def;
      Success := True;
   end Add_Simple_Type;

   ---------------------------------------------------------------------------
   --  Validation Implementation
   ---------------------------------------------------------------------------

   function Is_Valid_Element_Name (
      Schema : Schema_Document;
      Name   : String) return Boolean
   is
      Name_Bounded : constant Bounded_String := To_Bounded_String (Name);
   begin
      --  If no elements defined, any name is invalid
      if Schema.Element_Count = 0 then
         return False;
      end if;

      --  Check if name matches any defined element
      for I in 1 .. Schema.Element_Count loop
         if Schema.Elements (I).Name = Name_Bounded then
            return True;
         end if;
      end loop;

      return False;
   end Is_Valid_Element_Name;

   function Validate_Element (
      Schema : Schema_Document;
      Doc    : DOM.Document;
      Node   : DOM.Node_Id) return Validation_Result
   is
      use DOM;
   begin
      --  Check if node is an element
      if Kind (Doc, Node) /= Element then
         return (Status => Invalid,
                Error_Message => To_Bounded_String ("Node is not an element"),
                Error_Path => Empty_String,
                Line => 0,
                Column => 0);
      end if;

      --  Get element name
      declare
         Element_Name : constant String := Name (Doc, Node);
      begin
         --  Check if element name is valid
         if not Is_Valid_Element_Name (Schema, Element_Name) then
            return (Status => Invalid,
                   Error_Message => To_Bounded_String
                      ("Unknown element: " & Element_Name),
                   Error_Path => To_Bounded_String ("/" & Element_Name),
                   Line => 0,
                   Column => 0);
         end if;

         --  For now, just validate the name
         --  Phase 4 will add structure validation
         --  Phase 5 will add content type validation
         return Valid_Result;
      end;
   end Validate_Element;

   function Validate_Document (
      Schema : Schema_Document;
      Doc    : DOM.Document) return Validation_Result
   is
      use DOM;
      Root_Node : constant Node_Id := Root (Doc);
   begin
      if Root_Node = Null_Node then
         return (Status => Invalid,
                Error_Message => To_Bounded_String
                   ("Document has no root element"),
                Error_Path => Empty_String,
                Line => 0,
                Column => 0);
      end if;

      --  Start validation from root
      return Validate_Element (Schema, Doc, Root_Node);
   end Validate_Document;

   ---------------------------------------------------------------------------
   --  Utility Functions Implementation
   ---------------------------------------------------------------------------

   function To_Bounded_String (S : String) return Bounded_String is
      Result : Bounded_String;
   begin
      if S'Length > Max_Name_Length then
         --  Truncate if too long (precondition should prevent this)
         Result.Length := Max_Name_Length;
         Result.Data (1 .. Max_Name_Length) :=
            S (S'First .. S'First + Max_Name_Length - 1);
      else
         Result.Length := S'Length;
         if S'Length > 0 then
            Result.Data (1 .. S'Length) := S;
         end if;
      end if;
      return Result;
   end To_Bounded_String;

   function To_String (B : Bounded_String) return String is
   begin
      return B.Data (1 .. B.Length);
   end To_String;

   overriding function "=" (Left, Right : Bounded_String) return Boolean is
   begin
      return Left.Length = Right.Length
         and then
         Left.Data (1 .. Left.Length) = Right.Data (1 .. Right.Length);
   end "=";

end SML.Schema;