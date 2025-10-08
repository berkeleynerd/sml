------------------------------------------------------------------------------
--  SML Root Package Specification
--  Simple Markup Language - Main Package
--  SPARK Ada Implementation
------------------------------------------------------------------------------

package SML with SPARK_Mode => On, Pure is

   --  Root package for the Simple Markup Language (SML) implementation.
   --  SML is a strict subset of XML with the following restrictions:
   --    - No attributes on elements
   --    - No processing instructions
   --    - No DTD or schema declarations
   --    - No CDATA sections
   --    - No comments
   --    - No namespaces
   --    - UTF-8 encoding only
   --    - Only standard XML entities: &lt; &gt; &amp; &quot; &apos;
   --
   --  This package serves as the parent for all SML-related packages:
   --    - SML.DOM: Document Object Model
   --    - SML.Parser: Parsing and validation
   --    - SML.UTF8: UTF-8 encoding utilities
   --    - SML.Entities: Entity reference handling
   --    - SML.Proof_Helpers: Ghost code for verification

   --  Version information
   Major_Version : constant Natural := 1;
   Minor_Version : constant Natural := 0;
   Patch_Version : constant Natural := 0;

   Version_String : constant String := "1.0.0";

end SML;