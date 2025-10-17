with Example_Types; use Example_Types;
with Example_Ghost;

package Example
  with SPARK_Mode
is
   function Create (Max : Natural) return Counter
     with Post => Example_Ghost.Is_Valid (Create'Result);

   procedure Increment (C : in out Counter)
     with 
       Pre  => C.Value < C.Max,
       Post => Example_Ghost.Value_Increased (C'Old, C);
end Example;
