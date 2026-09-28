Markdown Demonstration.

This section exercises Markdown-format commentary, complete with its many
Inweb extensions. These provide an alternative way to insert gadgets.

@h Commentary.
The content of this section is again meaningless. It exists only to test
the renderers.

Here is some _emphasis_ and **strong emphasis** and ~text struck through~.

Here is some `literal backticked text`.

Some index entries appear here, invisibly.@^index@>@.Z_X_1@>@:non-standard@>

@h Character set.
These are potentially tricky for TeX: {Knuth}. A\B. A_B. A#B. $40. A|B. 30%. 2^56.

And in backticked literal text: `{Knuth}. A\B. A_B. A#B. $40. A|B. 30%. 2^26.`

These are potentially tricky for HTML: <, &, >.

And in backticked literal text: `<, &, >`.

"Double quoted." 'Single quoted.'

In TeX variants, it's 'reasonable' to hope for "smart quotes" to be imposed, but
more questionable whether phrases like église château mañana will be accented.

@h ISO Latin-1.
Some formats can take most of Unicode, but others are more limited, and plain TeX
is stuck with a small selection of ASCII, leaving the following ragged. It's in
both tabular and untabular form because of issues with TeX rendering of table cells,
which mean that implementation of magic characters works differently in those cases.

|    |  0 |  1 |  2 |  3 |  4 |  5 |  6 |  7 |  8 |  9 |  A |  B |  C |  D |  E |  F | 
| -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | 
| 2x | SP |  ! |  " |  # |  $ |  % |  & |  ' |  ( |  ) |  * |  + |  , |  - |  . |  / | 
| 3x |  0 |  1 |  2 |  3 |  4 |  5 |  6 |  7 |  8 |  9 |  : |  ; |  < |  = |  > |  ? | 
| 4x |  @ |  A |  B |  C |  D |  E |  F |  G |  H |  I |  J |  K |  L |  M |  N |  O | 
| 5x |  P |  Q |  R |  S |  T |  U |  V |  W |  X |  Y |  Z |  [ |  \ |  ] |  ^ |  _ | 
| 6x |  ` |  a |  b |  c |  d |  e |  f |  g |  h |  i |  j |  k |  l |  m |  n |  o | 
| 7x |  p |  q |  r |  s |  t |  u |  v |  w |  x |  y |  z |  { | \| |  } |  ~ |    | 
| Ax | NB |  ¡ |  ¢ |  £ |  ¤ |  ¥ |  ¦ |  § |  ¨ |  © |  ª |  « |  ¬ | SH |  ® |  ¯ | 
| Bx |  ° |  ± |  ² |  ³ |  ´ |  µ |  ¶ |  · |  ¸ |  ¹ |  º |  » |  ¼ |  ½ |  ¾ |  ¿ | 
| Cx |  À |  Á |  Â |  Ã |  Ä |  Å |  Æ |  Ç |  È |  É |  Ê |  Ë |  Ì |  Í |  Î |  Ï | 
| Dx |  Ð |  Ñ |  Ò |  Ó |  Ô |  Õ |  Ö |  × |  Ø |  Ù |  Ú |  Û |  Ü |  Ý |  Þ |  ß | 
| Ex |  à |  á |  â |  ã |  ä |  å |  æ |  ç |  è |  é |  ê |  ë |  ì |  í |  î |  ï | 
| Fx |  ð |  ñ |  ò |  ó |  ô |  õ |  ö |  ÷ |  ø |  ù |  ú |  û |  ü |  ý |  þ |  ÿ | 

|    |  0 |  1 |  2 |  3 |  4 |  5 |  6 |  7 |  8 |  9 |  A |  B |  C |  D |  E |  F | 
| -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | 
| 2x | `SP` |  `!` |  `"` |  `#` |  `$` |  `%` |  `&` |  `'` |  `(` |  `)` |  `*` |  `+` |  `,` |  `-` |  `.` |  `/` | 
| 3x |  `0` |  `1` |  `2` |  `3` |  `4` |  `5` |  `6` |  `7` |  `8` |  `9` |  `:` |  `;` |  `<` |  `=` |  `>` |  `?` | 
| 4x |  `@` |  `A` |  `B` |  `C` |  `D` |  `E` |  `F` |  `G` |  `H` |  `I` |  `J` |  `K` |  `L` |  `M` |  `N` |  `O` | 
| 5x |  `P` |  `Q` |  `R` |  `S` |  `T` |  `U` |  `V` |  `W` |  `X` |  `Y` |  `Z` |  `[` |  `\` |  `]` |  `^` |  `_` | 
| 6x | `` ` `` |  `a` |  `b` |  `c` |  `d` |  `e` |  `f` |  `g` |  `h` |  `i` |  `j` |  `k` |  `l` |  `m` |  `n` |  `o` | 
| 7x |  `p` |  `q` |  `r` |  `s` |  `t` |  `u` |  `v` |  `w` |  `x` |  `y` |  `z` |  `{` |  bar |  `}` |  `~` |      | 
| Ax | `NB` |  `¡` |  `¢` |  `£` |  `¤` |  `¥` |  `¦` |  `§` |  `¨` |  `©` |  `ª` |  `«` |  `¬` | `SH` |  `®` |  `¯` | 
| Bx |  `°` |  `±` |  `²` |  `³` |  `´` |  `µ` |  `¶` |  `·` |  `¸` |  `¹` |  `º` |  `»` |  `¼` |  `½` |  `¾` |  `¿` | 
| Cx |  `À` |  `Á` |  `Â` |  `Ã` |  `Ä` |  `Å` |  `Æ` |  `Ç` |  `È` |  `É` |  `Ê` |  `Ë` |  `Ì` |  `Í` |  `Î` |  `Ï` | 
| Dx |  `Ð` |  `Ñ` |  `Ò` |  `Ó` |  `Ô` |  `Õ` |  `Ö` |  `×` |  `Ø` |  `Ù` |  `Ú` |  `Û` |  `Ü` |  `Ý` |  `Þ` |  `ß` | 
| Ex |  `à` |  `á` |  `â` |  `ã` |  `ä` |  `å` |  `æ` |  `ç` |  `è` |  `é` |  `ê` |  `ë` |  `ì` |  `í` |  `î` |  `ï` | 
| Fx |  `ð` |  `ñ` |  `ò` |  `ó` |  `ô` |  `õ` |  `ö` |  `÷` |  `ø` |  `ù` |  `ú` |  `û` |  `ü` |  `ý` |  `þ` |  `ÿ` | 

 SP   !   "   #   $   %   &   '   (   )   *   +   ,   -   .   /  

  0   1   2   3   4   5   6   7   8   9   :   ;   <   =   >   ?  

  @   A   B   C   D   E   F   G   H   I   J   K   L   M   N   O  

  P   Q   R   S   T   U   V   W   X   Y   Z   [   \   ]   ^   _  

  `   a   b   c   d   e   f   g   h   i   j   k   l   m   n   o  

  p   q   r   s   t   u   v   w   x   y   z   {   |   }   ~      

 NB   ¡   ¢   £   ¤   ¥   ¦   §   ¨   ©   ª   «   ¬  SH   ®   ¯  

  °   ±   ²   ³   ´   µ   ¶   ·   ¸   ¹   º   »   ¼   ½   ¾   ¿  

  À   Á   Â   Ã   Ä   Å   Æ   Ç   È   É   Ê   Ë   Ì   Í   Î   Ï  

  Ð   Ñ   Ò   Ó   Ô   Õ   Ö   ×   Ø   Ù   Ú   Û   Ü   Ý   Þ   ß  

  à   á   â   ã   ä   å   æ   ç   è   é   ê   ë   ì   í   î   ï  

  ð   ñ   ò   ó   ô   õ   ö   ÷   ø   ù   ú   û   ü   ý   þ   ÿ  

 `SP`   `!`   `"`   `#`   `$`   `%`   `&`   `'`   `(`   `)`   `*`   `+`   `,`   `-`   `.`   `/`  

  `0`   `1`   `2`   `3`   `4`   `5`   `6`   `7`   `8`   `9`   `:`   `;`   `<`   `=`   `>`   `?`  

  `@`   `A`   `B`   `C`   `D`   `E`   `F`   `G`   `H`   `I`   `J`   `K`   `L`   `M`   `N`   `O`  

  `P`   `Q`   `R`   `S`   `T`   `U`   `V`   `W`   `X`   `Y`   `Z`   `[`   `\`   `]`   `^`   `_`  

 `` ` ``   `a`   `b`   `c`   `d`   `e`   `f`   `g`   `h`   `i`   `j`   `k`   `l`   `m`   `n`   `o`  

  `p`   `q`   `r`   `s`   `t`   `u`   `v`   `w`   `x`   `y`   `z`   `{`   `|`   `}`   `~`        

 `NB`   `¡`   `¢`   `£`   `¤`   `¥`   `¦`   `§`   `¨`   `©`   `ª`   `«`   `¬`  `SH`   `®`   `¯`  

  `°`   `±`   `²`   `³`   `´`   `µ`   `¶`   `·`   `¸`   `¹`   `º`   `»`   `¼`   `½`   `¾`   `¿`  

  `À`   `Á`   `Â`   `Ã`   `Ä`   `Å`   `Æ`   `Ç`   `È`   `É`   `Ê`   `Ë`   `Ì`   `Í`   `Î`   `Ï`  

  `Ð`   `Ñ`   `Ò`   `Ó`   `Ô`   `Õ`   `Ö`   `×`   `Ø`   `Ù`   `Ú`   `Û`   `Ü`   `Ý`   `Þ`   `ß`  

  `à`   `á`   `â`   `ã`   `ä`   `å`   `æ`   `ç`   `è`   `é`   `ê`   `ë`   `ì`   `í`   `î`   `ï`  

  `ð`   `ñ`   `ò`   `ó`   `ô`   `õ`   `ö`   `÷`   `ø`   `ù`   `ú`   `û`   `ü`   `ý`   `þ`   `ÿ`  

@h Mathematics.
Zolotarev's Lemma says that $a\neq 0$ has a square root modulo a prime $p$
if and only if the rearrangement of $\lbrace 0, 1, 2, \dots, p-1\rbrace$ produced by multiplying
by $a$ is an even permutation. That is, if $\sigma(x) = ax {\rm ~mod~} p$, then
$$ \left({\frac {a}{p}}\right) = \cases{1 & if $\sigma$ even,\cr
-1 & if $\sigma$ odd.\cr} $$

@h Internal subheadings.

# Subhead level 1

## Subhead level 2

### Subhead level 3

This seems a good moment for what Markdown calls a thematic break.

-- -- --

And here are some more invisible entries.@!@^index@> @!@.Z_X_1@> @!@:non-standard@>

@h Lists and tables.
Some notable etymologies:

- Lanthanum from the Greek "lanthanein", meaning to be hidden.

- Praseodymium from the Greek "prasios", meaning leek-green, and "didymos", meaning twin.

- All of these from the mining village of Ytterby, on the Swedish island of Resaro:
	1. Terbium
	2. Erbium
	3. Yttrium
	4. Ytterbium

To tabulate:

| Element  | Name          | Usages  |
|:-------- | ------------- | -------:|
| 21 Sc    | Scandium      | aerospace alloys |
| 39 Y     | Yttrium       | tooth crowns, jet engines, light bulbs |
| 57 La    | Lanthanum     | glass additive, lenses |
| 58 Ce    | Cerium        | polishing powder, self-cleaning ovens |
| 59 Pr    | Praseodymium  | lasers, arc lights |

@h Block quotations.

> In 1787, Lieutenant Carl Axel Arrhenius found an unidentified black mineral
> in the Ytterby mine, whose purpose was to produce quartz and later feldspar.

Later on:

> In 1953, the mine was renovated and used for the storage of jet fuel, MC 77,
> but the storage method led to contamination.

We also support alerts:

> [!WARNING]
> Passenger ships of the _Waxholmsbolaget_ do not call at Ytterby pier in the
> winter months.

@h Links.
Regular Markdown links first. Here is a [typical link without problematic
characters in its URI](https://en.wikipedia.org/wiki/Acorn_System_BASIC), and a
[link with an accent in](https://en.wikipedia.org/wiki/Déclassée), and lastly
a [third link with a Hebrew letter](https://en.wikipedia.org/w/index.php?title=ℵ).

Inweb has its own slashed links, which we try next.
First //an external slashed link to Wikipedia -> https://en.wikipedia.org//,
and then //an internal one to code label A -> #A//.

@h Code extracts.
To begin with, an unfenced code extract:

	factorial = 1
	for i in range(2, n + 1):
		factorial *= i
	
	print(factorial)

And the same extract fenced:

```
factorial = 1
for i in range(2, n + 1):
    factorial *= i

print(factorial)
```

This time syntax-coloured as None:

``` none
factorial = 1
for i in range(2, n + 1):
    factorial *= i

print(factorial)
```

This time syntax-coloured as Python:

``` python
factorial = 1
for i in range(2, n + 1):
    factorial *= i

print(factorial)
```

@h Images and gadgets.

![Flag of St Lucia](stlucia.jpg)

![download: An early limerick](limerick.zip)

![embedded YouTube video](GR3aImy7dWw)

![embedded Vimeo video](204519)

![embedded SoundCloud audio](42803139)

![embedded Vimeo video at 400 by 300](204519)

![embedded SoundCloud audio at height 200](42803139)

@h Carousels. So this is a carousel by Markdown:

* (carousel "Stage 1 - Raw tree" captioned below)

	``` BoxArt
		ROOT ---> DOCUMENT
	```

* (carousel "Stage 2 - Developed tree" captioned below)

	``` BoxArt
		ROOT ---> DOCUMENT
					|
				  NODE 1  ---  NODE 2  ---  NODE 3  --- ...
	```

* (carousel "Stage 3 - Completed tree" captioned below)

	``` BoxArt
		ROOT ---> DOCUMENT
					|
				  NODE 1  ---  NODE 2  ---  NODE 3  --- ...
					|            |            |
				  text 1       text 2       text 3  ...
	```

@h A gratuitously long table.

| Atomic number | Symbol | Name |
| ------------- | ------ | ---- |
| 1 | H | Hydrogen |
| 2 | He | Helium |
| 3 | Li | Lithium |
| 4 | Be | Beryllium |
| 5 | B | Boron |
| 6 | C | Carbon |
| 7 | N | Nitrogen |
| 8 | O | Oxygen |
| 9 | F | Fluorine |
| 10 | Ne | Neon |
| 11 | Na | Sodium |
| 12 | Mg | Magnesium |
| 13 | Al | Aluminium |
| 14 | Si | Silicon |
| 15 | P | Phosphorus |
| 16 | S | Sulfur |
| 17 | Cl | Chlorine |
| 18 | Ar | Argon |
| 19 | K | Potassium |
| 20 | Ca | Calcium |
| 21 | Sc | Scandium |
| 22 | Ti | Titanium |
| 23 | V | Vanadium |
| 24 | Cr | Chromium |
| 25 | Mn | Manganese |
| 26 | Fe | Iron |
| 27 | Co | Cobalt |
| 28 | Ni | Nickel |
| 29 | Cu | Copper |
| 30 | Zn | Zinc |
| 31 | Ga | Gallium |
| 32 | Ge | Germanium |
| 33 | As | Arsenic |
| 34 | Se | Selenium |
| 35 | Br | Bromine |
| 36 | Kr | Krypton |
| 37 | Rb | Rubidium |
| 38 | Sr | Strontium |
| 39 | Y | Yttrium |
| 40 | Zr | Zirconium |
| 41 | Nb | Niobium |
| 42 | Mo | Molybdenum |
| 43 | Tc | Technetium |
| 44 | Ru | Ruthenium |
| 45 | Rh | Rhodium |
| 46 | Pd | Palladium |
| 47 | Ag | Silver |
| 48 | Cd | Cadmium |
| 49 | In | Indium |
| 50 | Sn | Tin |
| 51 | Sb | Antimony |
| 52 | Te | Tellurium |
| 53 | I | Iodine |
| 54 | Xe | Xenon |
| 55 | Cs | Caesium |
| 56 | Ba | Barium |
| 57 | La | Lanthanum |
| 58 | Ce | Cerium |
| 59 | Pr | Praseodymium |
| 60 | Nd | Neodymium |
| 61 | Pm | Promethium |
| 62 | Sm | Samarium |
| 63 | Eu | Europium |
| 64 | Gd | Gadolinium |
| 65 | Tb | Terbium |
| 66 | Dy | Dysprosium |
| 67 | Ho | Holmium |
| 68 | Er | Erbium |
| 69 | Tm | Thulium |
| 70 | Yb | Ytterbium |
| 71 | Lu | Lutetium |
| 72 | Hf | Hafnium |
| 73 | Ta | Tantalum |
| 74 | W | Tungsten |
| 75 | Re | Rhenium |
| 76 | Os | Osmium |
| 77 | Ir | Iridium |
| 78 | Pt | Platinum |
| 79 | Au | Gold |
| 80 | Hg | Mercury |
| 81 | Tl | Thallium |
| 82 | Pb | Lead |
| 83 | Bi | Bismuth |
| 84 | Po | Polonium |
| 85 | At | Astatine |
| 86 | Rn | Radon |
| 87 | Fr | Francium |
| 88 | Ra | Radium |
| 89 | Ac | Actinium |
| 90 | Th | Thorium |
| 91 | Pa | Protactinium |
| 92 | U | Uranium |
| 93 | Np | Neptunium |
| 94 | Pu | Plutonium |
| 95 | Am | Americium |
| 96 | Cm | Curium |
| 97 | Bk | Berkelium |
| 98 | Cf | Californium |
| 99 | Es | Einsteinium |
| 100 | Fm | Fermium |
| 101 | Md | Mendelevium |
| 102 | No | Nobelium |
| 103 | Lr | Lawrencium |
| 104 | Rf | Rutherfordium |
| 105 | Db | Dubnium |
| 106 | Sg | Seaborgium |
| 107 | Bh | Bohrium |
| 108 | Hs | Hassium |
| 109 | Mt | Meitnerium |
| 110 | Ds | Darmstadtium |
| 111 | Rg | Roentgenium |
| 112 | Cn | Copernicium |
| 113 | Nh | Nihonium |
| 114 | Fl | Flerovium |
| 115 | Mc | Moscovium |
| 116 | Lv | Livermorium |
| 117 | Ts | Tennessine |
| 118 | Og | Oganesson |

@h Index.
This sentence should be followed by a mechanically-constructed index.
