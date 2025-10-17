with Example_Types; use Example_Types;

package Example_Ghost
  with Ghost, SPARK_Mode
is
   function Is_Valid (C : Counter) return Boolean
     with Post => Is_Valid'Result = (C.Value <= C.Max);

   function Value_Increased (Old_C, New_C : Counter) return Boolean
     with Post => Value_Increased'Result = 
       (New_C.Value = Old_C.Value + 1 and New_C.Max = Old_C.Max);
end Example_Ghost;
