package body Example
  with SPARK_Mode
is
   function Create (Max : Natural) return Counter is
   begin
      return (Value => 0, Max => Max);
   end Create;

   procedure Increment (C : in out Counter) is
   begin
      C.Value := C.Value + 1;
   end Increment;
end Example;
