# Task 7.2 native terrain backup

Byte-identical copy made before Task 7.3 sculpting. SHA256:
`7DAC6742D83DF7F2513FB124A3514D0CD5102FF7553444B7E91CED417DEFBC4F`.

One 512 x 512 region at `(0, 0)`, 1 m spacing, heights -7 to 91.278 m.
This backup is never loaded by normal gameplay. `tools/refine_island.gd` uses
this frozen source for its explicitly requested offline sculpt pass, not the
older generator. Preserve this copy when making further hand edits.
