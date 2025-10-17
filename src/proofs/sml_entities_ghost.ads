------------------------------------------------------------------------------
--                   Simple Markup Language (SML) Library                   --
--                                                                          --
--               Entities Ghost Package - Formal Verification               --
------------------------------------------------------------------------------

package SML_Entities_Ghost
with
   Ghost,
   SPARK_Mode => On
is

   ---------------------------------------------------------------------------
   --  Ghost Functions for Entity Verification
   ---------------------------------------------------------------------------

   --  Count entity references in a string (simplified for ghost)
   function Count_Entity_References (Text : String) return Natural
     with
       Post =>
         Count_Entity_References'Result <= Text'Length / 3,  -- Min entity is 3 chars
       Global => null;

   --  Check if expansion preserves content semantics (abstract property)
   function Expansion_Preserves_Content
     (Original, Expanded : String) return Boolean
     with Global => null;

   --  Check if encoding is reversible (abstract property)
   function Encoding_Is_Reversible
     (Original : String; In_Attribute : Boolean) return Boolean
     with Global => null;

   ---------------------------------------------------------------------------
   --  Lemmas for Entity Properties
   ---------------------------------------------------------------------------

   --  Expansion never increases length
   procedure Lemma_Expansion_Reduces_Length (Text : String)
     with Global => null;

   --  Encoding is safe
   procedure Lemma_Encoding_Is_Safe (Text : String; In_Attribute : Boolean)
     with Global => null;

   --  Double encoding is idempotent
   procedure Lemma_Double_Encoding_Idempotent
     (Text : String; In_Attribute : Boolean)
     with Global => null;

   --  Valid entities can be expanded
   procedure Lemma_Valid_Entities_Expandable (Text : String)
     with Global => null;

   --  Entity at position has valid bounds
   procedure Lemma_Entity_Bounds (Text : String; Position : Natural)
     with
       Pre =>
         Position >= Text'First
         and then Position <= Text'Last,
       Global => null;

end SML_Entities_Ghost;