package body Example_Ghost
  with SPARK_Mode
is
   function Is_Valid (C : Counter) return Boolean is
   begin
      return C.Value <= C.Max;
   end Is_Valid;

   function Value_Increased (Old_C, New_C : Counter) return Boolean is
   begin
      return New_C.Value = Old_C.Value + 1 and New_C.Max = Old_C.Max;
   end Value_Increased;
end Example_Ghost;
