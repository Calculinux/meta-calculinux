# GLKTerm Interpreter Engine Configuration

GLKTerm supports multiple interactive fiction interpreter engines that can be enabled or disabled via PACKAGECONFIG options.

## Supported Interpreter Engines:
By default all interpreters are built.

### Classic Adventure Systems
- **advsys**: AdvSys interpreter support
- **scott**: Scott Adams interpreter (classic text adventures)
- **taylor**: Taylor interpreter support

### Z-machine and Glulx
- **bocfel**: Bocfel Z-machine interpreter (Infocom games)
- **glulxe**: Glulxe interpreter (modern Glulx format)
- **git**: Git interpreter (Glulx alternative)

### TADS Family
- **tads**: TADS interpreter (Text Adventure Development System)

### Hugo System
- **hugo**: Hugo interpreter support

### Alan System
- **alan2**: Alan 2 interpreter support
- **alan3**: Alan 3 interpreter support

### Other Systems
- **agility**: Agility interpreter support
- **jacl**: JACL interpreter support
- **level9**: Level 9 interpreter (Level 9 Computing games)
- **magnetic**: Magnetic Scrolls interpreter
- **plus**: Plus interpreter support
- **scare**: SCARE interpreter (ADRIFT game support)

## Customizing Engine Selection

To customize which engines are built, modify the PACKAGECONFIG line in your local.conf or recipe:

### Enable All Engines
```bitbake
PACKAGECONFIG:pn-glkterm = "advsys agility alan2 alan3 bocfel glulxe git hugo jacl level9 magnetic plus scare scott tads taylor"
```

### Minimal Build (only essential engines)
```bitbake
PACKAGECONFIG:pn-glkterm = "bocfel glulxe scott"
```

### Classic Games Focus
```bitbake
PACKAGECONFIG:pn-glkterm = "bocfel scott level9 magnetic"
```

### Modern IF Focus
```bitbake
PACKAGECONFIG:pn-glkterm = "bocfel glulxe git tads hugo"
```

## Game Format Support

Each interpreter engine supports specific game file formats:

- **Bocfel**: .z3, .z4, .z5, .z8 (Infocom Z-machine files)
- **Glulxe/Git**: .ulx, .gblorb (Glulx files)
- **Scott**: Scott Adams .dat files
- **TADS**: .gam, .t3 files
- **Hugo**: .hex files
- **Level 9**: Level 9 game files
- **Magnetic**: Magnetic Scrolls game files
- **SCARE**: .taf files (ADRIFT games)