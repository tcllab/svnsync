# linksync.tcl v. 1.0

The proc linksync allows deployment of files from a root location, like a 
version control check-out or backup/restore directory, to diverse locations on 
a user's computer, and collecting new edits to deployed files back into the 
root location.

Usage:

    linksync <subcommand> <args>

Subcommands:

```
  create  ?-uuid <UUID string>? <subdirectory within root> <local file|dir>

  collect ?-uuid <UUID string>? <root directory>

  deploy  ?-uuid <UUID string>? <root directory>
  
  check   ?-uuid <UUID string>? <root directory> ?<diff command prefix>?
  
  UUID
```
  
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

## Subcommands

### create

linksync's `create` subcommand makes it easy to create a symbolic link (to a 
file or directory) tagged with a universally-unique id (UUID) within a root 
directory (like a git check-out); the UUID will be specific to the computer.


### collect

Once one or more such symbolic links have been created, the `collect` 
subcommand will find in the given root directory all links tagged with the 
computer's UUID and copy the linked real file into the root directory, adjacent 
to the symbolic link file.  Then the user may perform a desired task like add 
and commit the files to a git repository, or make a backup of the directory.


### deploy

The `deploy` subcommand will do the opposite of `collect`; it will find the 
symbolic links tagged with the computer's UUID in the root directory and the 
real files next to them, and copy the real files to the location specified in 
the symbolic links.


### check

The `check` subcommand can be used for a simple check of the differences 
between the deployed files and root directory files, which may be desirable 
before doing a `collect` or a `deploy`.  By default the only output is the fact 
that the files are different; i.e., the default diff command prefix is
`diff -qr`.  If the `diff` command is unavailable, a simpler differencing check 
based only on file size will be done.

The user may specify a custom diff command prefix for the `check` subcommand.  
The pathnames of the deployed file and the root directory file will be appended 
to the command prefix and then the command will  be executed.


### UUID

The `UUID` subcommand returns the current universally-unique ID that linksync 
uses to tag symbolic links.

Each subcommand can include the switch '-uuid' as its first argument to specify 
a custom UUID string which linksync will use to search for symbolic links to 
operate on in the root directory.

## Usage

It's envisioned that a user may have several symbolic link files, each tagged 
with a UUID from a separate computer, in a root directory location 
corresponding to a single real file.  linksync's subcommands will ignore 
symbolic links not tagged with the current computer's UUID.  Thus a user may 
transport a root directory from computer to computer, and use linksync to 
collect and deploy files from/to bespoke locations on each computer.

## Copyright and License

Copyright (c) 2022 Stephen Huntley (stephen.huntley@alum.mit.edu)

License: Tcl license