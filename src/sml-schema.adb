------------------------------------------------------------------------------
--  SML.Schema Package Body
--  Schema validation for Simple Markup Language (SML) documents
--  SPARK Ada Implementation
------------------------------------------------------------------------------

package body SML.Schema
  with SPARK_Mode => On
is
   ---------------------------------------------------------------------------
   --  Internal Helper: Validate node against a given type name
   ---------------------------------------------------------------------------

   function Validate_Node_Against_Type
     (Schema    : Schema_Document;
      Doc       : DOM.Document;
      Node      : DOM.Node_Id;
      Type_Name : Bounded_String) return Validation_Result
   is
      use DOM;
   begin
      --  Try complex type first
      for I in 1 .. Schema.Complex_Type_Count loop
         if Schema.Complex_Types (I).Name = Type_Name then
            return Validate_Structure (Schema, Doc, Node, Type_Name);
         end if;
      end loop;

      --  Then simple type: text-only element with content validation
      for I in 1 .. Schema.Simple_Type_Count loop
         if Schema.Simple_Types (I).Name = Type_Name then
            declare
               Child             : Node_Id := First_Child (Doc, Node);
               Has_Element_Child : Boolean := False;
               First_Text_Node   : Node_Id := Null_Node;
            begin
               while Child /= Null_Node loop
                  if Kind (Doc, Child) = Element then
                     Has_Element_Child := True;
                  elsif Kind (Doc, Child) = Text
                    and then First_Text_Node = Null_Node
                  then
                     First_Text_Node := Child;
                  end if;
                  Child := Next_Sibling (Doc, Child);
               end loop;

               if Has_Element_Child then
                  return
                    (Status        => Invalid,
                     Error_Message =>
                       To_Bounded_String
                         ("Simple content cannot have child elements"),
                     Error_Path    => Empty_String,
                     Line          => 0,
                     Column        => 0);
               end if;

               declare
                  Content : constant String :=
                    (if First_Text_Node = Null_Node then
                       ""
                     else
                       Text_Value (Doc, First_Text_Node));
               begin
                  return Validate_Content (Schema, Type_Name, Content);
               end;
            end;
         end if;
      end loop;

      --  Unknown type name: treat as valid (no-op)
      return Valid_Result;
   end Validate_Node_Against_Type;

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
         Schema.Elements (I) :=
           (Name       => Empty_String,
            Type_Name  => Empty_String,
            Min_Occurs => 1,
            Max_Occurs => 1);
      end loop;

      for I in Schema.Simple_Types'Range loop
         Schema.Simple_Types (I) :=
           (Name        => Empty_String,
            Base_Type   => String_Type,
            Min_Value   => Integer'First,
            Max_Value   => Integer'Last,
            Min_Length  => 0,
            Max_Length  => Max_String_Length,
            Enum_Values => [others => Empty_String],
            Enum_Count  => 0);
      end loop;

      for I in Schema.Complex_Types'Range loop
         Schema.Complex_Types (I) :=
           (Name          => Empty_String,
            Content_Model => Sequence_Model,
            Children      =>
              [others =>
                 (Element_Name => Empty_String,
                  Type_Name    => Empty_String,
                  Min_Occurs   => 1,
                  Max_Occurs   => 1)],
            Child_Count   => 0);
      end loop;
   end Initialize;

   procedure Add_Element
     (Schema  : in out Schema_Document;
      Element : Element_Definition;
      Success : out Boolean) is
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

   procedure Add_Simple_Type
     (Schema   : in out Schema_Document;
      Type_Def : Simple_Type_Definition;
      Success  : out Boolean) is
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

   procedure Add_Complex_Type
     (Schema   : in out Schema_Document;
      Type_Def : Complex_Type_Definition;
      Success  : out Boolean) is
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

   function Is_Valid_Element_Name
     (Schema : Schema_Document; Name : String) return Boolean
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

   function Validate_Element
     (Schema : Schema_Document; Doc : DOM.Document; Node : DOM.Node_Id)
      return Validation_Result
   is
      use DOM;
   begin
      --  Check if node is an element
      if Kind (Doc, Node) /= Element then
         return
           (Status        => Invalid,
            Error_Message => To_Bounded_String ("Node is not an element"),
            Error_Path    => Empty_String,
            Line          => 0,
            Column        => 0);
      end if;

      --  Get element name
      declare
         Element_Name : constant String := Name (Doc, Node);
      begin
         --  Check if element name is valid
         if not Is_Valid_Element_Name (Schema, Element_Name) then
            return
              (Status        => Invalid,
               Error_Message =>
                 To_Bounded_String ("Unknown element: " & Element_Name),
               Error_Path    => To_Bounded_String ("/" & Element_Name),
               Line          => 0,
               Column        => 0);
         end if;

         --  Find the element definition
         for I in 1 .. Schema.Element_Count loop
            if Schema.Elements (I).Name = To_Bounded_String (Element_Name) then
               declare
                  Element_Def : Element_Definition renames Schema.Elements (I);
               begin
                  --  If a complex type with this name exists, validate structure
                  declare
                     Found_Complex : Boolean := False;
                  begin
                     if Element_Def.Type_Name.Length > 0 then
                        for C in 1 .. Schema.Complex_Type_Count loop
                           if Schema.Complex_Types (C).Name = Element_Def.Type_Name then
                              Found_Complex := True;
                              declare
                                 Structure_Result : constant Validation_Result :=
                                   Validate_Structure (Schema, Doc, Node, Element_Def.Type_Name);
                              begin
                                 if Structure_Result.Status = Invalid then
                                    return Structure_Result;
                                 end if;
                              end;
                              exit;
                           end if;
                        end loop;
                     end if;

                     --  If no complex type, check for simple type and validate content
                     if not Found_Complex and then Element_Def.Type_Name.Length > 0 then
                        --  Ensure there are no element children and extract first text node
                        declare
                           Child              : Node_Id := First_Child (Doc, Node);
                           Has_Element_Child  : Boolean := False;
                           First_Text_Node    : Node_Id := Null_Node;
                        begin
                           while Child /= Null_Node loop
                              if Kind (Doc, Child) = Element then
                                 Has_Element_Child := True;
                              elsif Kind (Doc, Child) = Text and then First_Text_Node = Null_Node then
                                 First_Text_Node := Child;
                              end if;
                              Child := Next_Sibling (Doc, Child);
                           end loop;

                           if Has_Element_Child then
                              return
                                (Status        => Invalid,
                                 Error_Message =>
                                   To_Bounded_String ("Simple content cannot have child elements"),
                                 Error_Path    => To_Bounded_String ("/" & Element_Name),
                                 Line          => 0,
                                 Column        => 0);
                           end if;

                           declare
                              Content : constant String :=
                                (if First_Text_Node = Null_Node then "" else Text_Value (Doc, First_Text_Node));
                              Content_Result : constant Validation_Result :=
                                Validate_Content (Schema, Element_Def.Type_Name, Content);
                           begin
                              if Content_Result.Status = Invalid then
                                 return Content_Result;
                              end if;
                           end;
                        end;
                     end if;
                  end;

               end;
               exit;
            end if;
         end loop;

         return Valid_Result;
      end;
   end Validate_Element;

   function Validate_Document
     (Schema : Schema_Document; Doc : DOM.Document) return Validation_Result
   is
      use DOM;
      Root_Node : constant Node_Id := Root (Doc);
   begin
      if Root_Node = Null_Node then
         return
           (Status        => Invalid,
            Error_Message =>
              To_Bounded_String ("Document has no root element"),
            Error_Path    => Empty_String,
            Line          => 0,
            Column        => 0);
      end if;

      --  Start validation from root
      return Validate_Element (Schema, Doc, Root_Node);
   end Validate_Document;

   function Validate_Structure
     (Schema      : Schema_Document;
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
               Complex_Type : Complex_Type_Definition
                 renames Schema.Complex_Types (I);
               Child        : Node_Id := First_Child (Doc, Parent_Node);
            begin
               --  Validate based on content model
               case Complex_Type.Content_Model is
                  when Sequence_Model =>
                     --  Strict order: consume children left-to-right
                     --  For each expected, count consecutive matches
                     --  Skip text nodes between elements
                     declare
                        J            : Natural := 1;
                        Actual_Count : Natural := 0;
                     begin
                        --  Initialize to first child of parent
                        Child := First_Child (Doc, Parent_Node);

                        while J <= Complex_Type.Child_Count loop
                           declare
                              Expected : Element_Ref
                                renames Complex_Type.Children (J);
                           begin
                              --  Skip non-element nodes
                              while Child /= Null_Node
                                and then Kind (Doc, Child) /= Element
                              loop
                                 Child := Next_Sibling (Doc, Child);
                              end loop;

                              --  Count consecutive matches
                              Actual_Count := 0;
                              while Child /= Null_Node
                                and then Kind (Doc, Child) = Element
                                and then To_Bounded_String
                                           (Name (Doc, Child))
                                         = Expected.Element_Name
                              loop
                                 --  Validate typed child if type provided
                                 if Expected.Type_Name.Length > 0 then
                                    declare
                                       Vres : constant Validation_Result :=
                                         Validate_Node_Against_Type
                                           (Schema,
                                            Doc,
                                            Child,
                                            Expected.Type_Name);
                                    begin
                                       if Vres.Status = Invalid then
                                          return Vres;
                                       end if;
                                    end;
                                 end if;

                                 Actual_Count := Actual_Count + 1;

                                 --  Early check for too many occurrences
                                 if Expected.Max_Occurs /= Natural'Last
                                   and then Actual_Count > Expected.Max_Occurs
                                 then
                                    return
                                      Check_Cardinality
                                        (Expected.Min_Occurs,
                                         Expected.Max_Occurs,
                                         Actual_Count,
                                         To_String
                                           (Expected.Element_Name));
                                 end if;

                                 Child := Next_Sibling (Doc, Child);
                                 --  Skip non-element nodes between matches
                                 while Child /= Null_Node
                                   and then Kind (Doc, Child) /= Element
                                 loop
                                    Child := Next_Sibling (Doc, Child);
                                 end loop;
                              end loop;

                              --  Final cardinality check for this expected
                              declare
                                 Result : constant Validation_Result :=
                                   Check_Cardinality
                                     (Expected.Min_Occurs,
                                      Expected.Max_Occurs,
                                      Actual_Count,
                                      To_String (Expected.Element_Name));
                              begin
                                 if Result.Status = Invalid then
                                    return Result;
                                 end if;
                              end;

                              --  Move to next expected item
                              J := J + 1;
                           end;
                        end loop;

                        --  Ensure no extra element children remain
                        while Child /= Null_Node loop
                           if Kind (Doc, Child) = Element then
                              declare
                                 Found_Name : constant String :=
                                   Name (Doc, Child);
                              begin
                                 return
                                   (Status        => Invalid,
                                    Error_Message =>
                                      To_Bounded_String
                                        ("Unexpected element: "
                                         & Found_Name),
                                    Error_Path    =>
                                      To_Bounded_String
                                        ("/" & Found_Name),
                                    Line          => 0,
                                    Column        => 0);
                              end;
                           end if;
                           Child := Next_Sibling (Doc, Child);
                        end loop;
                     end;

                  when Choice_Model =>
                     --  Exactly one option must have elements
                     declare
                        Options_With_Elements : Natural := 0;
                     begin
                        --  Count which options have elements
                        for J in 1 .. Complex_Type.Child_Count loop
                           declare
                              Expected     : Element_Ref
                                renames Complex_Type.Children (J);
                              Option_Count : Natural := 0;
                              Check_Child  : Node_Id :=
                                First_Child (Doc, Parent_Node);
                           begin
                              --  Count elements matching this option
                              while Check_Child /= Null_Node loop
                                 if Kind (Doc, Check_Child) = Element
                                   and then To_Bounded_String
                                              (Name (Doc, Check_Child))
                                            = Expected.Element_Name
                                 then
                                    Option_Count := Option_Count + 1;
                                 end if;
                                 Check_Child :=
                                   Next_Sibling (Doc, Check_Child);
                              end loop;

                              if Option_Count > 0 then
                                 Options_With_Elements :=
                                   Options_With_Elements + 1;

                                 --  Check cardinality for this option
                                 declare
                                    Result : constant Validation_Result :=
                                      Check_Cardinality
                                        (Expected.Min_Occurs,
                                         Expected.Max_Occurs,
                                         Option_Count,
                                         To_String (Expected.Element_Name));
                                 begin
                                    if Result.Status = Invalid then
                                       return Result;
                                    end if;
                                 end;
                              end if;
                           end;
                        end loop;

                        --  Validate that exactly one option was chosen
                        if Options_With_Elements = 0 then
                           return
                             (Status        => Invalid,
                              Error_Message =>
                                To_Bounded_String
                                  ("Choice group requires one option"),
                              Error_Path    => Empty_String,
                              Line          => 0,
                              Column        => 0);
                        elsif Options_With_Elements > 1 then
                           return
                             (Status        => Invalid,
                              Error_Message =>
                                To_Bounded_String
                                  ("Choice group allows only one option"),
                              Error_Path    => Empty_String,
                              Line          => 0,
                              Column        => 0);
                        end if;
                     end;

                     --  Validate any present typed option children
                     for J in 1 .. Complex_Type.Child_Count loop
                        declare
                           Expected    : Element_Ref
                             renames Complex_Type.Children (J);
                           Check_Child : Node_Id :=
                             First_Child (Doc, Parent_Node);
                        begin
                           if Expected.Type_Name.Length > 0 then
                              while Check_Child /= Null_Node loop
                                 if Kind (Doc, Check_Child) = Element
                                   and then To_Bounded_String
                                              (Name (Doc, Check_Child))
                                            = Expected.Element_Name
                                 then
                                    declare
                                       Vres : constant Validation_Result :=
                                         Validate_Node_Against_Type
                                           (Schema,
                                            Doc,
                                            Check_Child,
                                            Expected.Type_Name);
                                    begin
                                       if Vres.Status = Invalid then
                                          return Vres;
                                       end if;
                                    end;
                                 end if;
                                 Check_Child :=
                                   Next_Sibling (Doc, Check_Child);
                              end loop;
                           end if;
                        end;
                     end loop;

                  when Simple_Model =>
                     --  Text content only - no element children allowed
                     declare
                        Text_Child        : Node_Id :=
                          First_Child (Doc, Parent_Node);
                        Has_Element_Child : Boolean := False;
                        First_Text_Node   : Node_Id := Null_Node;
                     begin
                        --  Check for element children and find first text node
                        while Text_Child /= Null_Node loop
                           if Kind (Doc, Text_Child) = Element then
                              Has_Element_Child := True;
                           elsif Kind (Doc, Text_Child) = Text
                             and then First_Text_Node = Null_Node
                           then
                              First_Text_Node := Text_Child;
                           end if;
                           Text_Child := Next_Sibling (Doc, Text_Child);
                        end loop;

                        --  Simple content cannot have element children
                        if Has_Element_Child then
                           return
                             (Status        => Invalid,
                              Error_Message =>
                                To_Bounded_String
                                  ("Simple content cannot have child elements"),
                              Error_Path    => Empty_String,
                              Line          => 0,
                              Column        => 0);
                        end if;

                        --  If there's text content, validate it
                        --  Note: In full implementation, would validate
                        --  against the simple type for this element
                        if First_Text_Node /= Null_Node then
                           --  For now, just check it's not empty
                           declare
                              Text : constant String :=
                                Text_Value (Doc, First_Text_Node);
                              pragma Unreferenced (Text);
                           begin
                              --  Empty text is OK for simple content
                              null;
                           end;
                        end if;
                     end;
               end case;

               return Valid_Result;
            end;
         end if;
      end loop;

      --  Type not found - for now return valid
      --  In full implementation, this would be an error
      return Valid_Result;
   end Validate_Structure;

   function Check_Cardinality
     (Expected_Min : Natural;
      Expected_Max : Natural;
      Actual_Count : Natural;
      Element_Name : String) return Validation_Result is
   begin
      if Actual_Count < Expected_Min then
         return
           (Status        => Invalid,
            Error_Message =>
              To_Bounded_String
                ("Too few "
                 & Element_Name
                 & " elements: expected at least"
                 & Natural'Image (Expected_Min)
                 & ", got"
                 & Natural'Image (Actual_Count)),
            Error_Path    => To_Bounded_String ("/" & Element_Name),
            Line          => 0,
            Column        => 0);
      elsif Expected_Max /= Natural'Last and then Actual_Count > Expected_Max
      then
         return
           (Status        => Invalid,
            Error_Message =>
              To_Bounded_String
                ("Too many "
                 & Element_Name
                 & " elements: expected at most"
                 & Natural'Image (Expected_Max)
                 & ", got"
                 & Natural'Image (Actual_Count)),
            Error_Path    => To_Bounded_String ("/" & Element_Name),
            Line          => 0,
            Column        => 0);
      else
         return Valid_Result;
      end if;
   end Check_Cardinality;

   ---------------------------------------------------------------------------
   --  Content Validation Implementation
   ---------------------------------------------------------------------------

   function Validate_Content
     (Schema : Schema_Document; Type_Name : Bounded_String; Content : String)
      return Validation_Result is
   begin
      --  Look for the simple type definition
      for I in 1 .. Schema.Simple_Type_Count loop
         if Schema.Simple_Types (I).Name = Type_Name then
            declare
               Type_Def : Simple_Type_Definition
                 renames Schema.Simple_Types (I);
            begin
               case Type_Def.Base_Type is
                  when String_Type =>
                     --  Check string length
                     if Content'Length < Type_Def.Min_Length then
                        return
                          (Status        => Invalid,
                           Error_Message =>
                             To_Bounded_String
                               ("String too short: minimum "
                                & Natural'Image (Type_Def.Min_Length)
                                & " characters"),
                           Error_Path    => Empty_String,
                           Line          => 0,
                           Column        => 0);
                     elsif Content'Length > Type_Def.Max_Length then
                        return
                          (Status        => Invalid,
                           Error_Message =>
                             To_Bounded_String
                               ("String too long: maximum "
                                & Natural'Image (Type_Def.Max_Length)
                                & " characters"),
                           Error_Path    => Empty_String,
                           Line          => 0,
                           Column        => 0);
                     end if;

                     --  Check enumeration if defined
                     if Type_Def.Enum_Count > 0 then
                        --  Check content length before validation
                        if Content'Length > Max_Name_Length then
                           return
                             (Status        => Invalid,
                              Error_Message =>
                                To_Bounded_String
                                  ("Content too long for validation"),
                              Error_Path    => Empty_String,
                              Line          => 0,
                              Column        => 0);
                        end if;
                        return
                          Validate_Enum_Content
                            (Content,
                             Type_Def.Enum_Values,
                             Type_Def.Enum_Count);
                     end if;

                     return Valid_Result;

                  when Integer_Type =>
                     return
                       Validate_Integer_Content
                         (Content, Type_Def.Min_Value, Type_Def.Max_Value);

                  when Boolean_Type =>
                     return Validate_Boolean_Content (Content);

                  when Decimal_Type =>
                     return Validate_Decimal_Content (Content);
               end case;
            end;
         end if;
      end loop;

      --  Type not found - treat as string for now
      return Valid_Result;
   end Validate_Content;

   function Validate_Integer_Content
     (Content : String; Min_Value : Integer; Max_Value : Integer)
      return Validation_Result
   is
      Value : Integer;
   begin
      --  Try to parse as integer
      begin
         Value := Integer'Value (Content);
      exception
         when Constraint_Error =>
            return
              (Status        => Invalid,
               Error_Message =>
                 To_Bounded_String ("Invalid integer value: " & Content),
               Error_Path    => Empty_String,
               Line          => 0,
               Column        => 0);
      end;

      --  Check range
      if Value < Min_Value then
         return
           (Status        => Invalid,
            Error_Message =>
              To_Bounded_String
                ("Integer too small: minimum " & Integer'Image (Min_Value)),
            Error_Path    => Empty_String,
            Line          => 0,
            Column        => 0);
      elsif Value > Max_Value then
         return
           (Status        => Invalid,
            Error_Message =>
              To_Bounded_String
                ("Integer too large: maximum " & Integer'Image (Max_Value)),
            Error_Path    => Empty_String,
            Line          => 0,
            Column        => 0);
      end if;

      return Valid_Result;
   end Validate_Integer_Content;

   function Validate_Boolean_Content
     (Content : String) return Validation_Result is
   begin
      if Content = "true" or else Content = "false" then
         return Valid_Result;
      else
         return
           (Status        => Invalid,
            Error_Message =>
              To_Bounded_String
                ("Invalid boolean value: must be 'true' or 'false'"),
            Error_Path    => Empty_String,
            Line          => 0,
            Column        => 0);
      end if;
   end Validate_Boolean_Content;

   function Validate_Decimal_Content
     (Content : String) return Validation_Result
   is
      Value : Float;
      pragma Unreferenced (Value);
   begin
      --  Try to parse as float
      begin
         Value := Float'Value (Content);
      exception
         when Constraint_Error =>
            return
              (Status        => Invalid,
               Error_Message =>
                 To_Bounded_String ("Invalid decimal value: " & Content),
               Error_Path    => Empty_String,
               Line          => 0,
               Column        => 0);
      end;

      return Valid_Result;
   end Validate_Decimal_Content;

   function Validate_Enum_Content
     (Content : String; Enum_Values : Enum_Value_Array; Enum_Count : Natural)
      return Validation_Result
   is
      Content_Bounded : constant Bounded_String := To_Bounded_String (Content);
   begin
      --  Check if content matches any enum value
      for I in 1 .. Enum_Count loop
         if Enum_Values (I) = Content_Bounded then
            return Valid_Result;
         end if;
      end loop;

      --  Not found in enumeration
      return
        (Status        => Invalid,
         Error_Message =>
           To_Bounded_String ("Value not in enumeration: " & Content),
         Error_Path    => Empty_String,
         Line          => 0,
         Column        => 0);
   end Validate_Enum_Content;

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

   overriding
   function "=" (Left, Right : Bounded_String) return Boolean is
   begin
      return
        Left.Length = Right.Length
        and then Left.Data (1 .. Left.Length) = Right.Data (1 .. Right.Length);
   end "=";

end SML.Schema;
