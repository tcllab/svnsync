#!/usr/bin/env tclsh

if 0 {
########################

linksync.tcl --

Version 1.0

The proc linksync allows deployment of files from a root location, like a 
version control check-out or backup/restore directory, to diverse locations on 
a user's computer, and collecting new edits to deployed files back into the 
root location.

Usage: linksync <subcommand> <args>

Subcommands:

  create  ?-uuid <UUID string>? <subdirectory within root> <local file|dir>

  collect ?-uuid <UUID string>? <root directory>

  deploy  ?-uuid <UUID string>? <root directory>
  
  check   ?-uuid <UUID string>? <root directory> ?<diff command prefix>?
  
  UUID
  
----

Usage of the linksync procedure assumes the user may want to manage a set of 
files from a central directory of interest but deploy copies of some or all of 
those files to locations on the computer outside that directory.  It's also 
assumed that the directory of interest may be copied to other computers, and 
once there, files will need to be deployed to different and unique locations on 
those computers (such as the home directory of a user with a different 
username).  Git, for example, allows symbolic link files to be added and 
committed to a repository, but doesn't dereference the links and add the 
contents of the underlying real file to the repository.  Doing just that is 
left to the devices of the user.  linksync is designed to help with such a task.

----

## create

linksync's 'create' subcommand makes it easy to create a symbolic link (to a 
file or directory) tagged with a universally-unique id (UUID) within a root 
directory (like a git check-out); the UUID will be specific to the computer.


## collect

Once one or more such symbolic links have been created, the 'collect' 
subcommand will find in the given root directory all links tagged with the 
computer's UUID and copy the linked real file into the root directory, adjacent 
to the symbolic link file.  Then the user may perform a desired task like add 
and commit the files to a git repository, or make a backup of the directory.


## deploy

The 'deploy' subcommand will do the opposite; it will find the symbolic links 
tagged with the computer's UUID in the root directory and the real files next 
to them, and copy the real files to the location specified in the symbolic 
links.


## check

The 'check' subcommand can be used for a simple check of the differences 
between the deployed files and root directory files, which may be desirable 
before doing a 'collect' or a 'deploy'.  By default the only output is the fact 
that the files are different.  I.e., the default diff command prefix is 'diff 
-qr'.  If the 'diff' command is unavailable, a simpler differencing check based 
only on file size will be done.

The user may specify a custom diff command prefix for the 'check' subcommand.  
The pathnames of the deployed file and the root directory file will be appended 
to the command prefix and then the command will  be executed.


## UUID

The 'UUID' subcommand returns the current universally-unique ID that linksync 
uses to tag symbolic links.

Each subcommand can include the switch '-uuid' as its first argument to specify 
a custom UUID string which linksync will use to search for symbolic links to 
operate on in the root directory.

----

It's envisioned that a user may have several symbolic link files, each tagged 
with a UUID from a separate computer, in a root directory location 
corresponding to a single real file.  linksync's subcommands will ignore 
symbolic links not tagged with the current computer's UUID.  Thus a user may 
transport a root directory from computer to computer, and use linksync to 
collect and deploy files from/to bespoke locations on each computer.

Copyright (c) 2022 Stephen Huntley (stephen.huntley@alum.mit.edu)
License: Tcl license

########################
}

lappend ::auto_path [file dir [file dir [file norm [info script]]]]

########################
namespace eval ::linksync {

package provide linksync 0.1
package require fileutil::globfind 2.0

variable commandline 0
#variable diff_cmd {diff -qr}
variable diff_cmd tclDiff

proc UUID {{ino {}}} {
    if {$ino ne {}} {set UUID ino$fs(ino) ; return}
    
    file stat ~ fs
    set host {}
    catch {set host [info hostname]}
    lassign "$host ino$fs(ino)" UUID
    
    return $UUID
}

variable UUID [UUID]

proc linksync {args} {
    set UUID $::linksync::UUID
    set subargs [lassign $args subcmd]
    
    if {![string first [lindex $subargs 0] {-uuid}]} {
        set subargs [lassign $subargs trash UUID]
    }
    
    switch $subcmd {
        create {
            lassign $subargs link_dir target
            file mkdir $link_dir
            if {![file exists $target]} {errorCmd "Doesn't exist: $target"}
            if {[file isfile $link_dir]} {
                errorCmd "Can't make dir '$link_dir': file already exists."
            }
            
            try {
                return [create $link_dir $target]
            } on error outcome {
                errorCmd $outcome
            }
        }
        collect {
            set link_root $subargs
            if {![file isdir $link_root]} {
                errorCmd "Invalid directory: $link_root"
            }
            
            try {
                return [collect $link_root]
            } on error outcome {
                errorCmd $outcome
            }
        }
        check {
            lassign [
                concat $subargs [list $::linksync::diff_cmd]] checkDir diff_cmd

            if {![file isdir $checkDir]} {
                errorCmd "Invalid directory: $checkDir"
            }
            
            if {[info command $diff_cmd] ne {}} {

            } elseif {[auto_execok [lindex $diff_cmd 0]] eq {}} {
                puts stderr "\

Executable [lindex $diff_cmd 0] unavailable. Using file size for comparison.\   
                "
                set diff_cmd {}
            }

            try {
                check $checkDir $diff_cmd
            } on error outcome {
                errorCmd $outcome
            }
        }
        deploy {
            set link_root $subargs
            if {![file isdir $link_root]} {
                errorCmd "Invalid directory: $link_root"
            }
            
            try {
                return [deploy $link_root]
            } on error outcome {
                errorCmd $outcome
            }
        }
        UUID {return $UUID}
        default {
            errorCmd "
Incorrect arguments.

Usage: linksync <subcommand> <args>

Subcommands:

create  ?-uuid UUID? <link dir> <target file|dir>
collect ?-uuid UUID? <link root dir>
check   ?-uuid UUID? <link root dir> ?<diff command>?
deploy  ?-uuid UUID? <link root dir>
UUID 
            "
        }
    }
}

proc collect {link_root} {
    if {[uplevel info exists UUID]} {
        upvar UUID UUID
    } else {
        variable UUID
    }
    
    globfind $link_root -type l -pattern *.$UUID "::linksync::gf_sync collect"
}

proc deploy {link_root} {
    if {[uplevel info exists UUID]} {
        upvar UUID UUID
    } else {
        variable UUID
    }
    
    globfind $link_root -type l -pattern *.$UUID "::linksync::gf_sync deploy" 

}

proc check {checkDir {diff_cmd {}}} {
    if {[uplevel info exists UUID]} {
        upvar UUID UUID
    } else {
        variable UUID
    }
    
    variable commandline
    
    set linkfiles [
        globfind $checkDir -type l -pattern *.$UUID [
            list ::linksync::gf_check $diff_cmd
        ]
    ]
    
    if {$commandline} {return}
    
    return $linkfiles
}

proc create {link_dir target} {
    if {[uplevel info exists UUID]} {
        upvar UUID UUID
    } else {
        variable UUID
    }
    
    set linkname [
        file join [file norm $link_dir] [file tail $target]].$UUID

    file mkdir [file dir $linkname]
    file delete $linkname
    file link -symbolic $linkname $target
    return $linkname
}

#######################################################################
# globfind filter commands:
proc gf_sync {direction linkfile} {

    set source [file readlink $linkfile]
    set dest [file join [file dir $linkfile] [file tail $source]]
    
    if {$direction eq {deploy}} {
        lassign [list $source $dest] dest source
    }
    
    if {![file isfile $source] && ![file isdir $source]} {
        puts stderr "Unsupported link type: $linkfile"
        return 0
    }
    
    set backup [file dir $dest]/.[file tail $dest]

    set btrue 0
    if {[file exists $dest]} {file rename -force $dest $backup ; set btrue 1}
    
    if {[file isfile $source]} {
        try {
            file link -hard $dest $source
            file delete -force $backup
            return 1
        } on error outcome {
            puts stderr $outcome
        }
    }
    
    try {
        file copy -force $source $dest
    } on error outcome {
        if {$btrue} {file rename -force $backup $dest}
        puts stderr $outcome
        return 0
    }
    file delete -force $backup
    return 1
}

proc gf_check {diff_cmd linkfile} {
    set target [file readlink $linkfile]
    if {![file exists $target]} {puts stderr "Missing: $target" ; return 1}
    set linkname [file join [file dir $linkfile] [file tail $target]]
    
    if {[info command $diff_cmd] ne {}} {
        return [$diff_cmd $target $linkname]
    }
    
    if {$diff_cmd ne {}} {
        try {
            set diff_out [exec {*}$diff_cmd $target $linkname]
            if {$diff_out ne {}} {puts stdout $diff_out ; return 1}
        } on error outcome {
            puts stderr $outcome ; return 1
        }
        return 0
    }
    
    set ret1 [
        globfind $linkname -type f [
            list ::linksync::gf_checkdir 0 $linkname $target
        ]
    ]
    set ret2 [
        globfind $target -type f [
            list ::linksync::gf_checkdir 1 $target $linkname
        ]
    ]

    return [expr {[llength $ret1] || [llength $ret2]}]
}

proc gf_checkdir {existence_check dir1 dir2 dir1_file} {
    set path_length [llength [file split $dir1]]
    set dir2_file [
        file join $dir2 {*}[lrange [file split $dir1_file] $path_length end]
    ]
    if {![file isfile $dir2_file]} {
        puts stderr "Missing: $dir2_file"
        return 1
    }
    
    if {$existence_check} {return 0}
    
    if {[file size $dir1_file] != [file size $dir2_file]} {
        puts "Size mismatch: $dir1_file $dir2_file" ; return 1
    }

    return 0
}
#######################################################################


proc tclDiff {target linkname} {

    if {[auto_execok diff] eq {}} {
        upvar linkfile linkfile
        return [gf_check {} $linkfile]
    }
    
    set command [list diff -qr $target $linkname]
        
    lassign [chan pipe] rderr wrerr
    chan configure $wrerr -blocking 0
    set stdio [open |[concat $command [list 2>@ $wrerr]] a+]
    close $wrerr

    set stdout [read $stdio]
    set stderr [read $rderr]
    close $rderr
    try {
        close $stdio
        return 0
    } trap CHILDSTATUS {outcome opts} {
        lassign [dict get $opts -errorcode] trash trash exitcode
        switch $exitcode {
            1 {
                puts [string trim $stdout]
            }
            2 {
                puts stderr [string trim $stderr]
            }
        }
    }
    
    return 1
}

proc errorCmd {errMsg} {
    variable commandline
    if {$commandline} {
        puts stderr [string trim $errMsg]
        exit 1
    }

    error $errMsg
}

namespace import ::fileutil::globfind::globfind
namespace export linksync

} ; # end namespace eval ::linksync
########################

if {[file norm [info script]] eq [file norm $::argv0]} {
    set ::linksync::commandline 1
    namespace import ::linksync::linksync
    catch {linksync {*}$::argv} result opts
    if {[dict get $opts -code]} {puts $result ; exit 1}
    if {[string trim [join $result \n]] ne {}} {
        puts [string trim [join $result \n]]
    }
    exit
}