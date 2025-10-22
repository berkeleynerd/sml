------------------------------------------------------------------------------
--  SML.Schema Package Body
--  Schema validation for Simple Markup Language (SML) documents
--  SPARK Ada Implementation
------------------------------------------------------------------------------

with SML.UTF8;

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
                     Error_Path    => To_Bounded_String ("/" & Name (Doc, Node)),
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
            Int_Min_Exclusive => False,
            Int_Max_Exclusive => False,
            Dec_Min     => Float'First,
            Dec_Max     => Float'Last,
            Dec_Min_Exclusive => False,
            Dec_Max_Exclusive => False,
            Total_Digits    => Natural'Last,
            Fraction_Digits => Natural'Last,
            Min_Length  => 0,
            Max_Length  => Max_String_Length,
            Length      => Natural'Last,
            Trim        => False,
            Prefix      => Empty_String,
            Suffix      => Empty_String,
            Contains    => Empty_String,
            Enum_Values => [others => Empty_String],
            Enum_Count  => 0);
     end loop;

      for I in Schema.Complex_Types'Range loop
         Schema.Complex_Types (I) :=
           (Name          => Empty_String,
            Content_Model => Sequence_Model,
            Group_Min_Occurs => 1,
            Group_Max_Occurs => 1,
            Simple_Content_Type_Name => Empty_String,
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

   procedure Set_Root_Element (Schema : in out Schema_Document; Name : String) is
   begin
      Schema.Root_Element := To_Bounded_String (Name);
   end Set_Root_Element;

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

      --  Enforce specific root element if specified in schema
      if Schema.Root_Element.Length > 0 then
         declare
            Root_Name : constant String := Name (Doc, Root_Node);
         begin
            if To_Bounded_String (Root_Name) /= Schema.Root_Element then
               return
                 (Status        => Invalid,
                  Error_Message =>
                    To_Bounded_String
                      ("Invalid root element: expected "
                       & To_String (Schema.Root_Element)
                       & ", got " & Root_Name),
                  Error_Path    => To_Bounded_String ("/" & Root_Name),
                  Line          => 0,
                  Column        => 0);
            end if;
         end;
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
                     -- Strict order: repeat group Group_Min_Occurs..Group_Max_Occurs times
                     declare
                        Rep                : Natural := 0;
                        Consumed_In_Rep    : Boolean := False;
                        J                  : Natural := 1;
                        Actual_Count       : Natural := 0;
                        Max_Repetitions    : Natural := Complex_Type.Group_Max_Occurs;
                     begin
                        Child := First_Child (Doc, Parent_Node);

                        Group_Loop : loop
                           exit Group_Loop when Max_Repetitions /= Natural'Last and then Rep >= Max_Repetitions;

                           -- Start repetition
                           Consumed_In_Rep := False;
                           J := 1;

                           while J <= Complex_Type.Child_Count loop
                              declare
                                 Expected : constant Element_Ref := Complex_Type.Children (J);
                              begin
                                 -- Skip non-element nodes
                                 while Child /= Null_Node and then Kind (Doc, Child) /= Element loop
                                    Child := Next_Sibling (Doc, Child);
                                 end loop;

                                 -- If required and next doesn't match: either stop (if min satisfied) or error
                                 if Child /= Null_Node
                                   and then Kind (Doc, Child) = Element
                                   and then Expected.Min_Occurs > 0
                                   and then To_Bounded_String (Name (Doc, Child)) /= Expected.Element_Name
                                 then
                                    if Rep >= Complex_Type.Group_Min_Occurs then
                                       exit Group_Loop;
                                    else
                                       declare
                                          Found_Name : constant String := Name (Doc, Child);
                                          Exp_Name   : constant String := To_String (Expected.Element_Name);
                                       begin
                                          return
                                            (Status        => Invalid,
                                             Error_Message => To_Bounded_String ("Order violation: expected " & Exp_Name & " before " & Found_Name),
                                             Error_Path    => To_Bounded_String ("/" & Found_Name),
                                             Line          => 0,
                                             Column        => 0);
                                       end;
                                    end if;
                                 end if;

                                 -- Count consecutive matches for this expected
                                 Actual_Count := 0;
                                 while Child /= Null_Node
                                   and then Kind (Doc, Child) = Element
                                   and then To_Bounded_String (Name (Doc, Child)) = Expected.Element_Name
                                 loop
                                    -- Typed validation if provided
                                    if Expected.Type_Name.Length > 0 then
                                       declare
                                          Vres : constant Validation_Result :=
                                            Validate_Node_Against_Type (Schema, Doc, Child, Expected.Type_Name);
                                       begin
                                          if Vres.Status = Invalid then
                                             return Vres;
                                          end if;
                                       end;
                                    end if;

                                    Actual_Count := Actual_Count + 1;
                                    Consumed_In_Rep := True;

                                    if Expected.Max_Occurs /= Natural'Last and then Actual_Count > Expected.Max_Occurs then
                                       return Check_Cardinality (Expected.Min_Occurs, Expected.Max_Occurs, Actual_Count, To_String (Expected.Element_Name));
                                    end if;

                                    Child := Next_Sibling (Doc, Child);
                                    while Child /= Null_Node and then Kind (Doc, Child) /= Element loop
                                       Child := Next_Sibling (Doc, Child);
                                    end loop;
                                 end loop;

                                 -- Final cardinality check for this expected
                                 declare
                                    Result : constant Validation_Result :=
                                      Check_Cardinality (Expected.Min_Occurs, Expected.Max_Occurs, Actual_Count, To_String (Expected.Element_Name));
                                 begin
                                    if Result.Status = Invalid then
                                       return Result;
                                    end if;
                                 end;

                                 J := J + 1;
                              end;
                           end loop;

                           -- Completed one repetition
                           Rep := Rep + 1;

                           -- If nothing consumed this repetition
                           if not Consumed_In_Rep then
                              if Rep >= Complex_Type.Group_Min_Occurs then
                                 exit Group_Loop;
                              else
                                 return
                                   (Status        => Invalid,
                                    Error_Message => To_Bounded_String ("Missing required group repetition"),
                                    Error_Path    => Empty_String,
                                    Line          => 0,
                                    Column        => 0);
                              end if;
                           end if;
                        end loop Group_Loop;

                        -- Ensure no extra element children remain
                        while Child /= Null_Node loop
                           if Kind (Doc, Child) = Element then
                              declare
                                 Found_Name : constant String := Name (Doc, Child);
                              begin
                                 return
                                   (Status        => Invalid,
                                    Error_Message => To_Bounded_String ("Unexpected element: " & Found_Name),
                                    Error_Path    => To_Bounded_String ("/" & Found_Name),
                                    Line          => 0,
                                    Column        => 0);
                              end;
                           end if;
                           Child := Next_Sibling (Doc, Child);
                        end loop;
                     end;

                  when Choice_Model =>
                     -- Group-level occurs for choice: each repetition picks exactly one option
                     declare
                        Picks          : Natural := 0;
                        Max_Picks      : Natural := Complex_Type.Group_Max_Occurs;
                        C              : Node_Id := First_Child (Doc, Parent_Node);
                     begin
                        while C /= Null_Node loop
                           if Kind (Doc, C) = Element then
                              declare
                                 NameB   : constant Bounded_String :=
                                   To_Bounded_String (Name (Doc, C));
                                 Matched : Boolean := False;
                              begin
                                 -- Find matching option
                                 for J in 1 .. Complex_Type.Child_Count loop
                                    declare
                                       Opt : constant Element_Ref := Complex_Type.Children (J);
                                    begin
                                       if Opt.Element_Name = NameB then
                                          Matched := True;
                                          -- Typed validation for this pick
                                          if Opt.Type_Name.Length > 0 then
                                             declare
                                                Vres : constant Validation_Result :=
                                                  Validate_Node_Against_Type (Schema, Doc, C, Opt.Type_Name);
                                             begin
                                                if Vres.Status = Invalid then
                                                   return Vres;
                                                end if;
                                             end;
                                          end if;
                                          exit;
                                       end if;
                                    end;
                                 end loop;
                                 if not Matched then
                                    return
                                      (Status        => Invalid,
                                       Error_Message => To_Bounded_String ("Unexpected element: " & To_String (NameB)),
                                       Error_Path    => To_Bounded_String ("/" & To_String (NameB)),
                                       Line          => 0,
                                       Column        => 0);
                                 end if;
                                 -- Count this as one pick
                                 Picks := Picks + 1;
                                 if Max_Picks /= Natural'Last and then Picks > Max_Picks then
                                    return
                                      (Status        => Invalid,
                                       Error_Message => To_Bounded_String ("Too many choices: maximum" & Natural'Image (Complex_Type.Group_Max_Occurs) & ", got" & Natural'Image (Picks)),
                                       Error_Path    => To_Bounded_String ("/" & To_String (NameB)),
                                       Line          => 0,
                                       Column        => 0);
                                 end if;
                              end;
                           end if;
                           C := Next_Sibling (Doc, C);
                        end loop;

                        -- Check minimum number of picks
                        if Picks < Complex_Type.Group_Min_Occurs then
                           return
                             (Status        => Invalid,
                              Error_Message => To_Bounded_String ("Too few choices: minimum" & Natural'Image (Complex_Type.Group_Min_Occurs) & ", got" & Natural'Image (Picks)),
                              Error_Path    => Empty_String,
                              Line          => 0,
                              Column        => 0);
                        end if;
                     end;

                  when All_Model =>
                     --  Unordered group: each expected element has independent
                     --  cardinality; unexpected elements are rejected
                     declare
                        Counts : array (1 .. Complex_Type.Child_Count) of Natural :=
                          [others => 0];
                        EChild : Node_Id := First_Child (Doc, Parent_Node);
                     begin
                        --  Scan all element children
                        while EChild /= Null_Node loop
                           if Kind (Doc, EChild) = Element then
                              declare
                                 Found : constant Bounded_String :=
                                   To_Bounded_String (Name (Doc, EChild));
                                 Matched : Boolean := False;
                              begin
                                 for K in 1 .. Complex_Type.Child_Count loop
                                    declare
                                       RefK : constant Element_Ref :=
                                         Complex_Type.Children (K);
                                    begin
                                       if RefK.Element_Name = Found then
                                          Matched := True;
                                          Counts (K) := Counts (K) + 1;
                                          --  Early too-many check
                                          if RefK.Max_Occurs /= Natural'Last
                                            and then Counts (K) > RefK.Max_Occurs
                                          then
                                             return
                                               Check_Cardinality
                                                 (RefK.Min_Occurs,
                                                  RefK.Max_Occurs,
                                                  Counts (K),
                                                  To_String (RefK.Element_Name));
                                          end if;

                                          --  Typed validation for this child
                                          if RefK.Type_Name.Length > 0 then
                                             declare
                                                Vres : constant Validation_Result :=
                                                  Validate_Node_Against_Type
                                                    (Schema,
                                                     Doc,
                                                     EChild,
                                                     RefK.Type_Name);
                                             begin
                                                if Vres.Status = Invalid then
                                                   return Vres;
                                                end if;
                                             end;
                                          end if;
                                          exit;
                                       end if;
                                    end;
                                 end loop;
                                 if not Matched then
                                    return
                                      (Status        => Invalid,
                                       Error_Message =>
                                         To_Bounded_String
                                           ("Unexpected element: "
                                            & To_String (Found)),
                                       Error_Path    => Found,
                                       Line          => 0,
                                       Column        => 0);
                                 end if;
                              end;
                           end if;
                           EChild := Next_Sibling (Doc, EChild);
                        end loop;

                        --  Check minimums
                        for K in 1 .. Complex_Type.Child_Count loop
                           declare
                              RefK : constant Element_Ref :=
                                Complex_Type.Children (K);
                              Cnt : constant Natural := Counts (K);
                              MinRes : constant Validation_Result :=
                                Check_Cardinality
                                  (RefK.Min_Occurs,
                                   RefK.Max_Occurs,
                                   Cnt,
                                   To_String (RefK.Element_Name));
                           begin
                              if MinRes.Status = Invalid then
                                 return MinRes;
                              end if;
                           end;
                        end loop;
                     end;

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
                     Error_Path    => To_Bounded_String ("/" & Name (Doc, Parent_Node)),
                     Line          => 0,
                     Column        => 0);
               end if;

                        --  Validate text against bound simple type if provided
                        if Complex_Type.Simple_Content_Type_Name.Length > 0 then
                           declare
                              Content : constant String :=
                                (if First_Text_Node = Null_Node then
                                   ""
                                 else
                                   Text_Value (Doc, First_Text_Node));
                              Result : constant Validation_Result :=
                                Validate_Content
                                  (Schema,
                                   Complex_Type.Simple_Content_Type_Name,
                                   Content);
                           begin
                              if Result.Status = Invalid then
                                 return Result;
                              end if;
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
                     --  Optional trim
                     declare
                        S : constant String :=
                          (if Type_Def.Trim then
                             SML.UTF8.Trim_Whitespace (Content)
                           else
                             Content);
                     begin
                     --  Check string length
                     if S'Length < Type_Def.Min_Length then
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
                     elsif S'Length > Type_Def.Max_Length then
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
                     --  Exact length if configured
                     if Type_Def.Length /= Natural'Last and then S'Length /= Type_Def.Length then
                        return
                          (Status        => Invalid,
                           Error_Message =>
                             To_Bounded_String
                               ("String length must be "
                                & Natural'Image (Type_Def.Length)
                                & " characters"),
                           Error_Path    => Empty_String,
                           Line          => 0,
                           Column        => 0);
                     end if;

                     if Type_Def.Enum_Count > 0 then
                        --  Check content length before validation
                        if S'Length > Max_Name_Length then
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
                            (S,
                             Type_Def.Enum_Values,
                             Type_Def.Enum_Count);
                     end if;

                     --  Optional prefix/suffix/contains constraints
                     if Type_Def.Prefix.Length > 0 then
                        declare
                           P : constant String := To_String (Type_Def.Prefix);
                        begin
                           if S'Length < P'Length or else
                             (P'Length > 0 and then
                              S (S'First .. S'First + P'Length - 1) /= P)
                           then
                              return
                                (Status        => Invalid,
                                 Error_Message =>
                                   To_Bounded_String
                                     ("String must start with: " & P),
                                 Error_Path    => Empty_String,
                                 Line          => 0,
                                 Column        => 0);
                           end if;
                        end;
                     end if;

                     if Type_Def.Suffix.Length > 0 then
                        declare
                           Suf : constant String := To_String (Type_Def.Suffix);
                           CL  : constant Natural := S'Length;
                           L   : constant Natural := Suf'Length;
                        begin
                           if L > CL or else
                             (L > 0 and then
                              S (S'Last - L + 1 .. S'Last) /= Suf)
                           then
                              return
                                (Status        => Invalid,
                                 Error_Message =>
                                   To_Bounded_String
                                     ("String must end with: " & Suf),
                                 Error_Path    => Empty_String,
                                 Line          => 0,
                                 Column        => 0);
                           end if;
                        end;
                     end if;

                     if Type_Def.Contains.Length > 0 then
                        declare
                           Sub : constant String := To_String (Type_Def.Contains);
                           CL  : constant Natural := S'Length;
                           SL  : constant Natural := Sub'Length;
                           Found : Boolean := False;
                        begin
                           if SL = 0 then
                              Found := True;
                           elsif SL <= CL then
                              declare
                                 I : Natural := 1;
                              begin
                                 while I <= CL - SL + 1 loop
                                    if S (I .. I + SL - 1) = Sub then
                                       Found := True;
                                       exit;
                                    end if;
                                    I := I + 1;
                                 end loop;
                              end;
                           end if;
                           if not Found then
                              return
                                (Status        => Invalid,
                                 Error_Message =>
                                   To_Bounded_String ("String must contain: " & Sub),
                                 Error_Path    => Empty_String,
                                 Line          => 0,
                                 Column        => 0);
                           end if;
                        end;
                     end if;

                     return Valid_Result;
                     end;

                  when Integer_Type =>
                     declare
                        IRes  : constant Validation_Result :=
                          Validate_Integer_Content (Content, Type_Def.Min_Value, Type_Def.Max_Value);
                        Value : Integer;
                     begin
                        if IRes.Status = Invalid then
                           return IRes;
                        end if;
                        --  Exclusive bounds
                        begin
                           Value := Integer'Value (Content);
                        exception
                           when Constraint_Error =>
                              return
                                (Status        => Invalid,
                                 Error_Message => To_Bounded_String ("Invalid integer value: " & Content),
                                 Error_Path    => Empty_String,
                                 Line          => 0,
                                 Column        => 0);
                        end;
                        if Type_Def.Int_Min_Exclusive and then Value <= Type_Def.Min_Value then
                           return
                             (Status        => Invalid,
                              Error_Message => To_Bounded_String ("Integer must be > " & Integer'Image (Type_Def.Min_Value)),
                              Error_Path    => Empty_String,
                              Line          => 0,
                              Column        => 0);
                        end if;
                        if Type_Def.Int_Max_Exclusive and then Value >= Type_Def.Max_Value then
                           return
                             (Status        => Invalid,
                              Error_Message => To_Bounded_String ("Integer must be < " & Integer'Image (Type_Def.Max_Value)),
                              Error_Path    => Empty_String,
                              Line          => 0,
                              Column        => 0);
                        end if;

                        --  If enumeration present, enforce numeric membership
                        if Type_Def.Enum_Count > 0 then
                           for E in 1 .. Type_Def.Enum_Count loop
                              declare
                                 EV_Str : constant String := To_String (Type_Def.Enum_Values (E));
                                 EV     : Integer;
                                 Match  : Boolean := False;
                              begin
                                 begin
                                    EV := Integer'Value (EV_Str);
                                    if EV = Value then
                                       Match := True;
                                    end if;
                                 exception
                                    when Constraint_Error => null;
                                 end;
                                 if Match then
                                    return Valid_Result;
                                 end if;
                              end;
                           end loop;
                           return
                             (Status        => Invalid,
                              Error_Message => To_Bounded_String ("Value not in enumeration: " & Content),
                              Error_Path    => Empty_String,
                              Line          => 0,
                              Column        => 0);
                        end if;
                        return Valid_Result;
                     end;

                  when Boolean_Type =>
                     return Validate_Boolean_Content (Content);

                  when Decimal_Type =>
                     declare
                        Res : Validation_Result :=
                          Validate_Decimal_Content (Content);
                        V   : Float;
                        --  Digit counts
                        Total_D  : Natural := 0;
                        Fraction : Natural := 0;
                        Seen_Dot : Boolean := False;
                     begin
                        if Res.Status = Invalid then
                           return Res;
                        end if;
                        --  Parse again to check range (safe under try/catch)
                        begin
                           V := Float'Value (Content);
                        exception
                           when Constraint_Error =>
                              return
                                (Status        => Invalid,
                                 Error_Message =>
                                   To_Bounded_String
                                     ("Invalid decimal value: " & Content),
                                 Error_Path    => Empty_String,
                                 Line          => 0,
                                 Column        => 0);
                        end;
                        if V < Type_Def.Dec_Min then
                            return
                             (Status        => Invalid,
                              Error_Message =>
                                To_Bounded_String
                                  ("Decimal too small: minimum "
                                   & Float'Image (Type_Def.Dec_Min)),
                              Error_Path    => Empty_String,
                              Line          => 0,
                              Column        => 0);
                        elsif V > Type_Def.Dec_Max then
                           return
                             (Status        => Invalid,
                              Error_Message =>
                                To_Bounded_String
                                  ("Decimal too large: maximum "
                                   & Float'Image (Type_Def.Dec_Max)),
                              Error_Path    => Empty_String,
                              Line          => 0,
                              Column        => 0);
                        end if;
                        --  Exclusive bounds, if configured
                        if Type_Def.Dec_Min_Exclusive and then V <= Type_Def.Dec_Min then
                           return
                             (Status        => Invalid,
                              Error_Message =>
                                To_Bounded_String
                                  ("Decimal must be > " & Float'Image (Type_Def.Dec_Min)),
                              Error_Path    => Empty_String,
                              Line          => 0,
                              Column        => 0);
                        end if;
                        if Type_Def.Dec_Max_Exclusive and then V >= Type_Def.Dec_Max then
                           return
                             (Status        => Invalid,
                              Error_Message =>
                                To_Bounded_String
                                  ("Decimal must be < " & Float'Image (Type_Def.Dec_Max)),
                              Error_Path    => Empty_String,
                              Line          => 0,
                              Column        => 0);
                        end if;
                        --  Enforce totalDigits/fractionDigits (max)
                        if Type_Def.Total_Digits /= Natural'Last or else
                           Type_Def.Fraction_Digits /= Natural'Last
                        then
                           -- Count digits in content (ignore sign and dot)
                           declare
                              S : constant String := Content;
                           begin
                              for I in S'Range loop
                                 if S (I) = '-' then
                                    null;
                                 elsif S (I) = '.' then
                                    Seen_Dot := True;
                                 elsif S (I) >= '0' and then S (I) <= '9' then
                                    Total_D := Total_D + 1;
                                    if Seen_Dot then
                                       Fraction := Fraction + 1;
                                    end if;
                                 else
                                    null;
                                 end if;
                              end loop;
                           end;
                           if Type_Def.Total_Digits /= Natural'Last and then
                              Total_D > Type_Def.Total_Digits
                           then
                              return
                                (Status        => Invalid,
                                 Error_Message =>
                                   To_Bounded_String
                                     ("Too many digits: maximum total "
                                      & Natural'Image (Type_Def.Total_Digits)),
                                 Error_Path    => Empty_String,
                                 Line          => 0,
                                 Column        => 0);
                           end if;
                           if Type_Def.Fraction_Digits /= Natural'Last and then
                              Fraction > Type_Def.Fraction_Digits
                           then
                              return
                                (Status        => Invalid,
                                 Error_Message =>
                                   To_Bounded_String
                                     ("Too many fraction digits: maximum "
                                      & Natural'Image (Type_Def.Fraction_Digits)),
                                 Error_Path    => Empty_String,
                                 Line          => 0,
                                 Column        => 0);
                           end if;
                        end if;
                        --  If enumeration present, enforce numeric membership
                        if Type_Def.Enum_Count > 0 then
                           for E in 1 .. Type_Def.Enum_Count loop
                              declare
                                 EV_Str : constant String := To_String (Type_Def.Enum_Values (E));
                                 EV     : Float;
                                 Match  : Boolean := False;
                              begin
                                 begin
                                    EV := Float'Value (EV_Str);
                                    if EV = V then
                                       Match := True;
                                    end if;
                                 exception
                                    when Constraint_Error => null;
                                 end;
                                 if Match then
                                    return Valid_Result;
                                 end if;
                              end;
                           end loop;
                           return
                             (Status        => Invalid,
                              Error_Message => To_Bounded_String ("Value not in enumeration: " & Content),
                              Error_Path    => Empty_String,
                              Line          => 0,
                              Column        => 0);
                        end if;
                        return Valid_Result;
                     end;
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
