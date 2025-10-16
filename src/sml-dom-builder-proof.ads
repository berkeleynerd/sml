------------------------------------------------------------------------------
--                   Simple Markup Language (SML) Library                   --
--                                                                          --
--               SPARK Proof Support - DOM Builder Package                  --
------------------------------------------------------------------------------

package SML.DOM.Builder.Proof
with
   Ghost,
   SPARK_Mode
is

   ---------------------------------------------------------------------------
   --  Ghost Functions for Builder Verification
   ---------------------------------------------------------------------------

   --  Check if a specific node is marked as deleted
   function Is_Deleted (Doc : Document; Node : Node_Id) return Boolean
     with Pre => Is_Valid_Node (Doc, Node), Global => null;

   --  Check if Node is a descendant of Ancestor (transitive child relationship)
   function Is_Descendant_Of
     (Doc : Document; Node, Ancestor : Node_Id) return Boolean
     with
       Pre => Is_Valid_Node (Doc, Node) and then Is_Valid_Node (Doc, Ancestor),
       Global => null;

   --  Verify all descendants of a node are marked deleted
   function All_Descendants_Deleted
     (Doc : Document; Root_Node : Node_Id) return Boolean
     with Pre => Is_Valid_Node (Doc, Root_Node), Global => null;

   --  Count total deleted nodes in document
   function Count_Deleted_Nodes (Doc : Document) return Natural
     with Global => null;

   --  Check if document has any deleted nodes
   function Has_Deleted_Nodes (Doc : Document) return Boolean
     with
       Global => null,
       Post => Has_Deleted_Nodes'Result = (Count_Deleted_Nodes (Doc) > 0);

   --  Check if all nodes in document are not deleted
   function No_Deleted_Nodes (Doc : Document) return Boolean
     with
       Global => null,
       Post => No_Deleted_Nodes'Result = (Count_Deleted_Nodes (Doc) = 0);

end SML.DOM.Builder.Proof;
