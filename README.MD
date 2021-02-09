# The Reconstruction of ZZT

The Reconstruction of ZZT is a reverse-engineered recreation of the source code to the last official release of
[ZZT](https://museumofzzt.com/about-zzt), ZZT 3.2. The output executable is byte-for-byte identical with said
release, which means that the source code accurately represents the original engine's behavior.

The intent behind this project is to facilitate improved preservation and accessibility of ZZT's worlds and community,
as well as facilitate new, exciting developments.

## Frequently Asked Questions

### What is ZZT?

ZZT is an adventure game created by Tim Sweeney and released in January 1991 for DOS computers. What set it apart was the
inclusion of a fully-featured world editor in the shareware release. Since then, ZZT has gone on to inspire thousands of
players and game creators all around the world.

You can learn more about ZZT through the [Museum of ZZT](https://museumofzzt.com/about-zzt).

### How can I run the original ZZT on a modern computer?

There are many ways to run ZZT on a modern PC. While pretty much anything capable of running DOS will do the trick, the recommended ones are:

 * **[Zeta](http://zeta.asie.pl)**, an emulator dedicated to running ZZT's original engine (Windows, Linux, macOS, HTML5),
 * [DOSBox](https://www.dosbox.com/), a general DOS software emulator.

### Where can I find ZZT worlds to play?

The official ZZT worlds originally released with the game can be found [here](https://museumofzzt.com/file/z/zzt.zip).

Beyond that, I highly recommend checking out the [Museum of ZZT](https://museumofzzt.com/), particularly its Featured
Games section, to find amazing worlds created by the ZZT community over the past three decades.

### How can I create ZZT worlds of my own?

ZZT comes with a built-in editor and documentation - just press "E"!

However, please note that the community has since created more powerful editors, the most popular of which is [KevEdit](https://github.com/cknave/kevedit/releases).
This is currently the recommended solution. Dr. Dos has created a [live stream series](https://www.youtube.com/watch?v=suIKp6HLBC8&list=PL71MurckxMeDCeOrKZ5Gd58GtC1ZmU-BW)
on YouTube detailing how to use Zeta and KevEdit to create your own ZZT worlds.

### How was the source code reconstructed?

Very patiently! I wrote [an article on my blog](https://blog.asie.pl/2020/08/reconstructing-zzt/) in an attempt to describe the journey, as well as the tools and 
techniques I utilized in the process.

### What is part of this open-source release?

This release's binary distribution includes:

 * **ZZT.EXE** - the ZZT engine executable,
 * **ZZT.DAT** - the documentation originally included with ZZT,
 * **DEMO.ZZT** - the official demonstration world, part of ZZT's bundled documentation,
 * **ZZT.CFG** - the ZZT configuration file (set to open DEMO.ZZT by default).

The source code includes the source format for both ZZT.EXE and ZZT.DAT, as well as relevant tools.

### Why did the source code have to be reconstructed?

This is because the original source code to ZZT
[was lost a long time ago](https://web.archive.org/web/19991010013339/http://www.epicgames.com/zzt.htm).

### I'm a ZZTer from back in the day and I have some backups from that period. Are they still useful?

**Yes!** There are many ZZT worlds, utilities, and other documents which have not yet been preserved. If you'd like to share them and see them be
adequately catalogued and preserved, please contact me at (kontakt at asie dot pl) - or get in touch with the Museum of ZZT community.

## Directory structure

* **BIN** - output directory for EXE and TPU files,
* **DIST** - output directory for the binary distribution,
* **DOC** - documentation files used for building ZZT.DAT:
    * **ABOUT.HLP** - about text,
    * **GAME.HLP** - help text (play),
    * **EDITOR.HLP** - help text (editor):
      * **CREATURE.HLP**, **TERRAIN.HLP**, **ITEM.HLP**, **LANG.HLP**, **LANGREF.HLP**, **LANGTUT.HLP**, **INFO.HLP** - additional help text,
    * **LICENSE.HLP** - licensing terms for the source code release, formatted for in-game view,
    * END1.MSG, END2.MSG, END3.MSG, END4.MSG - registration messages for the shareware version of ZZT; not present,
* **MISC** - miscellaneous files which are not part of the build process:
    * **relocfix.py** - Python 3 script for fixing relocation table segments in EXE binaries after LZEXE decompression,
* **RES** - resource files which are not otherwise recompiled:
    * **DEMO.ZZT** - the official ZZT demonstration world,
    * **ZZT.CFG** - the ZZT configuration file used for the binary distribution,
* **SRC** - the reconstructed ZZT source code,
    * **ZZT.PAS** - main source file,
* **TOOLS** - tools used when building:
    * **DATPACK.PAS** - DATPACK, a tool for creating and extracting the ZZT.DAT file (source code),
    * **LZEXE.EXE** - LZEXE, a .EXE compression tool by Fabrice Bellard,
* **BUILD.BAT** - source code build script,
* **LICENSE.TXT** - licensing terms for the source code release.

## License

The Reconstruction of ZZT is licensed under the terms of the MIT license as described in LICENSE.TXT, with the exception of certain files included with this release:

* **TOOLS/LZEXE.DOC**, **TOOLS/LZEXE.EXE**:

```
    LZEXE.EXE v0.91    (c) 1989 Fabrice BELLARD

    Ce programme fait parti du domaine public (FREEWARE),  donc vous pouvez
  l'utiliser, le copier et le distribuer sans problème. Et vous pouvez même
  en faire un usage commercial, c'est à dire compacter des fichiers EXE que
  vous allez vendre. Mais la vente de LZEXE.EXE est interdite.
```

* **MISC/relocfix.py**: Copyright (c) 2020 Adrian Siekierka, licensed under "zero-clause" BSD

## Compiling

### Requirements

* DOS-compatible environment (f.e. DOSBox),
* Turbo Pascal 5.5 (if you don't have it, it's officially available for free via Embarcadero's Antique Software website).

### Instructions

1. Ensure that TPC.EXE from Turbo Pascal is available on your PATH (f.e. `SET PATH=C:\TP;%PATH%`).
2. From the source code directory, run `BUILD.BAT`.
3. The DIST directory will contain files comprising the release as outlined in the FAQ.

If the source code has not been modified, the resulting **ZZT.EXE** file should be byte-for-byte identical with the **ZZT.EXE** bundled with ZZT 3.2.

### Compilation FAQ

#### Can the Reconstruction be compiled with Free Pascal instead?

If you'd rather stick to an entirely free software stack for building ZZT, that is also possible, albeit not without modifications:

 * Ideally, the latest SVN trunk version of Free Pascal should be used.
 * Free Pascal must be compiled as a DOS/i8086 cross-compiler in the Large memory model ([more information](https://wiki.freepascal.org/DOS)).
 * The compilation flags "-Mtp" and "-WmLarge" must be used.
 * The methods in VIDEO.PAS using inline(...) must be rewritten, as Free Pascal does not support this form of inline ASM code.
 * SOUNDS.PAS must be patched, as Free Pascal does not support overlapping CASE statements.
 * As LZEXE is not free software (source unavailable), you may want to consider removing it from your build process or replacing it with another compressor,
such as UPX (with the --8086 flag).

Please note that, as Free Pascal's RTL is significantly larger, the resulting binary is likewise about 40KB larger - leaving less memory space for game worlds.

#### What are all the "unk"-prefixed variables?

These are variables which are not used at all anywhere in the source code, but are assumed to exist in the stack or data segments, affecting relevant
variable offsets and stack checks. They are required for byte-level equivalence, but you are free to remove them and get a functionally equivalent
version of the engine - with the exception of some structures, like TStat, which are serialized to disk.

### Recipe for five better friends

1. Fix 5 annoying bugs in ZZT.
2. Give a copy of each bugfix to a friend, neighbor or business associate.
3. You now have five better friends.

## Greetings

I'd like to thank everyone who has spent the last few years contributing to the rebirth of the small ZZT community. It is thanks to your passion and dedication
that this project has been made possible.
