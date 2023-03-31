# svnsync.tcl v. 1.1

## Usage:

    svnsync PATH URL ?-log_message <TEXT>? ?-autoconfirm?

**PATH** - Pathname of the local directory to be backed up.

**URL**  - Address of Subversion repository location where contents of PATH are
           to be stored.
           
**-log_message** - Text description of content to be backed up.

**-autoconfirm** - Proceed directly to commit of contents at PATH to URL,
                   without stopping to ask user for confirmation.

-----

[svnsync](https://github.com/tcllab/svnsync) is a command-line program to sync 
the contents of any local directory to any location within a Subversion 
repository.  Adds and deletes files within the repository as necessary.

The local checkout directory is left unchanged; this includes final deletion of
the .svn subdirectory created during the Subversion checkout process -- so when 
svnsync completes, the local directory is no longer a valid Subversion working 
copy.

The checkout status is output to the screen and svnsync pauses before 
committing, so the user knows what changes are to be made to the repository.
The user is given a chance to abort before committing changes.  The user also 
has a chance to enter a log message at the pause, unless the `-log_message` 
option is given on the command line.  If the `-autoconfirm` option is given, 
then there is no pause and the changes are committed as they are.  A 
human-readable timestamp is used as a default log message if the user has not 
specified one.

Updates and merges are beyond the scope of this command.  If necessary they
must be done independently by the user before executing svnsync.  If desired,
the user may kill the program (e.g., `ctrl-c`) at the pause before commit
confirmation, in which case the local directory will remain as a Subversion
working checkout and the user can make changes using Subversion's tools.  The
user may then commit using Subversion directly, or (after deleting the .svn 
subdirectory) run svnsync again.

As an alternative to the above, a very handy and compact Tcl/Tk-based GUI tool 
called [tkrev](https://sourceforge.net/projects/tkcvs/) is launched by svnsync 
if it is found in the user's executable path.  tkrev is useful for quickly 
examining the Subversion repository and working copy contents, checking file 
diffs, making edits, reverting file contents, etc.  svnsync will launch tkrev 
right before it pauses for commit confirmation, then close it after the commit 
is done.  N.B. tkrev is not included in the svnsync distribution, it must be 
installed separately by the user.

## Why svnsync?

The aim of svnsync is to make it easy to use 
[Subversion](https://subversion.apache.org), the venerable version control and 
source configuration management tool, as a personal backup/archive utility.

A software version control tool such as Subversion is typically designed to 
manage the contributions of teams of people to a single repository of work; 
such a program provides powerful tools for detecting collisions in people's 
contributions, and analyzing and eliminating those collisions; thus ensuring 
that no-one's work is lost.

But a personal backup program doesn't need to use those tools.  The svnsync 
script allows you to make the assumption that when you point the script to a 
directory of work that you want backed up, the directory is already in the 
condition that you want stored in the repository, no analysis or merging 
required.  svnsync makes note of all the content changes, as well as file 
additions and deletions, made since the last commit to the repository, and 
tells the repository to accept as definitive all changes in the directory to be 
backed up. It then makes a new commit to the repository that perfectly reflects 
the content of the directory targeted for backup.

Of course Subversion's analysis and merge tools remain available in case you 
ever find yourself in the situation of needing to compare and merge two 
versions of your own work.

## Suggested usage

I store and transport my Subversion repository on a password-protected USB 
flash drive.  Checking out working copies from a local repo goes quickly, even 
for large file collections.  Trying to use a remote repository over a network 
for backup-scale checkouts would likely be unacceptably slow.  Plus, 
hand-carrying a flash drive means I can back up public and work computers 
without firewall issues, and it eliminates concerns about network problems and 
server failures.

I use [rclone](https://rclone.org/) to back up my USB Subversion repository to 
a remote cloud file storage site.  Thus if my flash drive is lost or breaks, I 
can simply use rclone to copy the repository back to a new drive and carry on.  
Subversion makes this task straightforward, since all of a backup commit's 
changes are incorporated into a single file, so the rclone copy typically just 
involves one file and a handful of small metadata files.

When doing a backup, I generally don't use the `-log_message` option.  When 
svnsync pauses for confirmation and launches tkrev, I use tkrev to review file 
changes, then I write a log message at the command line prompt.  Then I 
instruct the script to proceed with the commit.

I run `svnadmin verify` on the local repository to ensure there are no 
corruptions in the repo files.  Then I use rclone to back up the local 
repository files to an internet file storage account.

## Why Subversion?

Subversion is billed as a source configuration management/version control tool, 
successor to CVS and precursor to git.  But in this category it's something of 
an odd duck.  The server-side main repository of a Subversion project can be 
thought of simply as a portable cloud-ready versioning virtual filesystem, with 
minimal features actually related to source configuration.  For example, the 
concepts of "branches" and "tags", ubiquitous in the SCM/VC field, are 
implemented on Subversion servers by convention (in namimg and placement of 
subdirectories), rather than enforced by internal logic.

Thus it's easy to do things with Subversion that are difficult or impossible 
with other SCM tools.  New files can be written directly to any location in the 
server repository, without a checkout or "file add" step.  Any version of any 
subset of files can be checked out or simply exported raw into a local 
directory; compared to e.g. git which normally requires download of the entire 
project to a local computer and checkout of all the files in a specified 
revision.

To compare further with git: git has historically had trouble with scaling to 
manage large projects.  Subversion is well-known to corporate users as a good 
choice for very large enterprise-level projects.  Subversion was also designed 
from the start to handle all files as binary, as opposed to git which was 
designed to handle text files and has struggled to incorporate support for 
large collections of binaries.

Each Subversion commit does file de-duplication (as git does), and in addition 
stores file changes as deltas, captures all of a commit's changes in one file, 
and compresses the commit file (tasks which git only does under specialized 
circumstances if at all).  Thus Subversion commits are optimized for storage 
and transmission to cloud endpoints.

All these features and properties taken together make it easy to envision 
Subversion as a powerful, cloud-optimized backup/archiving tool.  The one task 
that does not fit naturally into this vision is transmitting file changes into 
the repository, which requires a local checkout and possibly several other 
steps. This is the part that svnsync is designed to automate.

A perl script exists in Subversion's own repository that purports to do what 
svnsync does.  But it is thousands of lines long, old, unmaintained, and no 
longer works with current versions of Subversion.  But new features added to 
Subversion in the past half-dozen or so years have made it easy to accomplish 
the task in just a couple of hundred lines.

## Why another backup solution?

Backup tools abound.  But the ones I've examined tend to be designed to back up 
a computer's files and restore them (if necessary) to the same computer, or one 
very much like it; or are meant to manage groups of substantially similar 
computers.

More flexible tools tend to cache large amounts of information on the backed-up 
computer, which complexifies configuration and management of the tool, and if 
lost or corrupted significantly degrades performance.

Older tools tend to become unmaintained by the authors, new tools show 
distressing tendencies to let bugs corrupt their backup repositories.  If one 
desires a lifetime solution, a long track record and active support are 
important.

Subversion has been around for over twenty years and still has a significant 
active user base.  A number of large enterprises have a big stake in 
Subversion's continued reliability.

## What's my objective for a backup/personal archive tool?

Around ten years into my career as a computer professional, I began to yearn 
for a tool that didn't seem to exist.  A backup tool that would function as a 
long-term personal archive, which would transcend individual computers, 
operating systems, physical locations and storage/transmission technologies.  A 
tool and an archive that would remain valid for as close to a lifetime as 
possible.

In that first ten years I had already seen Windows and Macintosh trade places 
in popularity a couple of times, the development of Linux, the rise and fall of 
Sun, seen the progression from floppy disks to parallel-port external storage 
to USB, progressed from FTP and Gopher to the World Wide Web.  Since my student 
days I'd seen time-share workstations evolve to personal desktops to grid 
computing networks to remote hosted virtual servers.

What I wanted was a tool that would help me preserve, organize and transfer my 
work from job to job and from work to home and back.  Something that would help 
me save and also segregate professional and personal work.  Something that 
would work across the categories of software and hardware architecture that I 
had seen come and go, and stand a chance of remaining useful over the course of 
a career and maybe a lifetime.

That tool still doesn't exist off the shelf.  In the past I had tried to write 
my own, and made attempts with wrappers around existing programs like CVS and 
fossil.  Nothing I tried was sufficiently reliable or flexible.

Subversion combined with svnsync may or may not be the ultimate solution, but 
it's the closest I've come by far, and the only such tool I've actually used 
for an extended period of time.

## License and Copyright

Copyright (c) 2022-2023 Stephen Huntley (stephen.huntley@alum.mit.edu)

License: Tcl license
