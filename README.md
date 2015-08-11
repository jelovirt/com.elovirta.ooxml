DITA to Word plug-in
====================

A DITA-OT plug-in to generate [Office Open XML (OOXML)](https://en.wikipedia.org/wiki/Office_Open_XML) output from DITA source.

Installation
------------

Standard DITA-OT plug-in installation, see [DITA-OT documentation](http://www.dita-ot.org/2.1/user-guide/plugins-installing.html).

```shell
$ dita -install https://github.com/jelovirt/com.elovirta.ooxml/archive/master.zip
```

Running
-------

Use the `docx` transtype to create DOCX output.

```shell
$ dita -i guide.ditamap -f docx
```

Extending
---------

Use the `dotx.file` parameter to provide an alternative Word template file. To change the Word style to DITA element mapping, override `document.xsl` property with a stylesheet that changes the mappings in `block-style` and `inline-style` modes. See `docx/word/document.xsl` for example.

Compatibility
-------------

The plug-in has been developed with DITA-OT 2.1 and newer.

The the output has been tested with Microsoft® Word for Mac 2011.

License
-------

The DITA to Word plug-in is released under the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0)
