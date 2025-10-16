------------------------------------------------------------------------------
--                   Simple Markup Language (SML) Library                   --
--                                                                          --
--                   SPARK Proof Support - Entities Package                 --
------------------------------------------------------------------------------

package SML.Entities.Proof
with
   Ghost,
   SPARK_Mode
is

   ---------------------------------------------------------------------------
   --  Ghost Functions for Entity Verification
   ---------------------------------------------------------------------------

   --  Count entity references in a string
   function Count_Entity_References (Text : String) return Natural
     with
       Post =>
         Count_Entity_References'Result <= Text'Length / 3,  -- Min entity is 3 chars
       Global => null;

   --  Check if expansion preserves content semantics
   function Expansion_Preserves_Content
     (Original, Expanded : String) return Boolean
     with
       Pre =>
         All_Entities_Valid (Original) and then No_Entity_References (Expanded),
       Global => null;

   --  Check if encoding is reversible
   function Encoding_Is_Reversible
     (Original : String; In_Attribute : Boolean) return Boolean
     with
       Global => null,
       Post =>
         Encoding_Is_Reversible'Result =
           (Expand_Entities (Encode_Entities (Original, In_Attribute)) = Original);

   ---------------------------------------------------------------------------
   --  Lemmas for Entity Properties
   ---------------------------------------------------------------------------

   --  Expansion never increases length
   procedure Lemma_Expansion_Reduces_Length (Text : String)
     with
       Pre => All_Entities_Valid (Text),
       Post => Expand_Entities (Text)'Length <= Text'Length,
       Global => null;

   --  Encoding is safe
   procedure Lemma_Encoding_Is_Safe (Text : String; In_Attribute : Boolean)
     with
       Post =>
         Is_Entity_Safe (Encode_Entities (Text, In_Attribute), In_Attribute),
       Global => null;

   --  Double encoding is idempotent
   procedure Lemma_Double_Encoding_Idempotent
     (Text : String; In_Attribute : Boolean)
     with
       Pre => Is_Entity_Safe (Text, In_Attribute),
       Post => Encode_Entities (Text, In_Attribute) = Text,
       Global => null;

   --  Valid entities can be expanded
   procedure Lemma_Valid_Entities_Expandable (Text : String)
     with
       Pre => All_Entities_Valid (Text),
       Post => No_Entity_References (Expand_Entities (Text)),
       Global => null;

   --  Entity at position has valid bounds
   procedure Lemma_Entity_Bounds (Text : String; Position : Natural)
     with
       Pre =>
         Position >= Text'First
         and then Position <= Text'Last
         and then Has_Valid_Entity_At (Text, Position),
       Post => Position + Entity_Length_At (Text, Position) - 1 <= Text'Last,
       Global => null;

end SML.Entities.Proof;
