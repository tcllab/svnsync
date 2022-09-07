#!/usr/bin/env tclsh

if 0 {
########################

globfind.tcl --

Version 2.0

The proc globfind is a replacement for tcllib's fileutil::find

Usage: globfind ?basedir? ?filtercmd? ?switches?

Options:

basedir - the directory from which to start the search.  Defaults to current
directory.

filtercmd - Tcl command; for each file found in the basedir, the filename will
be appended to filtercmd and the result will be evaluated.  The evaluation
should return a boolean value; only files whose return code is true will be
included in the final return result. ex: {file isdir}

switches - The switches will "prefilter" the results before the filtercmd is
applied.  The available switches are:

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

----

globfind is designed to be a fast and simple alternative to fileutil::find.
It takes advantage of glob's ability to use multiple patterns to scan deeply
into a directory structure in a single command, hence the name.

It reports symbolic links along with other files by default, but checks for
nesting of links which might otherwise lead to infinite search loops.

Unlike fileutil::find, the name of the basedir will be included in the results
if it fits the prefilter and filtercmd criteria (thus emulating the behavior of
the standard Unix GNU find utility).

globfind is generally two to three times faster than fileutil::find, and
fractionally faster than perl's File::Find function for comparable searches.

Support for Tcl versions before 8.5 has been dropped.

See: https://wiki.tcl-lang.org/page/globfind

Copyright (c) 2022 Stephen Huntley (stephen.huntley@alum.mit.edu)
License: Tcl license

########################
}


########################
namespace eval ::fileutil::globfind {
	package provide fileutil::globfind 2.0
	package require Tcl 8.5

	variable commandline 0

proc globfind {args} {
	variable commandline
	variable REDUNDANCY
	variable redundant_files

	set root .
	set types {}
	set customPattern *
	set globFiles [dict create]
	set maxDepth 0
	set depth 0
	set lastGlob 0
	set filtercmd {}
	set defaults [list]
	unset -nocomplain REDUNDANCY redundant_files

if 0 {
	# Full 16-level search pattern.  For experimental use only.
	# The code will work with any number of these lines removed from the end:
	set globPattern {
*
*/*
*/*/*
*/*/*/*
*/*/*/*/*
*/*/*/*/*/*
*/*/*/*/*/*/*
*/*/*/*/*/*/*/*
*/*/*/*/*/*/*/*/*
*/*/*/*/*/*/*/*/*/*
*/*/*/*/*/*/*/*/*/*/*
*/*/*/*/*/*/*/*/*/*/*/*
*/*/*/*/*/*/*/*/*/*/*/*/*
*/*/*/*/*/*/*/*/*/*/*/*/*/*
*/*/*/*/*/*/*/*/*/*/*/*/*/*/*
*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*
	}
}

	# Pattern that gives optimal performance:
	set globPattern {
*
*/*
	}

	
#######################################################################
# Argument Handling:
	set argLength [llength $args]
	for {set i 0} {$i < $argLength} {incr i} {
		switch -glob [set val [lindex $args $i]] {
			-d* {
				if {[string first $val {-depth}]} {continue}
				set maxDepth [lindex $args $i+1]
				incr i
			}
			-p* {
				if {[string first $val {-pattern}]} {continue}
				set customPattern [lindex $args $i+1]
				incr i
			}
			-t* {
				if {[string first $val {-types}]} {continue}
				set types [lindex $args $i+1]
				incr i
			}
			-r* {
				if {[string first $val {-redundancy}]} {continue}
				set globPattern "\n*\n"
				set REDUNDANCY 0
			} default {
				lappend defaults $val
			}
		}
	}

	lassign $defaults val1 val2
	switch [llength $defaults] {
		0 {}
		1 {
			if {[file exist $val1]} {
				set root $val1
			} else {
				set filtercmd $val1
			}
		}
		2 {
			if {![file exist $val1]} {
				errorCmd "\
'$val1' : No such file or directory \
"			}
			lassign $defaults root filtercmd
		}
		default {
			errorCmd "\
Incorrect arguments:
globfind  ?<base dir>? ?<filter command>?
	?-depth <integer>? ?-pattern <globpattern>?
	?-types <file attributes>? ?-redundancy? \
"			}
	}
#######################################################################
	
	# Define normalized basedir for later infinite loop test.
	# If globfind is being run recursively, grab existing normed basedir:
	set root_norm [uplevel {  if {[info exists root_norm]} {set root_norm}  }]
	if {$root_norm eq {}} {
		set root_norm [file dir [file normalize [file join $root \x00dummy]]]
		
		# Test if basedir is to be included in results:
		if {$root_norm in [
				glob -nocomplain \
					-type $types -dir [file dir $root_norm] $customPattern
		]} {
			if {$filtercmd eq {}} {
				dict set globFiles $root {}
			} elseif {[{*}$filtercmd $root]} {
				dict set globFiles $root {}
			}
		}
		
		#if {$commandline && [llength $globFiles]} {puts $globFiles}
if {$commandline && [dict size $globFiles]} {puts [dict keys $globFiles]}
	} else {
		set globFiles [dict create]
	}
	
	if {![file isdir $root]} {
		return [dict keys $globFiles]
	}
	
	# Apply custom glob pattern to default glob string:
	lappend map \n*\n ; lappend map \n$customPattern\n
	lappend map /*\n  ; lappend map /$customPattern\n
	set globDirPattern [lindex [split [string trim $globPattern] \n] end]
	
	set globPatternList [split [string trim [string map $map $globPattern]] \n]
	set depthIncr [llength $globPatternList]

	lappend dirsToGlob $root
	
	set dirDepth [llength [file split $root]]

	# Main loop for globbing files:
	while {[llength $dirsToGlob]} {
		set globTop [lindex $dirsToGlob 0]
		set dirsToGlob [lrange $dirsToGlob 1 end]

		if {![file readable $globTop]} {
			puts stderr "couldn't read directory \"$globTop\": permission denied"
			continue
		}
		
		# Test if all dirs at current search depth have been globbed.
		# If so, increment search depth:
		if {[llength [file split $globTop]] > $dirDepth} {
			set dirDepth [llength [file split $globTop]]
			incr depth $depthIncr
		}

		# If current search depth is greater that max depth,
		# truncate glob pattern:
		if {$maxDepth && [expr {$depth + $depthIncr} > $maxDepth]} {
			set depthRemaining [expr $maxDepth - $depth]
			set globPatternList [lrange $globPatternList 0 $depthRemaining-1]
			incr lastGlob
		}

		# Glob all files/dirs through current search depth increment:
		if {[catch {
			set newFiles [
				glob -nocomplain -type $types -dir $globTop {*}$globPatternList
			]
		} newFileErr opts]} {
			# If a dir within current search depth increment is unreadable,
			# call globfind recursively to exclude unreadable dir:
			set newFiles [
				# get all items at top of current search depth:
				glob -nocomplain -type $types -dir $globTop [
					lindex $globPatternList 0
				]
			]
			
			set d 0 ; if {$maxDepth} {set d [expr $maxDepth - 1]}
			set r {} ; if {[info exists REDUNDANCY]} {set r -r}
			
			# call globfind on each dir at top level of current search dir:
			set cl $commandline
			set commandline 0
			foreach newDir [glob -nocomplain -type d -dir $globTop *] {
				lappend newFiles {*}[
					globfind \
						$newDir $filtercmd \
						-d $d -p $customPattern -t $types {*}$r
				]
			}
			set commandline $cl
		}
		
		# Test each newly-found item with filtercmd before including in result:
		if {$filtercmd ne {}} {
			foreach nF $newFiles {
				if {[{*}$filtercmd $nF]} {
					dict set globFiles $nF {}
					if {$commandline} {puts $nF}
				}
			}
		} else {
			foreach nF $newFiles {
				dict set globFiles $nF {}
			}
			if {$commandline && $newFiles ne {}} {puts [string trim [join $newFiles \n]]}
		}
		
		# If globfind has been called recursively in current loop,
		# move on to next loop:
		if {[dict get $opts -code]} {continue}
		
		# If max search depth has been reached, skip search for new dirs:
		if {$lastGlob} {continue}
		
		# Find new dirs to glob at bottom of current search depth increment:
		set globDirs [glob -nocomplain -type d -dir $globTop $globDirPattern]
		catch {set globDirs_full [glob -nocomplain -type d -dir [file norm $globTop] $globDirPattern]}

		# Exclude symbolic link dirs that may create infinite search loop:
		foreach gD $globDirs gD_full $globDirs_full {
			set gD_norm [file dir [file normalize [file join $gD \x00dummy]]]
			if {$gD_norm eq $gD_full} {lappend dirsToGlob $gD ; continue}

			if {[string first $root_norm $gD_norm] == 0
					||
				[string first $gD_norm $gD_full] == 0
			} {
				# store excluded dirs in namespace vars for later inspection:
				if {[info exists REDUNDANCY]} {
					lappend redundant_files $gD_full
					set REDUNDANCY 1
				}
				continue
			}
			
			lappend dirsToGlob $gD
		}
	}

	return [dict keys $globFiles]
}

# If script being run from shell, send error message to stderr:
proc errorCmd {errMsg} {
	if {$::fileutil::globfind::commandline} {
		puts stderr $errMsg
		exit 1
	}
	
	error $errMsg
}

namespace export globfind

} ; # end namespace eval ::fileutil::globfind
########################

namespace eval :: {namespace import ::fileutil::globfind::globfind}

if {[file norm [info script]] eq [file norm $::argv0]} {
	set ::fileutil::globfind::commandline 1 
	catch {globfind {*}$::argv} result opts
	if {[dict get $opts -code]} {puts $result ; exit 1}
	exit
}














########################
# Following are sample filter commands that can be used with globfind:

namespace eval ::fileutil::globfind {

# scfind: a command suitable for use as a filtercmd with globfind, arguments
# duplicate a subset of GNU find args.

proc scfind {args} {
	set filename [file join [pwd] [lindex $args end]]
	set switches [lrange $args 0 end-1]

	array set types {
		f	file
		d	directory
		c	characterSpecial
		b	blockSpecial
		p	fifo
		l	link
		s	socket
	}

	array set signs {
		- <
		+ >
	}

	array set multiplier {
		time 86400
		min   3600
	}
	file stat $filename fs
	set pass 1
	set switchLength [llength $switches]
	for {set i 0} {$i < $switchLength} {incr i} {
		set sw [lindex $switches $i]
		switch -- $sw {
			-type {
				set value [lindex $switches [incr i]]
				if ![string equal $fs(type) $types($value)] {return 0}
			}
			-regex {
				set value [lindex $switches [incr i]]
				if ![regexp $value $filename] {return 0}
			}
			-size {
				set value [lindex $switches [incr i]]
				set sign "=="
				if [info exists signs([string index $value 0])] {
					set sign $signs([string index $value 0])
					set value [string range $value 1 end]
				}
				set sizetype [string index $value end]
				set value [string range $value 0 end-1]
				if [string equal $sizetype b] {set value [expr $value * 512]}
				if [string equal $sizetype k] {set value [expr $value * 1024]}
				if [string equal $sizetype w] {set value [expr $value * 2]}

				if ![expr $fs(size) $sign $value] {return 0}
			}
			-atime -
			-mtime -
			-ctime -
			-amin -
			-mmin -
			-cmin {
				set value [lindex $switches [incr i]]

				set sw [string range $sw 1 end]
				set time "[string index $sw 0]time"
				set interval [string range $sw 1 end]
				set sign "=="
				if [info exists signs([string index $value 0])] {
					set sign $signs([string index $value 0])
					set value [string range $value 1 end]
				}
				set value [
					expr [clock seconds] - ($value * $multiplier($interval))
				]
				if ![expr $value $sign $fs($time)] {return 0}
			}
 		}
	}
	return 1
}

# find: example use of globfind and scfind to duplicate a subset of the
# command line interface of GNU find.
# ex: 
#	find $env(HOME) -type l -atime +1

proc find {args} {
	globfind [lindex $args 0] [list [subst "scfind $args"]]
}

} ; # end namespace eval ::fileutil::globfind