package Example_Types
  with SPARK_Mode
is
   type Counter is record
      Value : Natural;
      Max   : Natural;
   end record
     with Predicate => Value <= Max;
end Example_Types;
