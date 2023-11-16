This command creates an Elf/OS filesystem on a disk. It accepts two options, "-a" which specifies a size in allocation units (4K each), and "-m" which specifies a size in megabytes. In the absence of either option, the filesystem will be the size of the underlying disk up to a maximum of 256 MB.

Note that the format command creates a filesystem but does not install a bootloader. To make a disk bootable, the sys command should be used after formatting.
