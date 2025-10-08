------------------------------------------------------------------------------
--  SML.Bisimulation Package Specification
--  Semantic Equivalence between Text and DOM Representations
--  SPARK Ada Implementation - Formal Verification
------------------------------------------------------------------------------

with SML.DOM;
with SML.Grammar;
with SML.Parser;

package SML.Bisimulation with SPARK_Mode => On, Ghost is

   --  This package proves bisimulation between SML text representation
   --  and DOM representation, showing they preserve the same semantic
   --  information and can be converted back and forth.

   ---------------------------------------------------------------------------
   --  Main Bisimulation Theorem
   ---------------------------------------------------------------------------

   --  Text and DOM are semantically equivalent
   procedure Lemma_Text_DOM_Bisimulation
     with Post => (for all Input : String =>
                     (if Parse(Input).Success then
                        Semantically_Equivalent(Input, Parse(Input).Document)));

   --  Semantic equivalence relation
   function Semantically_Equivalent (Text : String;
                                     Doc : SML.DOM.Document) return Boolean
     with Pre => SML.DOM.Is_Well_Formed(Doc),
          Post => Semantically_Equivalent'Result =
                    (Same_Structure(Text, Doc) and then
                     Same_Content(Text, Doc) and then
                     Same_Order(Text, Doc));

   ---------------------------------------------------------------------------
   --  Structural Correspondence
   ---------------------------------------------------------------------------

   --  Text and DOM have same tree structure
   function Same_Structure (Text : String; Doc : SML.DOM.Document) return Boolean
     with Pre => SML.DOM.Is_Well_Formed(Doc);

   --  Count elements in text matches DOM
   procedure Lemma_Element_Count_Preserved
     with Post => (for all Input : String =>
                     (if Parse(Input).Success then
                        Count_Elements_In_Text(Input) =
                        Count_Elements_In_DOM(Parse(Input).Document)));

   --  Count elements in text representation
   function Count_Elements_In_Text (Text : String) return Natural
     with Post => Count_Elements_In_Text'Result <= Text'Length;

   --  Count elements in DOM
   function Count_Elements_In_DOM (Doc : SML.DOM.Document) return Natural
     with Pre => SML.DOM.Is_Well_Formed(Doc),
          Post => Count_Elements_In_DOM'Result <= SML.DOM.Node_Count(Doc);

   --  Nesting depth preserved
   procedure Lemma_Depth_Preserved
     with Post => (for all Input : String =>
                     (if Parse(Input).Success then
                        Max_Nesting_Depth_Text(Input) =
                        Max_Depth_DOM(Parse(Input).Document)));

   --  Get maximum nesting depth in text
   function Max_Nesting_Depth_Text (Text : String) return Natural
     with Post => Max_Nesting_Depth_Text'Result <= SML.DOM.Max_Tree_Depth;

   --  Get maximum depth in DOM
   function Max_Depth_DOM (Doc : SML.DOM.Document) return Natural
     with Pre => SML.DOM.Is_Well_Formed(Doc),
          Post => Max_Depth_DOM'Result <= SML.DOM.Max_Tree_Depth;

   ---------------------------------------------------------------------------
   --  Content Preservation
   ---------------------------------------------------------------------------

   --  Text content is preserved
   function Same_Content (Text : String; Doc : SML.DOM.Document) return Boolean
     with Pre => SML.DOM.Is_Well_Formed(Doc);

   --  All text content from input appears in DOM
   procedure Lemma_Text_Content_Preserved
     with Post => (for all Input : String =>
                     (if Parse(Input).Success then
                        All_Text_In_DOM(Input, Parse(Input).Document)));

   --  Check if all text content appears in DOM
   function All_Text_In_DOM (Text : String; Doc : SML.DOM.Document) return Boolean
     with Pre => SML.DOM.Is_Well_Formed(Doc);

   --  Element names are preserved
   procedure Lemma_Element_Names_Preserved
     with Post => (for all Input : String =>
                     (if Parse(Input).Success then
                        All_Names_Match(Input, Parse(Input).Document)));

   --  Check if all element names match
   function All_Names_Match (Text : String; Doc : SML.DOM.Document) return Boolean
     with Pre => SML.DOM.Is_Well_Formed(Doc);

   --  Entity references are correctly expanded
   procedure Lemma_Entities_Expanded_Correctly
     with Post => (for all Input : String =>
                     (if Parse(Input).Success and Contains_Entities(Input) then
                        Entities_Expanded_In_DOM(Input, Parse(Input).Document)));

   --  Check if input contains entities
   function Contains_Entities (Text : String) return Boolean;

   --  Check if entities are expanded in DOM
   function Entities_Expanded_In_DOM (Text : String; Doc : SML.DOM.Document)
                                     return Boolean
     with Pre => SML.DOM.Is_Well_Formed(Doc);

   ---------------------------------------------------------------------------
   --  Order Preservation
   ---------------------------------------------------------------------------

   --  Element and text order is preserved
   function Same_Order (Text : String; Doc : SML.DOM.Document) return Boolean
     with Pre => SML.DOM.Is_Well_Formed(Doc);

   --  Sibling order preserved
   procedure Lemma_Sibling_Order_Preserved
     with Post => (for all Input : String =>
                     (if Parse(Input).Success then
                        Sibling_Order_Matches(Input, Parse(Input).Document)));

   --  Check if sibling order matches
   function Sibling_Order_Matches (Text : String; Doc : SML.DOM.Document)
                                  return Boolean
     with Pre => SML.DOM.Is_Well_Formed(Doc);

   --  Document order traversal matches text order
   procedure Lemma_Document_Order_Preserved
     with Post => (for all Input : String =>
                     (if Parse(Input).Success then
                        Document_Order_Matches(Input, Parse(Input).Document)));

   --  Check if document order matches
   function Document_Order_Matches (Text : String; Doc : SML.DOM.Document)
                                   return Boolean
     with Pre => SML.DOM.Is_Well_Formed(Doc);

   ---------------------------------------------------------------------------
   --  Round-Trip Properties
   ---------------------------------------------------------------------------

   --  Serialize DOM back to text
   function Serialize (Doc : SML.DOM.Document) return String
     with Pre => SML.DOM.Is_Well_Formed(Doc),
          Post => Is_Valid_SML(Serialize'Result);

   --  Parse-serialize round trip (may not be identical due to whitespace)
   procedure Lemma_Parse_Serialize_Equivalent
     with Post => (for all Input : String =>
                     (if Parse(Input).Success then
                        Semantically_Equivalent(Input,
                                              Parse(Serialize(Parse(Input).Document)).Document)));

   --  Serialize-parse round trip (should be identical)
   procedure Lemma_Serialize_Parse_Identity
     with Post => (for all Doc : SML.DOM.Document =>
                     (if SML.DOM.Is_Well_Formed(Doc) then
                        DOM_Equal(Doc, Parse(Serialize(Doc)).Document)));

   --  Check if two DOM trees are equal
   function DOM_Equal (Doc1, Doc2 : SML.DOM.Document) return Boolean
     with Pre => SML.DOM.Is_Well_Formed(Doc1) and
                 SML.DOM.Is_Well_Formed(Doc2);

   ---------------------------------------------------------------------------
   --  Canonical Form
   ---------------------------------------------------------------------------

   --  Define canonical text representation
   function Canonical_Form (Text : String) return String
     with Pre => Is_Valid_SML(Text),
          Post => Is_Valid_SML(Canonical_Form'Result) and then
                  Is_Canonical(Canonical_Form'Result);

   --  Check if text is in canonical form
   function Is_Canonical (Text : String) return Boolean
     with Post => Is_Canonical'Result =
                    (No_Extra_Whitespace(Text) and then
                     No_Empty_Text_Nodes(Text) and then
                     Minimal_Quotes(Text));

   --  Canonical forms parse to same DOM
   procedure Lemma_Canonical_Unique
     with Post => (for all Text1, Text2 : String =>
                     (if Is_Valid_SML(Text1) and Is_Valid_SML(Text2) and then
                         Canonical_Form(Text1) = Canonical_Form(Text2)
                      then DOM_Equal(Parse(Text1).Document,
                                    Parse(Text2).Document)));

   ---------------------------------------------------------------------------
   --  Information Preservation
   ---------------------------------------------------------------------------

   --  No information loss during parsing
   procedure Lemma_No_Information_Loss
     with Post => (for all Input : String =>
                     (if Parse(Input).Success then
                        Can_Recover_Original_Structure(Input, Parse(Input).Document)));

   --  Check if original structure can be recovered
   function Can_Recover_Original_Structure (Original : String;
                                           Doc : SML.DOM.Document) return Boolean
     with Pre => SML.DOM.Is_Well_Formed(Doc);

   --  All significant whitespace preserved
   procedure Lemma_Significant_Whitespace_Preserved
     with Post => (for all Input : String =>
                     (if Parse(Input).Success then
                        Preserves_Significant_Whitespace(Input, Parse(Input).Document)));

   --  Check if significant whitespace is preserved
   function Preserves_Significant_Whitespace (Text : String;
                                             Doc : SML.DOM.Document) return Boolean
     with Pre => SML.DOM.Is_Well_Formed(Doc);

   ---------------------------------------------------------------------------
   --  Correspondence Functions
   ---------------------------------------------------------------------------

   --  Map text position to DOM node
   function Text_Position_To_Node (Text : String;
                                   Position : Natural;
                                   Doc : SML.DOM.Document) return SML.DOM.Node_Id
     with Pre => Position >= Text'First and Position <= Text'Last and
                 SML.DOM.Is_Well_Formed(Doc) and
                 Parse(Text).Success,
          Post => (if Text_Position_To_Node'Result /= SML.DOM.Null_Node then
                     SML.DOM.Is_Valid_Node(Doc, Text_Position_To_Node'Result));

   --  Map DOM node to text range
   function Node_To_Text_Range (Node : SML.DOM.Node_Id;
                               Doc : SML.DOM.Document;
                               Text : String) return Natural
     with Pre => Node /= SML.DOM.Null_Node and
                 SML.DOM.Is_Valid_Node(Doc, Node) and
                 Parse(Text).Success,
          Post => Node_To_Text_Range'Result >= Text'First and
                  Node_To_Text_Range'Result <= Text'Last;

   ---------------------------------------------------------------------------
   --  Whitespace Normalization
   ---------------------------------------------------------------------------

   --  Different whitespace modes produce equivalent DOMs
   procedure Lemma_Whitespace_Modes_Equivalent
     with Post => (for all Input : String =>
                     (for all Mode : Whitespace_Mode =>
                        (if Parse_With_Options(Input,
                                             (Whitespace => Mode, others => <>)).Success
                         then Structurally_Equivalent(
                                Parse(Input).Document,
                                Parse_With_Options(Input,
                                                 (Whitespace => Mode, others => <>)).Document))));

   --  Check if DOMs are structurally equivalent (ignoring text differences)
   function Structurally_Equivalent (Doc1, Doc2 : SML.DOM.Document) return Boolean
     with Pre => SML.DOM.Is_Well_Formed(Doc1) and
                 SML.DOM.Is_Well_Formed(Doc2);

   ---------------------------------------------------------------------------
   --  Helper Functions
   ---------------------------------------------------------------------------

   --  Check for extra whitespace
   function No_Extra_Whitespace (Text : String) return Boolean;

   --  Check for empty text nodes
   function No_Empty_Text_Nodes (Text : String) return Boolean;

   --  Check for minimal quote usage
   function Minimal_Quotes (Text : String) return Boolean;

   --  Traverse DOM in document order
   type DOM_Visitor is access procedure (Node : SML.DOM.Node_Id;
                                        Doc : SML.DOM.Document);

   procedure Traverse_Document_Order (Doc : SML.DOM.Document;
                                     Visit : DOM_Visitor)
     with Pre => SML.DOM.Is_Well_Formed(Doc);

   ---------------------------------------------------------------------------
   --  Induction for Bisimulation
   ---------------------------------------------------------------------------

   --  Induction principle for bisimulation proofs
   procedure Lemma_Bisimulation_Induction
     (P : access function (Text : String; Doc : SML.DOM.Document) return Boolean)
     with Pre =>
            -- Base: empty element
            (for all Tag : String =>
               (if Valid_Tag_Name(Tag) then
                  P("<" & Tag & "></" & Tag & ">",
                    Make_Empty_Element(Tag)))) and then
            -- Base: text element
            (for all Tag, Content : String =>
               (if Valid_Tag_Name(Tag) and Valid_Text(Content) then
                  P("<" & Tag & ">" & Content & "</" & Tag & ">",
                    Make_Text_Element(Tag, Content)))) and then
            -- Inductive: composition preserves property
            (for all Text1, Text2 : String =>
               for all Doc1, Doc2 : SML.DOM.Document =>
                 (if P(Text1, Doc1) and P(Text2, Doc2) then
                    P(Text1 & Text2, Compose_Documents(Doc1, Doc2)))),
          Post => (for all Text : String =>
                     for all Doc : SML.DOM.Document =>
                       (if Parse(Text).Success and then
                           DOM_Equal(Doc, Parse(Text).Document)
                        then P(Text, Doc)));

   --  Helper: check valid tag name
   function Valid_Tag_Name (Tag : String) return Boolean;

   --  Helper: check valid text content
   function Valid_Text (Content : String) return Boolean;

   --  Helper: make empty element DOM
   function Make_Empty_Element (Tag : String) return SML.DOM.Document
     with Pre => Valid_Tag_Name(Tag),
          Post => SML.DOM.Is_Well_Formed(Make_Empty_Element'Result);

   --  Helper: make text element DOM
   function Make_Text_Element (Tag, Content : String) return SML.DOM.Document
     with Pre => Valid_Tag_Name(Tag) and Valid_Text(Content),
          Post => SML.DOM.Is_Well_Formed(Make_Text_Element'Result);

   --  Helper: compose two DOMs
   function Compose_Documents (Doc1, Doc2 : SML.DOM.Document)
                              return SML.DOM.Document
     with Pre => SML.DOM.Is_Well_Formed(Doc1) and
                 SML.DOM.Is_Well_Formed(Doc2),
          Post => SML.DOM.Is_Well_Formed(Compose_Documents'Result);

end SML.Bisimulation;