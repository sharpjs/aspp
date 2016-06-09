#### `EXPERIMENTAL`

I've been trying various ideas for an assembly language preprocessor.

The current iteration targets the **[vasm](http://sun.hasenbraten.de/vasm)** assembler — specifically, its **[mot](http://sun.hasenbraten.de/vasm/release/vasm_4.html)** syntax module — and provides just two capabilities:

* Execute arbitrary Ruby code and insert the result inline within assembly code.  This covers traditional preprocessor macro definition/expansion and enables many other techniques.
 
* Local identifier aliases.  `a@b` means that future occurrences of `a` will be replaced with `b`, until either identifier is redefined or a non-local label is encountered.  This enables registers to be renamed according to their usage.
