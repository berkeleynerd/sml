------------------------------------------------------------------------------
--  SML.Schema.Loader Package Body
--  Implementation of schema loading from SML documents
--  SPARK Ada Implementation with Formal Verification Support
------------------------------------------------------------------------------

package body SML.Schema.Loader
  with SPARK_Mode => On
is

   --  Exception for schema loading failures
   Schema_Load_Failed : exception;

   --  Error information for failed schema loads
   type Schema_Load_Error_Info is record
      Message : Bounded_String;
      Line    : Natural := 0;
   end record;

   ---------------------------------------------------------------------------
   --  Internal Result Types for Parsing
   ---------------------------------------------------------------------------

   --  Result for parsing simple types
   type Parse_Simple_Result (Success : Boolean := False) is record
      case Success is
         when True =>
            Simple_Def : Simple_Type_Definition;
         when False =>
            Error_Msg : Bounded_String;
      end case;
   end record;

   --  Result for parsing complex types
   type Parse_Complex_Result (Success : Boolean := False) is record
      case Success is
         when True =>
            Complex_Def : Complex_Type_Definition;
         when False =>
            Error_Msg : Bounded_String;
      end case;
   end record;

   --  Result for parsing element definitions
   type Parse_Elem_Result (Success : Boolean := False) is record
      case Success is
         when True =>
            Elem_Def : Element_Definition;
         when False =>
            Error_Msg : Bounded_String;
      end case;
   end record;

   ---------------------------------------------------------------------------
   --  DOM Helper Functions
   ---------------------------------------------------------------------------

   function Find_Child_Element
     (Doc    : DOM.Document;
      Parent : DOM.Node_Id;
      Name   : String) return DOM.Node_Id
   is
      Child : DOM.Node_Id := DOM.First_Child (Doc, Parent);
   begin
      while Child /= DOM.Null_Node loop
         pragma Loop_Variant (Structural => Child);

         if DOM.Kind (Doc, Child) = DOM.Element and then
            DOM.Name (Doc, Child) = Name
         then
            return Child;
         end if;

         Child := DOM.Next_Sibling (Doc, Child);
      end loop;

      return DOM.Null_Node;
   end Find_Child_Element;

   function Get_Element_Text
     (Doc     : DOM.Document;
      Element : DOM.Node_Id) return String
   is
      Child : constant DOM.Node_Id := DOM.First_Child (Doc, Element);
   begin
      if Child /= DOM.Null_Node and then
         DOM.Kind (Doc, Child) = DOM.Text
      then
         declare
            Text : constant String := DOM.Text_Value (Doc, Child);
         begin
            --  Bound text to Max_Name_Length to satisfy postcondition
            if Text'Length > Max_Name_Length then
               return Text (Text'First .. Text'First + Max_Name_Length - 1);
            else
               return Text;
            end if;
         end;
      end if;

      return "";
   end Get_Element_Text;

   ---------------------------------------------------------------------------
   --  Integer Parsing (SPARK_Mode Off due to Integer'Value)
   ---------------------------------------------------------------------------

   function Parse_Integer (Text : String; Default : Integer) return Integer
     with SPARK_Mode => Off
   is
   begin
      if Text'Length = 0 then
         return Default;
      end if;

      begin
         return Integer'Value (Text);
      exception
         when Constraint_Error =>
            return Default;
      end;
   end Parse_Integer;

   function Get_Integer_Value
     (Doc           : DOM.Document;
      Parent        : DOM.Node_Id;
      Child_Name    : String;
      Default_Value : Integer) return Integer
   is
      Child : constant DOM.Node_Id :=
        Find_Child_Element (Doc, Parent, Child_Name);
   begin
      if Child = DOM.Null_Node then
         return Default_Value;
      end if;

      declare
         Text : constant String := Get_Element_Text (Doc, Child);
      begin
         return Parse_Integer (Text, Default_Value);
      end;
   end Get_Integer_Value;

   --  Float parsing (SPARK_Mode Off due to Float'Value)
   function Parse_Float (Text : String; Default : Float) return Float
     with SPARK_Mode => Off
   is
   begin
      if Text'Length = 0 then
         return Default;
      end if;
      begin
         return Float'Value (Text);
      exception
         when Constraint_Error =>
            return Default;
      end;
   end Parse_Float;

   function Get_Float_Value
     (Doc           : DOM.Document;
      Parent        : DOM.Node_Id;
      Child_Name    : String;
      Default_Value : Float) return Float
   is
      Node : constant DOM.Node_Id := Find_Child_Element (Doc, Parent, Child_Name);
   begin
      if Node = DOM.Null_Node then
         return Default_Value;
      end if;
      return Parse_Float (Get_Element_Text (Doc, Node), Default_Value);
   end Get_Float_Value;

   function Get_Natural_Value
     (Doc           : DOM.Document;
      Parent        : DOM.Node_Id;
      Child_Name    : String;
      Default_Value : Natural) return Natural
   is
      Result : constant Integer :=
        Get_Integer_Value (Doc, Parent, Child_Name, Default_Value);
   begin
      if Result < 0 then
         return Default_Value;
      else
         return Result;
      end if;
   end Get_Natural_Value;

   ---------------------------------------------------------------------------
   --  Schema Element Parsers (Forward Declarations)
   ---------------------------------------------------------------------------

   function Parse_Simple_Type
     (Doc       : DOM.Document;
      Type_Node : DOM.Node_Id) return Parse_Simple_Result;

   function Parse_Complex_Type
     (Doc       : DOM.Document;
      Type_Node : DOM.Node_Id) return Parse_Complex_Result;

   function Parse_Element_Definition
     (Doc       : DOM.Document;
      Elem_Node : DOM.Node_Id) return Parse_Elem_Result;

   ---------------------------------------------------------------------------
   --  Enumeration Parsing
   ---------------------------------------------------------------------------

   procedure Parse_Enumeration_Values
     (Doc       : DOM.Document;
      Enum_Node : DOM.Node_Id;
      Type_Def  : in out Simple_Type_Definition)
   is
      Value_Child : DOM.Node_Id := DOM.First_Child (Doc, Enum_Node);
      Count       : Natural := 0;
   begin
      while Value_Child /= DOM.Null_Node and then
            Count < Max_Enum_Values
      loop
         pragma Loop_Variant (Structural => Value_Child);
         pragma Loop_Invariant (Count <= Max_Enum_Values);

         if DOM.Kind (Doc, Value_Child) = DOM.Element and then
            DOM.Name (Doc, Value_Child) = "value"
         then
            Count := Count + 1;
            Type_Def.Enum_Values (Count) :=
              To_Bounded_String (Get_Element_Text (Doc, Value_Child));
         end if;

         Value_Child := DOM.Next_Sibling (Doc, Value_Child);
      end loop;

      Type_Def.Enum_Count := Count;
   end Parse_Enumeration_Values;

   ---------------------------------------------------------------------------
   --  Simple Type Parsing
   ---------------------------------------------------------------------------

   function Parse_Simple_Type
     (Doc       : DOM.Document;
      Type_Node : DOM.Node_Id) return Parse_Simple_Result
   is
      Type_Def         : Simple_Type_Definition;
      Name_Node        : DOM.Node_Id;
      Restriction_Node : DOM.Node_Id;
      Base_Node        : DOM.Node_Id;
   begin
      --  Get name
      Name_Node := Find_Child_Element (Doc, Type_Node, "name");
      if Name_Node = DOM.Null_Node then
         return (Success => False,
                 Error_Msg => To_Bounded_String ("simpleType missing <name>"));
      end if;
      Type_Def.Name := To_Bounded_String (Get_Element_Text (Doc, Name_Node));

      --  Get restriction
      Restriction_Node := Find_Child_Element (Doc, Type_Node, "restriction");
      if Restriction_Node = DOM.Null_Node then
         return (Success   => False,
                 Error_Msg => To_Bounded_String
                   ("simpleType missing <restriction>"));
      end if;

      --  Get base type
      Base_Node := Find_Child_Element (Doc, Restriction_Node, "base");
      if Base_Node = DOM.Null_Node then
         return (Success   => False,
                 Error_Msg => To_Bounded_String
                   ("restriction missing <base>"));
      end if;

      declare
         Base_Text : constant String := Get_Element_Text (Doc, Base_Node);
      begin
         if Base_Text = "integer" then
            Type_Def.Base_Type := Integer_Type;
            --  Parse minValue/maxValue
            Type_Def.Min_Value :=
              Get_Integer_Value (Doc, Restriction_Node, "minValue",
                                Integer'First);
            Type_Def.Max_Value :=
              Get_Integer_Value (Doc, Restriction_Node, "maxValue",
                                Integer'Last);

         elsif Base_Text = "string" then
            Type_Def.Base_Type := String_Type;
            --  Check for enumeration
            declare
               Enum_Node : constant DOM.Node_Id :=
                 Find_Child_Element (Doc, Restriction_Node, "enumeration");
            begin
               if Enum_Node /= DOM.Null_Node then
                  Parse_Enumeration_Values (Doc, Enum_Node, Type_Def);
               end if;
            end;
            --  Optional length and prefix/suffix facets
            declare
               MinLen_Node : constant DOM.Node_Id :=
                 Find_Child_Element (Doc, Restriction_Node, "minLength");
               MaxLen_Node : constant DOM.Node_Id :=
                 Find_Child_Element (Doc, Restriction_Node, "maxLength");
               Prefix_Node : constant DOM.Node_Id :=
                 Find_Child_Element (Doc, Restriction_Node, "prefix");
               Suffix_Node : constant DOM.Node_Id :=
                 Find_Child_Element (Doc, Restriction_Node, "suffix");
            begin
               if MinLen_Node /= DOM.Null_Node then
                  Type_Def.Min_Length :=
                    Get_Natural_Value (Doc, Restriction_Node, "minLength", 0);
               end if;
               if MaxLen_Node /= DOM.Null_Node then
                  Type_Def.Max_Length :=
                    Get_Natural_Value (Doc, Restriction_Node, "maxLength", Max_String_Length);
               end if;
               if Prefix_Node /= DOM.Null_Node then
                  Type_Def.Prefix :=
                    To_Bounded_String (Get_Element_Text (Doc, Prefix_Node));
               end if;
               if Suffix_Node /= DOM.Null_Node then
                  Type_Def.Suffix :=
                    To_Bounded_String (Get_Element_Text (Doc, Suffix_Node));
               end if;
            end;

         elsif Base_Text = "boolean" then
            Type_Def.Base_Type := Boolean_Type;

         elsif Base_Text = "decimal" then
            Type_Def.Base_Type := Decimal_Type;
            --  Optional min/max constraints
            Type_Def.Dec_Min :=
              Get_Float_Value (Doc, Restriction_Node, "minValue", Float'First);
            Type_Def.Dec_Max :=
              Get_Float_Value (Doc, Restriction_Node, "maxValue", Float'Last);

         else
            return (Success   => False,
                    Error_Msg => To_Bounded_String ("Unknown base type"));
         end if;
      end;

      return (Success => True, Simple_Def => Type_Def);
   end Parse_Simple_Type;

   ---------------------------------------------------------------------------
   --  Element Reference Parsing
   ---------------------------------------------------------------------------

   procedure Parse_Element_References
     (Doc       : DOM.Document;
      Container : DOM.Node_Id;
      Type_Def  : in out Complex_Type_Definition)
   is
      Elem_Child : DOM.Node_Id := DOM.First_Child (Doc, Container);
      Count      : Natural := 0;
   begin
      while Elem_Child /= DOM.Null_Node and then
            Count < Max_Sequence_Elements
      loop
         pragma Loop_Variant (Structural => Elem_Child);
         pragma Loop_Invariant (Count <= Max_Sequence_Elements);

         if DOM.Kind (Doc, Elem_Child) = DOM.Element and then
            DOM.Name (Doc, Elem_Child) = "element"
         then
            Count := Count + 1;

            declare
               Ref       : Element_Ref;
               Name_Node : constant DOM.Node_Id :=
                 Find_Child_Element (Doc, Elem_Child, "name");
               Type_Node : constant DOM.Node_Id :=
                 Find_Child_Element (Doc, Elem_Child, "type");
               Max_Node  : constant DOM.Node_Id :=
                 Find_Child_Element (Doc, Elem_Child, "maxOccurs");
            begin
               if Name_Node /= DOM.Null_Node then
                  Ref.Element_Name :=
                    To_Bounded_String (Get_Element_Text (Doc, Name_Node));
               end if;

               --  Optional nested type binding for child element
               if Type_Node /= DOM.Null_Node then
                  Ref.Type_Name :=
                    To_Bounded_String (Get_Element_Text (Doc, Type_Node));
               end if;

               Ref.Min_Occurs :=
                 Get_Natural_Value (Doc, Elem_Child, "minOccurs", 1);

               --  Handle "unbounded" for maxOccurs
               if Max_Node /= DOM.Null_Node then
                  declare
                     Max_Text : constant String :=
                       Get_Element_Text (Doc, Max_Node);
                  begin
                     if Max_Text = "unbounded" then
                        Ref.Max_Occurs := Natural'Last;
                     else
                        Ref.Max_Occurs :=
                          Get_Natural_Value (Doc, Elem_Child, "maxOccurs", 1);
                     end if;
                  end;
               else
                  Ref.Max_Occurs := 1;
               end if;

               Type_Def.Children (Count) := Ref;
            end;
         end if;

         Elem_Child := DOM.Next_Sibling (Doc, Elem_Child);
      end loop;

      Type_Def.Child_Count := Count;
   end Parse_Element_References;

   ---------------------------------------------------------------------------
   --  Complex Type Parsing
   ---------------------------------------------------------------------------

   function Parse_Complex_Type
     (Doc       : DOM.Document;
      Type_Node : DOM.Node_Id) return Parse_Complex_Result
   is
      Type_Def     : Complex_Type_Definition;
      Name_Node    : DOM.Node_Id;
      Content_Node : DOM.Node_Id;
   begin
      --  Get name
      Name_Node := Find_Child_Element (Doc, Type_Node, "name");
      if Name_Node = DOM.Null_Node then
         return (Success => False,
                 Error_Msg => To_Bounded_String
                   ("complexType missing <name>"));
      end if;
      Type_Def.Name := To_Bounded_String (Get_Element_Text (Doc, Name_Node));

      --  Find content model (sequence or choice)
      Content_Node := Find_Child_Element (Doc, Type_Node, "sequence");
      if Content_Node /= DOM.Null_Node then
         Type_Def.Content_Model := Sequence_Model;
         Parse_Element_References (Doc, Content_Node, Type_Def);
      else
         Content_Node := Find_Child_Element (Doc, Type_Node, "choice");
         if Content_Node /= DOM.Null_Node then
            Type_Def.Content_Model := Choice_Model;
            Parse_Element_References (Doc, Content_Node, Type_Def);
         else
            return (Success   => False,
                    Error_Msg => To_Bounded_String
                      ("complexType missing <sequence> or <choice>"));
         end if;
      end if;

      return (Success => True, Complex_Def => Type_Def);
   end Parse_Complex_Type;

   ---------------------------------------------------------------------------
   --  Element Definition Parsing
   ---------------------------------------------------------------------------

   function Parse_Element_Definition
     (Doc       : DOM.Document;
      Elem_Node : DOM.Node_Id) return Parse_Elem_Result
   is
      Elem_Def  : Element_Definition;
      Name_Node : DOM.Node_Id;
      Type_Node : DOM.Node_Id;
   begin
      Name_Node := Find_Child_Element (Doc, Elem_Node, "name");
      if Name_Node = DOM.Null_Node then
         return (Success   => False,
                 Error_Msg => To_Bounded_String ("element missing <name>"));
      end if;
      Elem_Def.Name := To_Bounded_String (Get_Element_Text (Doc, Name_Node));

      Type_Node := Find_Child_Element (Doc, Elem_Node, "type");
      if Type_Node = DOM.Null_Node then
         return (Success   => False,
                 Error_Msg => To_Bounded_String ("element missing <type>"));
      end if;
      Elem_Def.Type_Name :=
        To_Bounded_String (Get_Element_Text (Doc, Type_Node));

      Elem_Def.Min_Occurs :=
        Get_Natural_Value (Doc, Elem_Node, "minOccurs", 1);
      Elem_Def.Max_Occurs :=
        Get_Natural_Value (Doc, Elem_Node, "maxOccurs", 1);

      return (Success => True, Elem_Def => Elem_Def);
   end Parse_Element_Definition;

   ---------------------------------------------------------------------------
   --  Helper Procedure for Schema Building
   ---------------------------------------------------------------------------

   procedure Build_Schema_From_DOM
     (Doc        : DOM.Document;
      Root       : DOM.Node_Id;
      Schema     : in out Schema_Document;
      Had_Error  : out Boolean;
      Error_Info : out Schema_Load_Error_Info)
   is
      Child : DOM.Node_Id := DOM.First_Child (Doc, Root);
      Success : Boolean;
   begin
      Had_Error := False;
      Error_Info := (Message => Empty_String, Line => 0);

      --  Traverse children of <schema>
      while Child /= DOM.Null_Node loop
         pragma Loop_Variant (Structural => Child);

         if DOM.Kind (Doc, Child) = DOM.Element then
            declare
               Child_Name : constant String := DOM.Name (Doc, Child);
            begin
               if Child_Name = "simpleType" then
                  declare
                     Parse_Result : constant Parse_Simple_Result :=
                       Parse_Simple_Type (Doc, Child);
                  begin
                     if Parse_Result.Success then
                        Add_Simple_Type (Schema, Parse_Result.Simple_Def,
                                       Success);
                        if not Success then
                           Had_Error := True;
                           Error_Info.Message :=
                             To_Bounded_String ("Failed to add simpleType");
                           return;
                        end if;
                     else
                        Had_Error := True;
                        Error_Info.Message := Parse_Result.Error_Msg;
                        return;
                     end if;
                  end;

               elsif Child_Name = "complexType" then
                  declare
                     Parse_Result : constant Parse_Complex_Result :=
                       Parse_Complex_Type (Doc, Child);
                  begin
                     if Parse_Result.Success then
                        Add_Complex_Type (Schema, Parse_Result.Complex_Def,
                                        Success);
                        if not Success then
                           Had_Error := True;
                           Error_Info.Message :=
                             To_Bounded_String ("Failed to add complexType");
                           return;
                        end if;
                     else
                        Had_Error := True;
                        Error_Info.Message := Parse_Result.Error_Msg;
                        return;
                     end if;
                  end;

               elsif Child_Name = "element" then
                  declare
                     Parse_Result : constant Parse_Elem_Result :=
                       Parse_Element_Definition (Doc, Child);
                  begin
                     if Parse_Result.Success then
                        Add_Element (Schema, Parse_Result.Elem_Def, Success);
                        if not Success then
                           Had_Error := True;
                           Error_Info.Message :=
                             To_Bounded_String ("Failed to add element");
                           return;
                        end if;
                     else
                        Had_Error := True;
                        Error_Info.Message := Parse_Result.Error_Msg;
                        return;
                     end if;
                  end;
               end if;
            end;
         end if;

         Child := DOM.Next_Sibling (Doc, Child);
      end loop;
   end Build_Schema_From_DOM;

   ---------------------------------------------------------------------------
   --  Main Load_Schema Function
   ---------------------------------------------------------------------------

   function Load_Schema (Doc : DOM.Document) return Schema_Load_Result is
      Root_Node   : constant DOM.Node_Id := DOM.Root (Doc);
      Local_Error : Schema_Load_Error_Info;
   begin
      --  Verify root is <schema> (early return before extended return)
      if Root_Node = DOM.Null_Node or else
         DOM.Name (Doc, Root_Node) /= "schema"
      then
         return (Success       => False,
                 Error_Message => To_Bounded_String ("Root must be <schema>"),
                 Error_Line    => 0);
      end if;

      --  Use extended return with helper procedure
      return Result : Schema_Load_Result (Success => True) do
         declare
            Had_Error  : Boolean;
            Error_Info : Schema_Load_Error_Info;
         begin
            Initialize (Result.Schema);
            Build_Schema_From_DOM (Doc, Root_Node, Result.Schema,
                                  Had_Error, Error_Info);

            if Had_Error then
               Local_Error := Error_Info;
               raise Schema_Load_Failed;
            end if;
         end;
      end return;

   exception
      when Schema_Load_Failed =>
         return (Success       => False,
                 Error_Message => Local_Error.Message,
                 Error_Line    => Local_Error.Line);
   end Load_Schema;

end SML.Schema.Loader;
