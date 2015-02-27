# InstallAsUser
This project is aimed at creating a set of documentation and tools to ease the installation of .deb packages in a gnu/linux environment as an unprivileged user.
The verb `installation` here refers to the action of creating a directory structure from packages available from the debian based distribution repositories.

Motivation
----------
Nowadays, it is quite common for ict universities to run gnu/linux powered systems, but students usually don't have the privileges to install new software. Installing and running "user-space" software is possible but difficult. It is possible, provided that build tools are already installed, to build software from source, when available, and to run it, but is a pain to handle dependencies manually and to patch absolutes resource paths not to point to system root.

This is why a tool to ease the whole process, from package dependencies resolution to installation, is required.
It is important to point out that:
- scripts and strategies presented here are not a clean way of installing software, they are rather a workaround
- system daemons / kernel releated stuff cannot be run anyway since privilege infrastructure will, of course, prevent it

Strategy
--------
There are a set of problems to account:
- automatic dependencies resolution 
- dynamic library loading
- absolute resources path

Dependencies resolution can be handled via apt using `--print-uris install` options. This will cause apt to simply list the required package dependencies urls, only for missing dependencies.
Installed dynamic library loading could be achieved via the `LD_LIBRARY_PATH` global variable, but another method is used.

What is really neaded to successfully relink absolute resources path is a way to change the filesystem root directory to a custom one. The `chroot` package does exactly this, but it requires root privileges.
Fortunately, the [proot](http://proot.me/) package provides similar user-space capabilities. It basically hooks custom system calls to provide a chroot-like jail.

proot is also able to bind a system path to be accessed inside the jail. This tool is wonderful, but the main limitation is its override policy. Suppose, for example, to want to install a package which provides the binary `foo` into /usr/bin. If you proot into your own directory structure, containing /usr/bin/foo, and bind system level /usr/bin to the proot usr/bin you will miss any system level user script since binding is performed into directory level basis.

This is where [unionfs](http://unionfs.filesystems.org/) comes to hand. It permits to "merge" together multiple filesystem structures to and build one. The branch order is specified from the command line through br1:br2:...:brn, its semantics is "when looking for a file, first look into branch br1, if not found look into branch br2" and so on. Fortunately someone made unionfs a [fuse module](https://github.com/rpodgorny/unionfs-fuse) so it is possible to run it in userspace.

The unionfs/proot combo enables the creation of a diff like file system structure in which your installed packages are layered on the top of the actual system root directory. Any changes you made will be written back to your "diff" filesystem folder.

Installation
------------
The process of setting up the environment and enter it is performed by [wonderland.sh](wonderland.sh) script. The very rough interface to the apt command to download and extract packages is instead implemented into [debget.sh](debget.sh). It is recommended to use an external drive has the workspace expecially on storage limited systems.

1. Clone this repository: `git clone https://github.com/emanuele-f/installasuser`
2. Make sure wonderland.sh is executable: `chmod +x wonderland.sh`
3. Execute wonderland.sh to download unionfs/proot if not already installed and then enter the proot
4. The new command `debget` should be available to you to install new packages. Run it with no options for help.
5. When you've finished with the proot, just exit to cleanup the environment.

The `sysroot` folder will be created and used to maintain your modifications. `pkgcache` will also be created to hold your downloaded packages. It is binded, into the proot jail, to '/debget/_pool' and used by debget command.

Software recipes
----------------
Here is a list of successfully installed software on Ubuntu Trusty:

- *dolphin-emu*: based upon [glennric ppa](https://launchpad.net/~glennric/+archive/ubuntu/dolphin-emu), here is an archive containing the required packages: [dolphin-emu.tar](dolphin-emu.tar). Unpack it into your `sysroot/debget` folder, then install it from inside proot jain using `debget -d dolphin-emu`. In order to run the gtk version of dolphin-emu, you will also need libwxgtk3.0 (`debget -i libwxgtk3.0`). To make it work properly, be sure to bind your home directory inside the proot (use `wonderland.sh -b /home /home`).
