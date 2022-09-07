#!/usr/bin/env tclsh

# Copyright (c) 2021 Stephen E. Huntley <stephen.huntley@alum.mit.edu>
# License: Tcl License

namespace eval ::svnsync {

#################################################################

variable syntax {$svnsync PATH URL [-log_message <TEXT>] [-autoconfirm]}

variable help {

PATH: Local writable directory to be turned into a Subversion working
	checkout.

URL: Subversion repository URL. Repository subdirectory will be created within
	base repository location if it doesn't exist.

-log_message: Text to be used for log entry when commmitting changes.

-autoconfirm: Don't ask user for confirmation before final commit of changes.
	Runs the command non-interactively.

------------------------

Syncs the contents of any local directory to any location within a Subversion
repository.  Adds and deletes files within the repository as necessary.

The local checkout directory is left unchanged; this includes final deletion of
the .svn subdirectory, so the local directory is no longer a valid Subversion
working checkout when the command completes.

The checkout status is output before committing, so the user knows what changes
are to be made to the repository.  User is given a chance to abort before
committing changes, unless the -autoconfirm option is specified.

Updates and merges are beyond the scope of this command.  If necessary they
must be done independently by the user before executing svnsync.  If desired,
the user may kill the program (e.g., ctrl-c) at the point of commit
confirmation, in which case the local directory will remain as a Subversion
working checkout and the user can make changes using Subversion's tools.  The
user may then commit, or (after deleting the .svn subdirectory) run svnsync
again.

}
#################################################################

proc help {} {
	variable syntax
	variable help
	
	set svnsync svnsync
	if {[file tail $::argv0] eq {svnsync.tcl}} {
		set svnsync svnsync.tcl
	}
	
	puts "syntax: [subst -nocom $syntax]\n"
	puts [string trim $help]
}

proc deleteExtraFiles {existing_list} {
	upvar PATH PATH

	set fileListReverse [lreverse [split [exec svn list $PATH -R] \n]]

	lappend dirList
	lappend checkoutFileList
	foreach flr $fileListReverse {
		set flr [file join $PATH $flr]
		if {[file isdir $flr]} {lappend dirList $flr ; continue}
		if { ($flr ni $existing_list) && [file exists $flr] } {
			lappend checkoutFileList $flr
		}
	}

	if {[llength $checkoutFileList]} {
		puts "Extra checked out files; to be removed:"
		puts [join $checkoutFileList \n]\n
	}
	
	foreach cfl $checkoutFileList {
		exec svn delete [file join $PATH $cfl@]
	}

	foreach dir $dirList {
		set dir [file join $PATH $dir]
		if {[glob -nocomplain $dir/*] eq {}} {
			exec svn delete $dir@
		}
	}
}

proc svnsync {args} {

	if {2 > [llength $args] || [llength $args] > 5} {
		help
		return
	}

	set log_message "svn sync [clock format [clock seconds]]"

	#set args $::argv

	if {[set autoconfirm [lsearch $args -a*]] > -1} {
		set autoconfirm_val [lindex $args $autoconfirm]
		if {[string first $autoconfirm_val {-autoconfirm}]} {
			error "Incorrect flag: $autoconfirm_val . Must be -autoconfirm or -log_message"
		}
		set args [lreplace $args $autoconfirm $autoconfirm]
		set autoconfirm 1
	} else {
		set autoconfirm 0
	}

	if {![expr {!([llength $args]%2)}]} {
		error "Incorrect arguments: $args"
	}

	set lkey [dict keys $args {-l*}]
	if {[string first $lkey {-log_message}]} {
		error "Incorrect argument: $lkey . Must be -autoconfirm or -log_message"
	}
	set log_message [dict get $args $lkey]
	set args [dict remove $args $lkey]

	lassign $args PATH URL

	if {"$URL$PATH" in [list $URL $PATH {}]} {
		error "Missing argument(s): must specify URL and checkout dir: $URL $PATH"
	}

	set PATH [file norm $PATH]
	if {![file isdir $PATH]} {
		error "Checkout value is not a valid directory: $PATH"
	}

	puts "autoconfirm: $autoconfirm\nlog message: $log_message\nPATH: $PATH\nURL: $URL\n"

	if {[file exists [file join $PATH .svn]]} {
		error ".svn directory exists, delete before proceeding."
	}

	catch {exec svn mkdir $URL --parents -m "svn sync add directory"}

	try {
	#############

		set co_output [exec svn checkout $URL $PATH --force]
		set co_output_list [split $co_output \n]

		unset -nocomplain existing_list
		lappend existing_list
		foreach coo $co_output_list {
			if {[string index $coo 0] eq {E}} {
				lappend existing_list [file norm [string trimleft [string range $coo 1 end]]]
			}
		}

		deleteExtraFiles $existing_list

		exec svn add $PATH --force --auto-props

		set status [exec svn status $PATH]

		if {[string trim $status] eq {}} {
			puts "No changes to commit."
			return
		}

		puts Status:
		puts $status\n\n

		if {!$autoconfirm} {
			puts -nonewline "Proceed? (Y/n): "
			flush stdout
			if {[gets stdin] ni {Y y {} } } {
			puts	"Aborted."
					return
			}
		}

		exec svn commit $PATH -m $log_message --non-interactive

		file delete -force [file join $PATH .svn]

		puts "Subversion sync complete."

	#############
	} finally {

		if {[file isdir [file join $PATH .svn]]} {
			if {![info exists existing_list]} {
				puts "Something went wrong with Subversion checkout.  Clean up workspace before trying again."
			} else {
				deleteExtraFiles $existing_list
				file delete -force [file join $PATH .svn]
			}
		}

	}

}

namespace export -clear svnsync

}; ####################### end namespace ::svnsync

namespace eval :: {namespace import ::svnsync::svnsync}

if {[file tail $::argv0] eq {svnsync.tcl}} {
	if {[catch {svnsync {*}$::argv} err]} {
		puts stderr $err
		set svnsync svnsync.tcl
		puts stderr "\nsyntax: [subst -nocom $::svnsync::syntax]"
		puts stderr "Type 'svnsync.tcl help' for more."
		exit 1
	}
}