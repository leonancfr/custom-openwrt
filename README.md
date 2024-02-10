# CharlinhOS

**Ladies and gentlemen, welcome to the unveiling of the most groundbreaking and spud-tacular project in the history of World – ChalinhOS, the extraordinary potato OS!**

*- Do you like studying more or potatoes?*
*- I like studying... but I like potatoes more.*

Let's potato our way into the future together! 👨🥔📚💻🚀

# Reasoning
There are two ways of building OpenWRT
1. Build System
 - customizable
 - very slow (many hours)
 - builds sysupgrade, initram and Image Builder
2. Image Builder
 - non customizable
 - very fast (few seconds)

Default Image Builder do not support custom device tree.
Device tree files ares compiled and embedded on OpenWRT kernel during Build System step, so to get custom `.dtb` in the kernel it is needed to recompile the kernel.
There are some community suggestions, but as it is not officialy supported, it is also a risky option and as such will be discarded.
https://forum.openwrt.org/t/how-openwrt-compiles-dts-files/67532
https://forum.openwrt.org/t/dts-support-in-imagebuilder/12320
https://www.mail-archive.com/openwrt-devel@lists.openwrt.org/msg57760.html

So it is needed to build a customized Image Builder to have support to this proprietary hardware and also achieve fast build times, thus this hybrid approach.

# Image Builder Build

## Build
This operation will build an image with Image Builder and all dependencies based on `diffconfig` file.
This image will be pushed to GitLab's image registry and will be used on GitLab's CI/CD to build a final CharlinhOS sysupgrade binary.

1. Update `CONFIG_VERSION_NUMBER` in `diffconfig` file on project's root folder to the new version number.

2. Run `build_and_push_image_builder.sh` to push a docker image with Image Builder for CharlinhOS with CharlesGO embedded.
This is a time and resource consuming operation, thus cannot be run on GitLab CI/CD.
```
GITLAB_TOKEN_NAME=<docker git clone token name> GITLAB_TOKEN=<docker git clone token> CHARLES_GO_ENV_FILE=<env file for prod or dev to build CharlesGo for> ./build_and_push_image_builder.sh 
```

# CharlinhOS Development
## Adding packages
1. Clone OpenWRT repo
```
git clone https://git.openwrt.org/openwrt/openwrt.git --branch v22.03.6 --depth 1 .
```

ln -srf mt7628an_hilink_hlk-7628n.dts openwrt/target/linux/ramips/dts/mt7628an_hilink_hlk-7628n.dts
ln -srf files openwrt/files

2. Update the feed

```shell
./scripts/feeds update -a
./scripts/feeds install -a
```

3. Install the desired package
```shell
./scripts/feeds install <package_name>
```

4. Expand `diffconfig` file
Copy `diffconfig` as `.config` inside `OpenWRT`'s repo and make it a full blown config 
```
cp diffconfig openwrt/.config
cd openwrt
make defconfig
```
> WARNING
> After running `./script/feeds`, `.config` file will suffer unpredictable changes that may affect your dev effort.
> Copy `diffconfig` file to the repo and expand it again 

5. Select the Package in Menuconfig
Navigate to the appropriate menu option where the package is located and enable it. Save the configuration and exit the menuconfig.

```shell
make menuconfig
```

***Obs: In most cases, the package is already available within the OpenWrt repository, so you just need to search for it in `make menuconfig`.***

6. Update config file
If the test went well, update the git-tracked diffconfig file
[General info](https://openwrt.org/docs/guide-developer/toolchain/use-buildsystem#configure_using_config_diff_file)

Inside OpenWRT folder
```
./scripts/diffconfig.sh > ../diffconfig 
```
  
7. Build your newly refreshed OpenWRT
```
time make -j $(($(nproc)+1)) V=s
```

8. Flashing
See manual flashing section on this README.

9. Verify Package Inclusion
After flashing the OpenWrt image to your device, you can verify if the new package is included by accessing the command line or the LuCI web interface.
```shell
opkg list-installed | grep <package_name>
```

# Manual Operations
For dev purposes, there are options to do those things manually

## Manual Flashing for NERVOSINHO

1. Go to `http://172.17.2.1:4404/` and log with the root user.
2. Enter in System -> Backup / Flash Firmware.
3. Seek `Flash new firmware image` section and click on `Flash image...`.
4. Browse `bin/targets/ramips/mt76x8/XXXXX-squashfs-sysupgrade.bin` file and click `Upload`.
5. Wait a bit :p
6. On the `Flash image?` dialog, uncheck `Keep settings and retain the current configuration` (all options should be unchecked) and click `Continue`.
7. The device will automatically reboot. Wait about 5 minutes and then try to access your updated firmware ;)


## Manual Deploy
1. Install dependencies
```
Install `sshpass` and `mqttx` before runining the deploy script.
```bash
sudo apt install -y --no-install-recommends sshpass
```

Linux install
```bash
curl -LO https://www.emqx.com/en/downloads/MQTTX/v1.9.6/mqttx-cli-linux-x64
sudo install ./mqttx-cli-linux-x64 /usr/local/bin/mqttx
```
Mac install
```bash
https://www.emqx.com/en/downloads/MQTTX/v1.9.6/mqttx-cli-macos-arm64
sudo install ./mqttx-cli-macos-arm64 /usr/local/bin/mqttx
```

2. Deploy
Finally, run the `deploy.sh <.env_file>` script to publish a new release for the desired environment.
***Note: This process will update all devices in the park provisioned with the new release environment. Additional information about this process can be found in the Updater Service documentation on Notion.***

## License

This project is licensed under a proprietary license.
