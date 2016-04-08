#!/bin/bash
#
# Created by Tommy,2015-2-25
#

# Init System
function initSystem() {
        # Setup environment
        VIRT_COMMAND=/usr/bin/virsh
        INST_COMMAND=/usr/bin/virt-install
        IMAG_COMMAND=/usr/bin/qemu-img
        IMAG_PATH=/vm/images
        ISO_PATH=/vm/manager/iso
        TEMPLATE_PATH=/vm/manager/templates

	LOG=/dev/null

        # export environment
        export PATH=/bin:/sbin:/usr/bin:/usr/sbin
}

# Checking System
# exit codes:
# 0 probable success
# 1 not running as root
# 2 no KVM supported
# 3 no /usr/sbin/virsh
# 4 no /usr/sbin/virt-install
# 5 no /usr/sbin/qemu-img
function checkSystem() {
	# Are we running as root?
	if [ "$(id -u)" -ne "0" ] ; then
		echo
		echo "* This command must be run as root"
		echo
		exit 1
	fi

	# Is KVM supported?
	if ! egrep -q '^flags.*(vmx|svm)' /proc/cpuinfo; then
		echo
		echo "* You do not appear to be running a machine that supports KVM"
		echo "* Please ensure you have a 64-bit CPU with VT extensions enabled in the BIOS"
		echo
		exit 2
	fi

	# Do we have $VIRT_COMMAND?
	if [ ! -x "$VIRT_COMMAND" ] ; then
		echo
		echo "* You are missing a needed package"
		echo "* Please install libvirt-client and try again"
		echo "* HINT: yum -y install libvirt-client"
		echo
		exit 3
	fi

	# Do we have $INST_COMMAND?
	if [ ! -x "$INST_COMMAND" ] ; then
		echo
		echo "* You are missing a needed package"
		echo "* Please install virt-install and try again"
		echo "* HINT: yum -y install virt-install"
		echo
		exit 4
	fi

	# Do we have $IMAG_COMMAND?
	if [ ! -x "$IMAG_COMMAND" ] ; then
		echo
		echo "* You are missing a needed package"
		echo "* Please install virt-install and try again"
		echo "* HINT: yum -y install qemu-img"
		echo
		exit 5
	fi
}

function setPlan() {
	if [ "$1" == "" ] ; then
			USE_PLAN=default
	else
			USE_PLAN=$1
	fi
	source ./plans/$USE_PLAN
}
# general
function setGeneral() {
	if [ "$NAME" == "" ] ; then
		echo -n "* Please enter the virtual machine name: "
		read NAME
	fi
	GENERAL="--name="$NAME

	# Is $NAME already installed?
	if [ -e /etc/libvirt/qemu/$NAME.xml ] ; then
		echo
		echo "* $NAME seems to already be installed"
			# Is it running as well?
			$VIRT_COMMAND list | grep -q $NAME
			RUNNING=$?
			if [ "$RUNNING" -eq "0" ] ; then
				echo
				echo "* $NAME also appears to be running"
				echo
				echo "* To access your guest, select"
				echo "  Applications -> System Tools -> Virtual Machine Manager"
				echo "  from the menu bar at the top of the screen and then double-click"
				echo "  on then entry for $NAME."
				echo
				echo "* To kill it, issue the command: $VIRT_COMMAND destroy $NAME"
				echo
				echo "* To remove it and start over, issue the commands:"
				echo "   $VIRT_COMMAND destroy $NAME ; $VIRT_COMMAND undefine $NAME"
				echo
				
				echo "* Make sure to kill it if you want to start over"
				echo
				echo "* $NAME install was ABORTED"
				echo
				exit 6
			fi	
		echo "* To start it, issue the command: $VIRT_COMMAND start $NAME"
		echo "* To remove it and start over, run the following:"
		echo "   $VIRT_COMMAND destroy $NAME ; $VIRT_COMMAND undefine $NAME"
		echo "* $NAME install was ABORTED"
		echo
		exit 7
	fi
	
	if [ "$RAM" == "" ] ; then
		echo -n "* How many memory needs (MB): "
		read RAM
	fi
	GENERAL=$GENERAL" --ram="$RAM
	
	if [ "$ARCH" == "" ] ; then
		echo -n "* Please select cpu architecture (i386,x86_64): "
		read ARCH
	fi
	GENERAL=$GENERAL" --arch="$ARCH
	
	if [ "$VCPU" == "" ] ; then
		echo "* NOTE! CPU topology can additionally be specified with sockets, cores, and threads.  If values are omitted, the rest will be autofilled preferring sockets over cores over threads."
		echo "* FORMAT=VCPUS[,maxvcpus=MAX][,sockets=#][,cores=#][,threads=#]"
		echo -n "* How many vcpu needs: "
		read VCPU
	fi
	GENERAL=$GENERAL" --vcpu="$VCPU
	
	if [ "$CPU_MODEL" ==  "" ] ; then
		echo -n "* Select a cpu model: "
		read CPU_MODEL
	fi
	GENERAL=$GENERAL" --cpu="$CPU_MODEL
}

# installation
function setInstallation() {
	if [ "$OS_VARIANT" == "" ] ; then
		echo "* OS-variant list:"
		osinfo-query os
		echo -n "* Please enter the OS-variant: "
		read OS_VARIANT
	fi
	if [ "$INST_TYPE" == "" ] ; then
		echo -n "* Enter Installation Method options (cdrom,location,import): "
		read INST_TYPE
	fi
	case $INST_TYPE in
		"cdrom" )
			if [ "$CDROM" == "" ] ; then
				echo "* ISO list:"
				ls $ISO_PATH
				echo -n "* Select a ISO: "
				read CDROM
				CDROM=$ISO_PATH/$CDROM
			fi
			INSTALLATION="--"$INST_TYPE" "$CDROM
		;;
		"location" )
			if [ "$LOCATION" == "" ] ; then
				echo -n "* Select a URL: "
				read LOCATION
			fi
			INSTALLATION="--"$INST_TYPE" "$LOCATION
		;;
		"import" )
			INSTALLATION="--"$INST_TYPE
		;;
	esac
	INSTALLATION="--os-variant="$OS_VARIANT" "$INSTALLATION
}

# storage
function setDisk() {
	if [ "$DISK_SIZE" == "" ] ; then
		echo "* Add disk"$DISKID"..."
		echo -n "* Set disk size (GB): "
		read DISK_SIZE
	fi	

	if [ "$DISK_FORMAT" == "" ] ; then
		echo -n "* Set disk format (raw,qcow2): "
		read DISK_FORMAT
	fi

	if [ -e $IMAG_PATH/$NAME"_disk"$DISKID"."$DISK_FORMAT ] ; then
		echo
		echo "* "$IMAG_PATH/$NAME"_disk"$DISKID"."$DISK_FORMAT" is already exists."
		echo "* $NAME install was ABORTED"
		echo
		exit 5
	fi

	$IMAG_COMMAND create -f $DISK_FORMAT $IMAG_PATH/$NAME"_disk"$DISKID"."$DISK_FORMAT $DISK_SIZE"G"
	if [ "$?" != "0" ] ; then
		echo
		echo "* Can't create disk "$IMAG_PATH/$NAME"_disk"$DISKID"."$DISK_FORMAT
		echo "* $NAME install was ABORTED"
		echo
		exit 8
	fi
	DISKS=$DISKS" --disk "$IMAG_PATH/$NAME"_disk"$DISKID"."$DISK_FORMAT",bus=virtio,format="$DISK_FORMAT
}

function depDisk() {
	if [ "$TEMPLATE" == "" ] ; then
		echo "* Templates list:"
		ls $TEMPLATE_PATH
			echo -n "* Select the template type: "
			read TEMPLATE

		echo -n "* Set disk format (raw,qcow2): "
			read DISK_FORMAT
	fi
	qemu-img convert -f qcow2 -O $DISK_FORMAT $TEMPLATE_PATH/$TEMPLATE $IMAG_PATH/$NAME"_disk"$DISKID"."$DISK_FORMAT
	DISKS=$DISKS" --disk "$IMAG_PATH/$NAME"_disk"$DISKID"."$DISK_FORMAT",bus=virtio,format="$DISK_FORMAT
}

function setStorage() {
	DISKID=1
	if [ "$INST_TYPE" == "import" ] ; then
		depDisk
	else
		setDisk
	fi
	if [ "$USE_PLAN" == "default" ] ; then
		let DISKID=$DISKID+1
	fi
	while true ; do
		if [ "$DISKID" != "1" ] ; then
			echo -n "* Add another disk? (yes/no): "
			read VAR
			case "$VAR" in
				"yes" | "YES" | "y" | "Y" )
				DISK_SIZE=""
				DISK_FORMAT=""
				setDisk
				let DISKID=$DISKID+1;;
				"no" | "NO" | "n" | "no" )
				break;;
			esac
		else
			break
		fi
	done
	STORAGE=$DISKS
}

# network
function setNetwork() {
	if [ "$NETWORK_TYPE" == "" ] ; then
                echo -n "* Network type (network,bridge): "
                read NETWORK_TYPE
        fi
        if [ "$NETWORK_INTERFACE" == "" ] ; then
                echo -n "* Select network: "
                read NETWORK_INTERFACE
        fi
	if [ "$NETWORK_MAC"  == "" ] ; then
		echo -n "* Enter MAC address (example:52:54:0A:07:01:01): "
		read NETWORK_MAC
	fi
	if [ "$NETWORK_MAC" == "ip" ] ; then
		echo -n "* Enter IP address (example:192.168.1.1): "
		read NETWORK_IP
		NETWORK_MAC="52:54"
		for((i=1;i<=4;i++))
		do
			array[$i]=`echo $NETWORK_IP | cut -d "." -f$i`
                	NETWORK_MAC=$NETWORK_MAC":"`echo "obase=16; ${array[$i]}" | bc;`
		done
	fi
	case "$NETWORK_TYPE" in
                "network" | "NETWORK" | "n" | "N" )
                NETWORK_TYPE="network"
                ;;
                "bridge" | "BRIDGE" | "b" | "B" )
                NETWORK_TYPE="bridge"
                ;;
        esac
	NETWORK="--network "$NETWORK_TYPE"="$NETWORK_INTERFACE",model=virtio,mac="$NETWORK_MAC
}

# graphics
function setSPICE() {
	if [ "$LISTEN" == "" ] ; then
		echo -n "* SPICE listen IP: "
		read LISTEN
	fi
	if [ "$PORT" == "" ] ; then
		echo -n "* SPICE listen port: "
		read PORT
	fi
	if [ "$TLSPORT" == "" ] ; then
		echo -n "* SPICE listen tlsport: "
		read TLSPORT
	fi
	if [ "$PASSWORD" == "" ] ; then
		echo -n "* SPICE connection password: "
		read PASSWORD
	fi
	GRAPHICS="--graphics spice,listen="$LISTEN",port="$PORT",tlsport="$TLSPORT",password="$PASSWORD" --channel spicevmc"
}

function setVNC() {
        if [ "$LISTEN" == "" ] ; then
                echo -n "* VNC listen IP: "
                read LISTEN
        fi
        if [ "$PORT" == "" ] ; then
                echo -n "* VNC listen port: "
                read PORT
        fi
        if [ "$PASSWORD" == "" ] ; then
                echo -n "* VNC connection password: "
                read PASSWORD
        fi
        GRAPHICS="--graphics vnc,listen="$LISTEN",port="$PORT",password="$PASSWORD
}

function setGraphics() {
	if [ "$GRAPHICS_TYPE" == "" ] ; then
		echo -n "* Graphics type (spice,vnc): "
		read GRAPHICS_TYPE
	fi
	case "$GRAPHICS_TYPE" in
		"vnc" | "VNC" | "v" | "V" )
		setVNC
		;;
		"spice" | "SPICE" | "s" | "S" )
		setSPICE
		;;
	esac
}

# virtualization
function setVirtualization() {
	VIRTUALIZATION="--hvm --accelerate"
}

# device
function setDevice() {
	case "$GRAPHICS_TYPE" in
		"vnc" | "VNC" | "v" | "V" )
		DEVICE="--video cirrus "
		;;
		"spice" | "SPICE" | "s" | "S" )
		DEVICE="--video qxl "
		;;
	esac
	DEVICE="--channel unix,mode=bind,target_type=virtio,name=org.qemu.guest_agent.0 --memballoon virtio"
}

function waitConfirm() {
	echo
	echo "---------------------------------"
	echo "- VM info"
	echo "---------------------------------"
	# general.sh
	echo "* Name: $NAME"
	echo "* RAM: $RAM"
	echo "* ARCH: $ARCH"
	echo "* VCPU: $VCPU"
	echo "* CPU Model: $CPU_MODEL"

	# installation.sh
	echo "* OS Variant: $OS_VARIANT"
	echo "* Install Type: $INST_TYPE"
	if [ "$CDROM" != "" ] ; then
		echo "* Install Media: $CDROM"
	fi
	if [ "$LOCATION" != "" ] ; then
		echo "* Install Media: $LOCATION"
	fi

	# storage.sh
	if [ "$TEMPLATE" != "" ] ; then
		echo "* Use Template: $TEMPLATE"
	fi
	if [ "$DISK_SIZE" != "" ] ; then
		echo "* Disk Size $DISK_SIZE"
	fi
	if [ "$DISK_FORMAT" != "" ] ; then
		echo "* Disk Format: $DISK_FORMAT"
	fi
	# network.sh
	echo "* Network Type: $NETWORK_TYPE"
	echo "* Network Interface: $NETWORK_INTERFACE"
	echo "* Network MAC Address: $NETWORK_MAC"

	# graphics.sh
	if [ "$GRAPHICS_TYPE" != "" ] ; then
		echo "* Graphics Type: $GRAPHICS_TYPE"
	fi
	echo "* Graphics Linsten: $LISTEN"
	echo "* Graphics Port: $PORT"
	if [ "$TLSPORT" != "" ] ; then
		echo "* Graphics TSL-Port: $TLSPORT"
	fi
	if [ "$PASSWORD" != "" ] ; then
		echo "* Graphics Password: $PASSWORD"
	fi
	echo "---------------------------------"
	echo -n "confirm? (yes/no):"
	read CONFIRM
	case "$CONFIRM" in
                "YES" | "yes" | "Y" | "y" )
                ;;
                "NO" | "no" | "N" | "n" )
                exit 0
                ;;
        esac
}

echo

initSystem
checkSystem
setPlan $1
setGeneral
setInstallation
setStorage
setNetwork
setGraphics
setVirtualization
setDevice
waitConfirm

echo
echo "* Preparing to install $NAME virtual machine"

# Ok, lets give it a shot...
# If this completes successfully
$INST_COMMAND \
        $GENERAL \
        $INSTALLATION \
        $STORAGE \
        $NETWORK \
        $GRAPHICS \
        $VIRTUALIZATION \
        $DEVICE \
        --noautoconsole
sleep 5
$VIRT_COMMAND setmem $NAME $[$RAM/4*3]M --config

echo
echo "* The $NAME virtual machine is installing"
echo
echo "* To access and monitor $NAME, select"
echo "  Applications -> System Tools -> Virtual Machine Manager"

exit 0
