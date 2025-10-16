------------------------------------------------------------------------------
--                   Simple Markup Language (SML) Library                   --
--                                                                          --
--                     SPARK Proof Support - UTF8 Package                   --
------------------------------------------------------------------------------

package body SML.UTF8.Proof
with
   SPARK_Mode
is

   ---------------------------------------------------------------------------
   --  Ghost Function Implementations
   ---------------------------------------------------------------------------

   function Is_Normalized (Text : String) return Boolean is
      Prev_Space : Boolean := False;
   begin
      for I in Text'Range loop
         if Is_XML_Whitespace (Text (I)) then
            if Prev_Space or else Text (I) /= ' ' then
               return False;
            end if;
            Prev_Space := True;
         else
            Prev_Space := False;
         end if;
      end loop;

      return True;
   end Is_Normalized;

   function Is_Trimmed (Text : String) return Boolean is
   begin
      return
        Text'Length = 0
        or else (not Is_XML_Whitespace (Text (Text'First))
                 and then not Is_XML_Whitespace (Text (Text'Last)));
   end Is_Trimmed;

   function Count_UTF8_Sequences
     (Text : String; First, Last : Natural) return Natural
   is
      Count : Natural := 0;
      I     : Natural := First;
      Len   : Natural;
   begin
      while I <= Last loop
         pragma Loop_Variant (Increases => I);
         Count := Count + 1;
         Len := UTF8_Sequence_Length (Text, I);

         if Len = 0 then
            I := I + 1;
         else
            I := I + Len;
         end if;
      end loop;

      return Count;
   end Count_UTF8_Sequences;

   ---------------------------------------------------------------------------
   --  Lemma Implementations
   ---------------------------------------------------------------------------

   procedure Lemma_Substring_Valid (Text : String; First, Last : Natural) is
   begin
      null;  -- Proof by SMT solver
   end Lemma_Substring_Valid;

   procedure Lemma_ASCII_Is_Valid_UTF8 (Text : String) is
   begin
      null;  -- Proof by SMT solver
   end Lemma_ASCII_Is_Valid_UTF8;

   procedure Lemma_Navigation_Preserves_Validity
     (Text : String; Position : Natural)
   is
   begin
      null;  -- Proof by SMT solver
   end Lemma_Navigation_Preserves_Validity;

end SML.UTF8.Proof;
