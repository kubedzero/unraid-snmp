# SNMP Plugin for Unraid

This plugin installs the SNMP suite of tools on Unraid, a NAS operating system based on Slackware. More information about the SNMP library can be found at http://www.net-snmp.org/

The main objectives of this repository are:

* to store compiled `.txz` files and `.plg` files that Unraid users need to install the SNMP Unraid plugin
* to track the source code that makes this plugin work



## Installation sequence

* An Unraid user gets the link to the raw `snmp.plg` file hosted on Github, such as https://raw.githubusercontent.com/kubedzero/unraid-snmp/master/snmp.plg
* They paste the URL into the text input of the "Install Plugin" tab of the Plugins Unraid UI and push "Install"
* Unraid makes a local copy of the `snmp.plg` file in `/boot/config/plugins/snmp.plg` which exists persistently on the Unraid USB drive
* Unraid automatically downloads the `.txz` packages declared in the `snmp.plg` file. In this case, it is Perl, libnl, net-snmp, and our custom-built file, unraid-snmp. They are downloaded into `/boot/config/plugins/snmp/` so they needn't be re-downloaded on reboots
  * A side effect of the USB caching and a limitation of the Unraid Plugin system is that the MD5 of the cached file is not checked, merely the presence of the file. The files on the USB can be modified as long as the filenames don't change. When the plugin is reinstalled (at reboot, for example) the download will be skipped because the file appears to exist. Then, the modified file will be used during installation.
* Unraid runs `upgradepkg --install-new packagename.txz` to run the package's installation commands. It uninstalls any package of the same name before doing this installation, rather than failing.
  * This happens in a particular, defined order. `perl` and `libnl` are needed for the installation of `net-snmp` which is needed for the installation of `unraid-snmp`
  * Each package's install usually consists of copying files out of the `.txz` to various places in the OS. Then, a `doinst.sh` shell script can run to create symbolic links or perform other modifications and setup
  * The `doinst.sh` script for `unraid-snmp` is rather involved. Most of the Unraid-specific customization is located within.
* Unraid then runs the shell script embedded towards the end of the `snmp.plg` file, which validates that SNMP is functioning and fails the plugin installation otherwise. 

## Making PLG Updates

Since most of the logic exists in the compiled `unraid-snmp.txz` file, the `snmp.plg` file needs very few updates:

* The changelog should be updated with the modifications made
* The plugin version should be incremented so the Unraid plugin update checker knows a newer version is available
  * The plugin version is also referenced in the filename of the `unraid-snmp.txz` package, so its name may need updating to keep in sync 
* The `.txz` filenames and their corresponding MD5 checksums should be updated
  * `md5sum packagename.txz` on Unraid, or `md5 packagename.txz` on macOS will print out the MD5 of the file
  * Updates to these files should also be checked into Git and stored under the `./packages/` directory



## Making TXZ Updates

Changing any of the numerous files under the `./source/` directory will require a rebuild of the `unraid-snmp.txz` file. The `./source/` directory is only for tracking code changes and does not affect the code deployed to Unraid.

The `createpackage.sh` script can assist with creating the package, but is provided mostly for convenience. The following instructions will take use of it, but the commands within can be run manually just as easily. 

The key to creating these Slackware packages is to use `makepkg` which is provided on Slackware. For this reason, I build the packages on my Unraid server.



* Get the source code from macOS onto Unraid with `scp -r ~/GitHub/kubedzero/unraid-snmp/source root@unraid.local:/tmp/packageSource`
  * recursively copy all source files to the Unraid server with IP `unraid.local` 
  * replace `unraid.local` with `192.168.1.10` or whatever your server's IP is
  * `scp` will automatically create the `packageSource` directory and drop the sub-contents into it. So if there was a file on macOS `~/GitHub/kubedzero/unraid-snmp/source/install/doinst.sh` it would be copied to `/tmp/packageSource/install/doinst.sh`. 
* Copy the `createpackage.sh` script as well: `scp ~/GitHub/kubedzero/unraid-snmp/createpackage.sh root@unraid.local:/tmp/`
* Run a remote SSH command on macOS to build the package: `ssh -t root@unraid.local "cd /tmp/ && bash /tmp/createpackage.sh 2020.09.19 /tmp/packageSource/"`
  * The `-t` command executes everything in the double quotes on the Unraid server
  * The command first establishes a location by moving into the `/tmp/` directory
  * It then calls `bash /tmp/createpackage.sh` because Unraid changed to not allow direct execution, aka just executing `/tmp/createpackage.sh`
  * `createpackage.sh` is given the argument `2020.09.19` for the package naming. It does not affect the way the package is created aside from the filename. 
  * It is also given the directory where the files and folders belonging in the package live, which we copied over earlier: `/tmp/packageSource/`
  * It creates the completed package `unraid-snmp-2020.09.19-x86_64-1.txz` in the directory we called the command from, `/tmp/`
* Diving into what `createpackage.sh` is actually doing
  * It confirms `makepkg` is installed, preventing accidental usage on macOS
  * It takes the input plugin version and constructs the package filename in typical Slackware format: `packagename-version-x86_64-1.txz` or `unraid-snmp-2020.09.19-x86_64-1.txz`
  * It cleans out `.DS_Store` files from the source directory (provided as the second argument), to make sure macOS artifacts don't get included during package creation
  * The `makepkg` command bundles everything in the directory from where it was called into the package, so in preparation, the script moves to the source directory (provided as the second argument)
  * The `makepkg` command is invoked and the package is created (outside the source directory, as required by the tool)
  * The MD5 of the created package is computed and printed for convenience
* Now we need to copy the compiled package back to macOS, where our Git repository lives. `scp "root@unraid.local:/tmp/*.txz" ~/GitHub/kubedzero/unraid-snmp/packages`
  * This copies any `.txz` file in `/tmp/` so it doesn't have to be updated for version bumps, but `*.txz` can just as easily be replaced with the full name `unraid-snmp-2020.09.19-x86_64-1.txz` if desired
* Now we need to update the MD5 listed in the `snmp.plg` file for the `unraid-snmp.txz` package we copied over. I do this manually, using the printout from the `createpackage.sh` script. A sample MD5 is `09655c2ee9391e64ff7584b2893b5454`
* Now update the plugin version in the `snmp.plg` file if it hasn't already been done, commit the code and package changes, and push to GitHub
* Done!



## Resources

* The Preclear plugin, maintained by gfjardim, has a `pkg_build.sh` script to assist with creating compiled `.txz` files
  * https://github.com/gfjardim/unRAID-plugins/blob/master/source/preclear.disk/pkg_build.sh
* The Nerd Pack plugin's README has some instructions on creating a Slackware compatible package for install, based on the work done by gfjardim for the Preclear plugin
  * https://github.com/dmacias72/unRAID-NerdPack/blob/master/README.md
  * A modified version of `pkg_build.sh` https://github.com/dmacias72/unRAID-NerdPack/blob/master/source/mkpkg
* Structuring of the source directories, specifically the install script, were found at https://slackwiki.com/Doinst.sh

