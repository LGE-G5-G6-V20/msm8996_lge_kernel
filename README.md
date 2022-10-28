# LGE MSM8996 4.4 source - Swan2000 custom branch.

This branch constitutes the Swan2000 version of LGE MSM8996's 4.4 kernel source, focused on better performance and efficiency over stable through a set of optimizations and voltage tweaks that aren't allowed at stable kernels aimed for official LOS support and such.

The custom name comes from a merge between the philosophies behind [SwanKernel](https://github.com/AShiningRay/SwanKernel-LGV20_G5_G6) and [mk2000](https://github.com/stendro/msm8996_lge_kernel), since the developers from those kernels worked in tandem to bring and optimize linux 4.4 to LGE's MSM8996 trio, comprised of LG G5, V20, and G6.

For more in-depth info on this kernel, please refer to the documentation available on the [wiki](https://github.com/LGE-G5-G6-V20/msm8996_lge_kernel/wiki).

## Building the kernel

### !! This guide assumes you're using a Linux distro to build the kernel !! 

First clone this repo, get into the folder you cloned it into, open up git terminal and type `git checkout LGE-4.4-new-Swan2000` to switch to this branch.

Then download these toolchains:

[Eva GCC Arm](https://github.com/mvaisakh/gcc-arm/archive/gcc-master.zip)

[Eva GCC AArch64](https://github.com/mvaisakh/gcc-arm64/archive/gcc-master.zip)

Unzip the subfolders from that first link (everything that's inside the `*-gcc-master` folder) into `~/toolchains/arm-eabi/`
And the subfolders from the second link into `~/toolchains/aarch64-elf/`

Then just go back to the cloned kernel source, open a terminal (or use the same one previously used for git) and type `./build.sh DEVICE`, DEVICE will be the variant you'll be building for, so US996, H850, etc.

If you're only interested in the kernel Image in order to use it as a prebuilt kernel for a ROM source, those steps should already give you the Image.lz4-dtb you need to place into the prebuilt folder. It'll be located in a newly created folder inside the cloned repo, `/build/arch/arm64/boot/` to be more precise.

If you want a flashable zip, then you need to run `./copy_finished.sh` after the kernel build completes successfully. That command will pack everything up and place the flashable zip into a newly created `out/` folder.
