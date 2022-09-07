This repository contains:

- [svnsync.tcl](svnsync.md): A script designed to make it easy to use
[Subversion](https://subversion.apache.org) as a personal backup/archive tool.  
Syncs the contents of any local directory to any location within a Subversion
repository.  Adds and deletes files within the repository as necessary.

Helper scripts:

- [linksync.tcl](linksync/linksync.md): Since Subversion doesn't follow 
symbolic links, this script aims to make it easy to add symbolic links into a 
Subversion checkout directory, then import and export the linked real files 
into and out of the checkout directory.  Thus making Subversion a potential 
installation/configuration tool as well as a repository. (No dependency on 
Subversion, can be used whenever it is desired to gather or deploy files 
into/out of a central location.)

- [globfind.tcl](globfind/globfind.md): A fast iterative file search utility 
that can execute a task for each file found.  Used by linksync to process 
symbolic links in a checkout and the real files they point to.