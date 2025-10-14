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
      Schema.Simple_Type_Count := 0;
      Schema.Complex_Type_Count := 0;
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

      for I in Schema.Complex_Types'Range loop
         Schema.Complex_Types (I) :=
            (Name => Empty_String,
             Content_Model => Sequence_Model,
             Children => [others => (Element_Name => Empty_String,
                                   Min_Occurs => 1,
                                   Max_Occurs => 1)],
             Child_Count => 0);
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
      if Schema.Simple_Type_Count >= Max_Types then
         Success := False;
         return;
      end if;

      --  Check for duplicate type name
      for I in 1 .. Schema.Simple_Type_Count loop
         if Schema.Simple_Types (I).Name = Type_Def.Name then
            Success := False;
            return;
         end if;
      end loop;

      --  Add the type
      Schema.Simple_Type_Count := Schema.Simple_Type_Count + 1;
      Schema.Simple_Types (Schema.Simple_Type_Count) := Type_Def;
      Success := True;
   end Add_Simple_Type;

   procedure Add_Complex_Type (
      Schema    : in out Schema_Document;
      Type_Def  : Complex_Type_Definition;
      Success   : out Boolean)
   is
   begin
      if Schema.Complex_Type_Count >= Max_Types then
         Success := False;
         return;
      end if;

      --  Check for duplicate type name
      for I in 1 .. Schema.Complex_Type_Count loop
         if Schema.Complex_Types (I).Name = Type_Def.Name then
            Success := False;
            return;
         end if;
      end loop;

      --  Add the type
      Schema.Complex_Type_Count := Schema.Complex_Type_Count + 1;
      Schema.Complex_Types (Schema.Complex_Type_Count) := Type_Def;
      Success := True;
   end Add_Complex_Type;

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

         --  Find the element definition
         for I in 1 .. Schema.Element_Count loop
            if Schema.Elements (I).Name =
               To_Bounded_String (Element_Name)
            then
               --  Validate structure if element has a complex type
               declare
                  Element_Def : Element_Definition renames
                     Schema.Elements (I);
                  Structure_Result : constant Validation_Result :=
                     Validate_Structure (Schema, Doc, Node,
                                       Element_Def.Type_Name);
               begin
                  if Structure_Result.Status = Invalid then
                     return Structure_Result;
                  end if;
               end;
               exit;
            end if;
         end loop;

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

   function Validate_Structure (
      Schema      : Schema_Document;
      Doc         : DOM.Document;
      Parent_Node : DOM.Node_Id;
      Type_Name   : Bounded_String) return Validation_Result
   is
      use DOM;
   begin
      --  Look for the complex type definition
      for I in 1 .. Schema.Complex_Type_Count loop
         if Schema.Complex_Types (I).Name = Type_Name then
            declare
               Complex_Type : Complex_Type_Definition renames
                  Schema.Complex_Types (I);
               Child : Node_Id := First_Child (Doc, Parent_Node);
            begin
               --  Validate based on content model
               case Complex_Type.Content_Model is
                  when Sequence_Model =>
                     --  Children must appear in order
                     for J in 1 .. Complex_Type.Child_Count loop
                        declare
                           Expected : Element_Ref renames
                              Complex_Type.Children (J);
                           Actual_Count : Natural := 0;
                        begin
                           --  Count matching children
                           while Child /= Null_Node loop
                              if Kind (Doc, Child) = Element and then
                                 To_Bounded_String (Name (Doc, Child)) =
                                    Expected.Element_Name
                              then
                                 Actual_Count := Actual_Count + 1;
                              end if;
                              Child := Next_Sibling (Doc, Child);
                           end loop;

                           --  Check cardinality
                           declare
                              Result : constant Validation_Result :=
                                 Check_Cardinality (
                                    Expected.Min_Occurs,
                                    Expected.Max_Occurs,
                                    Actual_Count,
                                    To_String (Expected.Element_Name));
                           begin
                              if Result.Status = Invalid then
                                 return Result;
                              end if;
                           end;
                        end;
                     end loop;

                  when Choice_Model =>
                     --  Exactly one child must match
                     --  Implementation deferred to Phase 5
                     null;

                  when Simple_Model =>
                     --  Text content only
                     --  Implementation deferred to Phase 5
                     null;
               end case;

               return Valid_Result;
            end;
         end if;
      end loop;

      --  Type not found - for now return valid
      --  In full implementation, this would be an error
      return Valid_Result;
   end Validate_Structure;

   function Check_Cardinality (
      Expected_Min : Natural;
      Expected_Max : Natural;
      Actual_Count : Natural;
      Element_Name : String) return Validation_Result
   is
   begin
      if Actual_Count < Expected_Min then
         return (Status => Invalid,
                Error_Message => To_Bounded_String
                   ("Too few " & Element_Name &
                    " elements: expected at least" &
                    Natural'Image (Expected_Min) &
                    ", got" & Natural'Image (Actual_Count)),
                Error_Path => To_Bounded_String ("/" & Element_Name),
                Line => 0,
                Column => 0);
      elsif Expected_Max /= Natural'Last
            and then Actual_Count > Expected_Max
      then
         return (Status => Invalid,
                Error_Message => To_Bounded_String
                   ("Too many " & Element_Name &
                    " elements: expected at most" &
                    Natural'Image (Expected_Max) &
                    ", got" & Natural'Image (Actual_Count)),
                Error_Path => To_Bounded_String ("/" & Element_Name),
                Line => 0,
                Column => 0);
      else
         return Valid_Result;
      end if;
   end Check_Cardinality;

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