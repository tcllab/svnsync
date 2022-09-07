# globfind.tcl v. 2.0

## Usage:

    globfind ?basedir? ?filtercmd? ?switches?
    
**Options:**

basedir - the directory from which to start the search.  Defaults to current
directory.

filtercmd - Tcl command prefix; for each file found in the basedir, the 
filename will be appended to filtercmd and the result will be evaluated.  The 
evaluation should return a boolean value; only files whose return code is true 
will be included in the final return result. ex: {file isdir}

switches - The switches will "prefilter" the results before the filtercmd is
applied.  The available switches are:

```
  -depth      - sets the number of levels down from the basedir into which the 
                filesystem hierarchy will be searched. A value of zero is
                interpreted as infinite depth.

  -pattern    - a glob-style filename-matching wildcard. ex: -pattern *.pdf

  -types      - any value acceptable to the "types" switch of the glob
                command. ex: -types {d hidden}

  -redundancy - eliminates redundant listing of real files that may occur due
                to symbolic links that link to directories within basedir (at
                the cost of slower execution). Stores names of such symbolic
                links in ::fileutil::globfind::redundant_files. Sets
                ::fileutil::globfind::REDUNDANCY to 1 if redundancies found,
                otherwise 0.
```

## Version 2.0 introduction

globfind is a directory hierarchy search utility.  It is designed to be a fast 
and simple alternative to the Tcl Library's fileutil::find.  It takes advantage 
of glob's ability to use multiple patterns to scan deeply into a directory 
structure in a single command, hence the name.

Version 2.0 is a rewrite from scratch to be faster and more compact, featureful 
and error-resilient.

On searches of large directory spaces for files matching a glob pattern, 
globfind typically runs about three times faster than fileutil::findByPattern, 
and about 150% of the speed of GNU find.

It reports symbolic links along with other files by default, but checks for
nesting of links which might otherwise lead to infinite search loops.

Unlike fileutil::find, the name of the basedir will be included in the results
if it fits the prefilter and filtercmd criteria (thus emulating the behavior of
the standard Unix GNU find utility).

Support for Tcl versions before 8.5 has been dropped.

See: https://wiki.tcl-lang.org/page/globfind

## Copyright and License

Copyright (c) 2022 Stephen Huntley (stephen.huntley@alum.mit.edu)

License: Tcl license