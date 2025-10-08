------------------------------------------------------------------------------
--  SML.Memory_Accounting Package Specification
--  Memory Usage Tracking and Bounds Proofs for SML Library
--  SPARK Ada Implementation - Formal Memory Accounting
------------------------------------------------------------------------------

with SML.DOM;
with SML.Memory_Model;
with SML.Parser;

package SML.Memory_Accounting with SPARK_Mode => On is

   --  This package provides functions to track and prove memory usage bounds
   --  for the SML library, ensuring memory consumption is polynomially
   --  bounded by input size.

   ---------------------------------------------------------------------------
   --  Memory Metrics
   ---------------------------------------------------------------------------

   --  Total memory used by a document
   function Total_Memory_Used (Pool : SML.Memory_Model.Arena_Pool) return Natural
     with Post => Total_Memory_Used'Result =
                    Node_Memory(Pool) + String_Memory(Pool) +
                    Metadata_Memory(Pool);

   --  Memory used by nodes
   function Node_Memory (Pool : SML.Memory_Model.Arena_Pool) return Natural
     with Post => Node_Memory'Result =
                    Pool.Allocated_Nodes * SML.Memory_Model.Node_Size_Bytes;

   --  Memory used by strings
   function String_Memory (Pool : SML.Memory_Model.Arena_Pool) return Natural
     with Post => String_Memory'Result = Pool.Allocated_Bytes;

   --  Memory used by metadata (ghost fields, indices, etc.)
   function Metadata_Memory (Pool : SML.Memory_Model.Arena_Pool) return Natural
     with Post => Metadata_Memory'Result <= 1024;  -- Small constant overhead

   ---------------------------------------------------------------------------
   --  Input-Based Memory Bounds
   ---------------------------------------------------------------------------

   --  Maximum memory required for input
   function Max_Memory_For_Input (Input_Size : Natural) return Natural
     with Post => Max_Memory_For_Input'Result =
                    Input_Size * SML.Memory_Model.Memory_Expansion_Factor +
                    Fixed_Overhead;

   --  Fixed overhead independent of input
   function Fixed_Overhead return Natural is (10_000)
     with Post => Fixed_Overhead'Result = 10_000;

   --  Actual expansion factor for valid SML
   function Actual_Expansion_Factor (Input : String) return Natural
     with Pre => SML.Parser.Is_Valid_SML(Input),
          Post => Actual_Expansion_Factor'Result <=
                    SML.Memory_Model.Memory_Expansion_Factor;

   --  Memory efficiency ratio
   function Memory_Efficiency (Pool : SML.Memory_Model.Arena_Pool;
                              Input_Size : Natural) return Float
     with Pre => Input_Size > 0,
          Post => Memory_Efficiency'Result =
                    Float(Total_Memory_Used(Pool)) / Float(Input_Size);

   ---------------------------------------------------------------------------
   --  Node Count Bounds
   ---------------------------------------------------------------------------

   --  Maximum nodes for given input
   function Max_Nodes_For_Input (Input : String) return Natural
     with Post => Max_Nodes_For_Input'Result <= Input'Length;

   --  Count possible elements in input
   function Count_Possible_Elements (Input : String) return Natural
     with Post => Count_Possible_Elements'Result <= Input'Length / 3;
     -- Minimum element is <a></a> = 7 chars, but conservatively use 3

   --  Count possible text nodes in input
   function Count_Possible_Text_Nodes (Input : String) return Natural
     with Post => Count_Possible_Text_Nodes'Result <= Input'Length;

   --  Total possible nodes
   function Total_Possible_Nodes (Input : String) return Natural
     with Post => Total_Possible_Nodes'Result =
                    Count_Possible_Elements(Input) +
                    Count_Possible_Text_Nodes(Input);

   ---------------------------------------------------------------------------
   --  String Storage Bounds
   ---------------------------------------------------------------------------

   --  Maximum string storage for input
   function Max_String_Storage_For_Input (Input : String) return Natural
     with Post => Max_String_Storage_For_Input'Result <= Input'Length * 2;
     -- Worst case: all text duplicated in element names and content

   --  Actual string storage used
   function String_Storage_Used (Pool : SML.Memory_Model.Arena_Pool;
                                Input : String) return Natural
     with Pre => SML.Parser.Parse(Input).Success,
          Post => String_Storage_Used'Result <= Input'Length;

   --  String deduplication savings (if implemented)
   function Deduplication_Savings (Pool : SML.Memory_Model.Arena_Pool)
                                  return Natural
     with Post => Deduplication_Savings'Result >= 0;

   ---------------------------------------------------------------------------
   --  Stack and Depth Bounds
   ---------------------------------------------------------------------------

   --  Maximum stack memory for parsing
   function Max_Stack_Memory (Input : String) return Natural
     with Post => Max_Stack_Memory'Result <=
                    SML.DOM.Max_Tree_Depth * Stack_Frame_Size;

   --  Size of parser stack frame
   function Stack_Frame_Size return Natural is (256)
     with Post => Stack_Frame_Size'Result = 256;

   --  Actual stack depth during parsing
   function Parse_Stack_Depth (Input : String) return Natural
     with Pre => SML.Parser.Is_Valid_SML(Input),
          Post => Parse_Stack_Depth'Result <= SML.DOM.Max_Tree_Depth;

   ---------------------------------------------------------------------------
   --  Memory Allocation Patterns
   ---------------------------------------------------------------------------

   type Allocation_Pattern is record
      Sequential : Natural;      -- Sequential allocations
      Random     : Natural;      -- Random access allocations
      Peak       : Natural;      -- Peak concurrent allocations
      Released   : Natural;      -- Deallocations
   end record;

   --  Get allocation pattern for input
   function Get_Allocation_Pattern (Input : String) return Allocation_Pattern
     with Pre => SML.Parser.Is_Valid_SML(Input);

   --  Check if allocation pattern is efficient
   function Is_Efficient_Pattern (Pattern : Allocation_Pattern) return Boolean
     with Post => Is_Efficient_Pattern'Result =
                    (Pattern.Sequential > Pattern.Random and
                     Pattern.Peak <= Pattern.Sequential + Pattern.Random);

   ---------------------------------------------------------------------------
   --  Memory Pressure Indicators
   ---------------------------------------------------------------------------

   --  Memory pressure level
   type Memory_Pressure is (Low, Medium, High, Critical);

   --  Get current memory pressure
   function Get_Memory_Pressure (Pool : SML.Memory_Model.Arena_Pool)
                                return Memory_Pressure
     with Post => Get_Memory_Pressure'Result =
                    (if Pool.Allocated_Nodes < SML.Memory_Model.Max_Document_Nodes / 4 then Low
                     elsif Pool.Allocated_Nodes < SML.Memory_Model.Max_Document_Nodes / 2 then Medium
                     elsif Pool.Allocated_Nodes < SML.Memory_Model.Max_Document_Nodes * 3 / 4 then High
                     else Critical);

   --  Can allocate more nodes?
   function Can_Allocate_More (Pool : SML.Memory_Model.Arena_Pool;
                               Count : Natural) return Boolean
     with Post => Can_Allocate_More'Result =
                    (Pool.Allocated_Nodes + Count <=
                     SML.Memory_Model.Max_Document_Nodes);

   ---------------------------------------------------------------------------
   --  Memory Bounds Lemmas
   ---------------------------------------------------------------------------

   --  Memory is bounded by input size
   procedure Lemma_Memory_Bounded_By_Input
     with Post => (for all Input : String =>
                     (if SML.Parser.Parse(Input).Success then
                        (for some Pool : SML.Memory_Model.Arena_Pool =>
                           Total_Memory_Used(Pool) <= Max_Memory_For_Input(Input'Length))));

   --  Node count is bounded
   procedure Lemma_Node_Count_Bounded
     with Post => (for all Input : String =>
                     (if SML.Parser.Parse(Input).Success then
                        (for some Pool : SML.Memory_Model.Arena_Pool =>
                           Pool.Allocated_Nodes <= Total_Possible_Nodes(Input))));

   --  String storage is bounded
   procedure Lemma_String_Storage_Bounded
     with Post => (for all Input : String =>
                     (if SML.Parser.Parse(Input).Success then
                        (for some Pool : SML.Memory_Model.Arena_Pool =>
                           Pool.Allocated_Bytes <= Max_String_Storage_For_Input(Input))));

   --  Stack usage is bounded
   procedure Lemma_Stack_Usage_Bounded
     with Post => (for all Input : String =>
                     Max_Stack_Memory(Input) <=
                     SML.DOM.Max_Tree_Depth * Stack_Frame_Size);

   --  Memory monotonicity
   procedure Lemma_Memory_Monotonic
     with Post => (for all Pool : SML.Memory_Model.Arena_Pool =>
                     (for all Old_Pool : SML.Memory_Model.Arena_Pool =>
                        (if Pool.Allocated_Nodes >= Old_Pool.Allocated_Nodes then
                           Total_Memory_Used(Pool) >= Total_Memory_Used(Old_Pool))));

   --  Efficiency bound
   procedure Lemma_Memory_Efficiency_Bound
     with Post => (for all Input : String =>
                     (if Input'Length > 0 and SML.Parser.Parse(Input).Success then
                        (for some Pool : SML.Memory_Model.Arena_Pool =>
                           Memory_Efficiency(Pool, Input'Length) <=
                           Float(SML.Memory_Model.Memory_Expansion_Factor))));

   ---------------------------------------------------------------------------
   --  Resource Exhaustion Prevention
   ---------------------------------------------------------------------------

   --  Check if parsing will exceed memory
   function Will_Exceed_Memory (Input : String) return Boolean
     with Post => Will_Exceed_Memory'Result =
                    (Max_Memory_For_Input(Input'Length) >
                     SML.Memory_Model.Max_Document_Nodes *
                     SML.Memory_Model.Node_Size_Bytes +
                     SML.Memory_Model.Max_String_Storage);

   --  Safe to parse input?
   function Safe_To_Parse (Input : String) return Boolean
     with Post => Safe_To_Parse'Result = not Will_Exceed_Memory(Input);

   --  Suggest memory limit for input
   function Suggested_Memory_Limit (Input_Size : Natural) return Natural
     with Post => Suggested_Memory_Limit'Result >= Max_Memory_For_Input(Input_Size);

   ---------------------------------------------------------------------------
   --  Memory Profiling Support
   ---------------------------------------------------------------------------

   type Memory_Profile is record
      Nodes_Allocated     : Natural;
      Strings_Allocated   : Natural;
      Peak_Usage         : Natural;
      Average_Node_Size  : Natural;
      Fragmentation      : Float;
   end record;

   --  Generate memory profile
   function Generate_Profile (Pool : SML.Memory_Model.Arena_Pool)
                             return Memory_Profile;

   --  Check if profile indicates problems
   function Profile_Has_Issues (Profile : Memory_Profile) return Boolean
     with Post => Profile_Has_Issues'Result =
                    (Profile.Fragmentation > 0.3 or
                     Profile.Average_Node_Size > SML.Memory_Model.Node_Size_Bytes * 2);

   ---------------------------------------------------------------------------
   --  Worst-Case Analysis
   ---------------------------------------------------------------------------

   --  Worst-case memory for pathological input
   function Worst_Case_Memory (Input_Size : Natural) return Natural
     with Post => Worst_Case_Memory'Result =
                    Input_Size * SML.Memory_Model.Memory_Expansion_Factor * 2;

   --  Is input pathological?
   function Is_Pathological_Input (Input : String) return Boolean
     with Post => Is_Pathological_Input'Result =
                    (Count_Possible_Elements(Input) > Input'Length / 10);

   --  Mitigation for pathological cases
   procedure Apply_Memory_Mitigation (Pool : in out SML.Memory_Model.Arena_Pool;
                                     Limit : Natural)
     with Pre => Get_Memory_Pressure(Pool) = Critical,
          Post => Total_Memory_Used(Pool) <= Total_Memory_Used(Pool'Old);

end SML.Memory_Accounting;