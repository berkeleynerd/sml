<schema>
  <simpleType>
    <name>portType</name>
    <restriction>
      <base>integer</base>
      <minValue>1</minValue>
      <maxValue>65535</maxValue>
    </restriction>
  </simpleType>

  <complexType>
    <name>portWrapperType</name>
    <simpleContent>
      <type>portType</type>
    </simpleContent>
  </complexType>

  <element>
    <name>port</name>
    <type>portWrapperType</type>
  </element>
</schema>
