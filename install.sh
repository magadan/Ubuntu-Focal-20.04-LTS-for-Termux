#!/data/data/com.termux/files/usr/bin/bash
carpeta=$PREFIX/share/Ubuntu
mkdir -p $carpeta
cd $carpeta
folder=ubuntu-fs
if [ -d "$folder" ]; then
	first=1
	echo -e "\e[1;31m [*] Skipping Downloading"
fi
tarball="ubuntu-rootfs.tar.gz"
if [ "$first" != 1 ];then
	if [ ! -f $tarball ]; then
		printf '\n\e[1;34m%-6s\e[m' '[*] Download Rootfs, this may take a while base on your internet speed'
		case `dpkg --print-architecture` in
		aarch64)
			archurl="arm64" ;;
		arm)
			archurl="armhf" ;;
		amd64)
			archurl="amd64" ;;
		x86_64)
			archurl="amd64" ;;	
		*)
			echo -e "\e[1;31m [*] Unknown Architecture"; exit 1 ;;
		esac
		wget -c --quiet --show-progress "https://partner-images.canonical.com/oci/focal/current/ubuntu-focal-oci-${archurl}-root.tar.gz" -O $tarball
	fi
	cur=`pwd`
	mkdir -p "$folder"
	cd "$folder"
	printf '\n\e[1;34m%-6s\e[m' '[*] Decompressing Rootfs, please be patient...'
	proot --link2symlink tar -xf ${cur}/${tarball} --warning=no-unknown-keyword --delay-directory-restore --preserve-permissions --exclude='dev'||:
        printf '\n\e[1;34m%-6s\e[m' '[*] Downloading of missing components...'
        rm -rf $carpeta/$folder/etc/resolv.conf
        rm -rf $carpeta/$folder/etc/hosts
        wget -P $carpeta/$folder/etc -c --quiet --show-progress https://raw.githubusercontent.com/dylanmeca/ubuntu-termux/main/config/resolv.conf
        wget -P $carpeta/$folder/etc -c --quiet --show-progress https://raw.githubusercontent.com/dylanmeca/ubuntu-termux/main/config/hosts
        wget -P $carpeta/$folder/proc -c --quiet --show-progress https://raw.githubusercontent.com/dylanmeca/ubuntu-termux/main/config/.loadavg
        wget -P $carpeta/$folder/proc -c --quiet --show-progress https://raw.githubusercontent.com/dylanmeca/ubuntu-termux/main/config/.stat
        wget -P $carpeta/$folder/proc -c --quiet --show-progress https://raw.githubusercontent.com/dylanmeca/ubuntu-termux/main/config/.uptime
        wget -P $carpeta/$folder/proc -c --quiet --show-progress https://raw.githubusercontent.com/dylanmeca/ubuntu-termux/main/config/.version
        wget -P $carpeta/$folder/proc -c --quiet --show-progress https://raw.githubusercontent.com/dylanmeca/ubuntu-termux/main/config/.vmstat
        function android () {
             local profile_script
             if [ -d "$carpeta/$folder/etc/profile.d" ]; then
                    profile_script="$carpeta/$folder/etc/profile.d/termux-proot.sh"
	     else
                    chmod u+rw "$carpeta/$folder/etc/profile" >/dev/null 2>&1 || true
                    profile_script="$carpeta/$folder/etc/profile"
             fi
             local LIBGCC_S_PATH
             LIBGCC_S_PATH="/$(cd ${carpeta}/${folder}; find usr/lib/ -name libgcc_s.so.1)"
	     wget -c --quiet --show-progress https://raw.githubusercontent.com/dylanmeca/ubuntu-termux/main/config/profile.sh
             chmod +x profile.sh
             ./profile.sh
             mv termux-proot.sh $profile_script
             rm -rf profile.sh
             if [ "${LIBGCC_S_PATH}" != "/" ]; then
		    echo "${LIBGCC_S_PATH}" >> "${carpeta}/${folder}/etc/ld.so.preload"
                    chmod 644 "${carpeta}/${folder}/etc/ld.so.preload"
             fi
             unset LIBGCC_S_PATH
        }
        android
        chmod u+rw "$carpeta/$folder/etc/passwd" \
		"$carpeta/$folder/etc/shadow" \
		"$carpeta/$folder/etc/group" \
		"$carpeta/$folder/etc/gshadow" >/dev/null 2>&1 || true
        echo "aid_$(id -un):x:$(id -u):$(id -g):Android user:/:/sbin/nologin" >> \
                "$carpeta/$folder/etc/passwd"
        echo "aid_$(id -un):*:18446:0:99999:7:::" >> \
		"$carpeta/$folder/etc/shadow"
        function groups () {
              local group_name group_id
              while read -r group_name group_id; do
                     echo "aid_${group_name}:x:${group_id}:root,aid_$(id -un)" >> \
                              "$carpeta/$folder/etc/group"
                     if [ -f "$carpeta/$folder/etc/gshadow" ]; then
                             echo "aid_${group_name}:*::root,aid_$(id -un)" >> \
				      "$carpeta/$folder/etc/gshadow"
		     fi
              done < <(paste <(id -Gn | tr ' ' '\n') <(id -G | tr ' ' '\n'))		
        }
        groups 
	cd "$cur"
fi
mkdir -p ubuntu-binds
bin=ubuntu
printf '\n\e[1;34m%-6s\e[m' '[*] Configuring Ubuntu...'
cat > $bin <<- EOM
#!/bin/bash
cd \$(dirname \$0)
## unset LD_PRELOAD in case termux-exec is installed
unset LD_PRELOAD
command="proot"
command+=" --link2symlink"
# Support System V IPC
#command+=" --sysvipc"
command+=" --kernel-release=5.4.0-faked"
command+=" -0"
command+=" -r $PREFIX/share/Ubuntu/$folder"
if [ -n "\$(ls -A $PREFIX/share/Ubuntu/ubuntu-binds)" ]; then
    for f in $PREFIX/share/Ubuntu/ubuntu-binds/* ;do
      . \$f
    done
fi
command+=" -b /dev"
command+=" -b /dev/urandom:/dev/random"
command+=" -b /proc"
command+=" -b /proc/self/fd:/dev/fd"
command+=" -b /proc/self/fd/0:/dev/stdin"
command+=" -b /proc/self/fd/1:/dev/stdout"
command+=" -b /proc/self/fd/2:/dev/stderr"
command+=" -b $PREFIX/share/Ubuntu/ubuntu-fs/proc/.loadavg:/proc/loadavg"
command+=" -b $PREFIX/share/Ubuntu/ubuntu-fs/proc/.stat:/proc/stat"
command+=" -b $PREFIX/share/Ubuntu/ubuntu-fs/proc/.uptime:/proc/uptime"
command+=" -b $PREFIX/share/Ubuntu/ubuntu-fs/proc/.version:/proc/version"
command+=" -b $PREFIX/share/Ubuntu/ubuntu-fs/proc/.vmstat:/proc/vmstat"
command+=" -b /sys"
command+=" -b /data/dalvik-cache"
command+=" -b /data/data/com.termux/cache"
command+=" -b /data/data/com.termux"
command+=" -b /storage"
command+=" -b /storage/self/primary:/sdcard"
command+=" -b /system"
command+=" -b /vendor"
command+=" -b /mnt"
command+=" -b $PREFIX/tmp:/tmp"
#command+=" -b /apex"
#command+=" -b /linkerconfig/ld.config.txt"
#command+=" -b /plat_property_contexts"
#command+=" -b /property_contexts"
command+=" -b $PREFIX/share/Ubuntu/ubuntu-fs/tmp:/dev/shm"
command+=" -b /:/host-rootfs"
command+=" -b $PREFIX/share/Ubuntu/ubuntu-fs/root:/dev/shm"
## uncomment the following line to have access to the home directory of termux
#command+=" -b /data/data/com.termux/files/home:/root"
command+=" -b /sdcard"
command+=" -w /root"
command+=" /usr/bin/env -i"
command+=" HOME=/root"
command+=" PREFIX=/data/data/com.termux/files/usr"
command+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games:/data/data/com.termux/files/usr/bin:/system/bin:/system/xbin"
command+=" TERM=\$TERM"
command+=" LANG=C.UTF-8"
command+=" /bin/bash --login"
com="\$@"
if [ -z "\$1" ];then
    exec \$command
else
    \$command -c "\$com"
fi
EOM

termux-fix-shebang $bin
chmod +x $bin
mv $bin $PREFIX/bin
rm -rf $tarball
cd $HOME
printf '\n\e[1;34m%-6s\e[m' '[*] The installation is finished'
printf '\n\e[1;34m%-6s\e[m' '[*] Start Ubuntu 20.04 with the command: ubuntu'
rm -rf install.sh
