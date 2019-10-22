#!/bin/bash -v

# set -e -x

#-------------------------------------------------------------------------------
# Parameter Settings
#-------------------------------------------------------------------------------

# Show Linux Distribution/Distro information
if [ $(command -v lsb_release) ]; then
	lsb_release -a
fi

# Show Linux System Information
uname -a

# Show Linux distribution release Information
if [ -f /etc/os-release ]; then
	cat /etc/os-release
fi

#-------------------------------------------------------------------------------
# Cleanup process for old kernel Package
#-------------------------------------------------------------------------------

# Removing old kernel packages (Use dnf commands)
if [ $(command -v dnf) ]; then
	# Removing old kernel packages
	echo "Target operating system"
	uname -r
	dnf --showduplicate list kernel
	dnf remove -y $(dnf repoquery --installonly --latest-limit=-1 -q)
	sleep 5
	dnf --showduplicate list kernel
	# Reconfigure GRUB 2 config file
	if [ $(command -v grub2-mkconfig) ]; then
		grub2-mkconfig -o $(find /boot | grep -w grub.cfg)
	fi
	# Cleanup repository information
	dnf clean all
fi

# Removing old kernel packages (Use yum/package-cleanup commands)
if [ $(command -v yum) ]; then
	if [ $(command -v package-cleanup) ]; then
		if [ $(command -v dnf) ]; then
			echo "Excluded operating systems"
		else
			# Removing old kernel packages
			echo "Target operating system"
			uname -r
			yum --showduplicate list kernel
			package-cleanup --oldkernels --count="1" -y
			sleep 5
			yum --showduplicate list kernel
			# Reconfigure GRUB 2 config file
			if [ $(command -v grub2-mkconfig) ]; then
				grub2-mkconfig -o $(find /boot | grep -w grub.cfg)
			fi
			# Cleanup repository information
			yum clean all
		fi
	fi
fi

# Removing old kernel packages (Use zypper/purge-kernels commands)
if [ $(command -v zypper) ]; then
	if [ $(command -v purge-kernels) ]; then
		# Removing old kernel packages
		echo "Target operating system"
		uname -r
		rpm -qa | grep kernel | sort
		cat /etc/zypp/zypp.conf | grep multiversion.kernels
		purge-kernels
		sleep 5
		rpm -qa | grep kernel | sort
		# Reconfigure GRUB 2 config file
		if [ $(command -v grub2-mkconfig) ]; then
			grub2-mkconfig -o $(find /boot | grep -w grub.cfg)
		fi
		# Cleanup repository information
		zypper clean --all
	fi
fi

# Removing old kernel packages (Use apt-get/purge-old-kernels commands)
if [ $(command -v apt-get) ]; then
	if [ $(command -v purge-old-kernels) ]; then
		# Removing old kernel packages
		echo "Target operating system"
		uname -r
		dpkg --get-selections | grep linux-image

		purge-old-kernels
		# purge-old-kernels --keep 1 -qy

		sleep 5
		dpkg --get-selections | grep linux-image
		# Reconfigure GRUB 2 config file
		if [ $(command -v update-grub) ]; then
			update-grub
		fi
		# Cleanup repository information
		apt-get clean
	fi
fi

#-------------------------------------------------------------------------------
# Cleanup process for Configuration Files, and Log Files
#-------------------------------------------------------------------------------

# Remove the udev persistent rules file
rm -rf /etc/udev/rules.d/70-persistent-*

# Remove cloud-init status
rm -rf /var/lib/cloud/*

# Remove /tmp files
rm -rf /tmp/*

# Remove /var/log files
find /var/log/ -type f -name \* -exec cp -f /dev/null {} \;

# Remove /var/log/user-data_*.log files
rm -rf /var/log/user-data_*.log

# Remove SSH Host Key Pairs
HostKeyFlag=$(find /etc/ssh/ -name "*_key" | wc -l)
PublicKeyFlag=$(find /etc/ssh/ -name "*_key.pub" | wc -l)

if [ $HostKeyFlag -gt 0 ]; then
	# Remove SSH Host Key Pairs
	shred -u --force /etc/ssh/*_key
fi

if [ $PublicKeyFlag -gt 0 ]; then
	# Remove SSH Public Key Pairs
	shred -u --force /etc/ssh/*_key.pub
fi

# Remove SSH Authorized Keys (Root User) for All Linux Distribution
if [ -f /root/.ssh/authorized_keys ]; then
	shred -u --force /root/.ssh/authorized_keys
fi

# Remove SSH Authorized Keys (ec2-user User) for Amazon Linux, Red Hat Enterprise Linux (RHEL), SUSE Linux Enterprise Server (SLES)
if [ -f /home/ec2-user/.ssh/authorized_keys ]; then
	shred -u --force /home/ec2-user/.ssh/authorized_keys
fi

# Remove SSH Authorized Keys (centos User) for CentOS
if [ -f /home/centos/.ssh/authorized_keys ]; then
	shred -u --force /home/centos/.ssh/authorized_keys
fi

# Remove SSH Authorized Keys (fedora User) for fedora
if [ -f /home/fedora/.ssh/authorized_keys ]; then
	shred -u --force /home/fedora/.ssh/authorized_keys
fi

# Remove SSH Authorized Keys (ubuntu User) for Ubuntu
if [ -f /home/ubuntu/.ssh/authorized_keys ]; then
	shred -u --force /home/ubuntu/.ssh/authorized_keys
fi

# Remove SSH Authorized Keys (admin User) for Debian
if [ -f /home/admin/.ssh/authorized_keys ]; then
	shred -u --force /home/admin/.ssh/authorized_keys
fi

# Remove Bash History
unset HISTFILE

# Remove Bash History (for Default User)
[ -f /root/.bash_history ] && rm -rf /root/.bash_history
[ -f /home/ec2-user/.bash_history ] && rm -rf /home/ec2-user/.bash_history
[ -f /home/centos/.bash_history ] && rm -rf /home/centos/.bash_history
[ -f /home/fedora/.bash_history ] && rm -rf /home/fedora/.bash_history
[ -f /home/ubuntu/.bash_history ] && rm -rf /home/ubuntu/.bash_history
[ -f /home/admin/.bash_history ] && rm -rf /home/admin/.bash_history

# Remove Bash History (for AWS Service and Tool User)
[ -f /home/ssm-user/.bash_history ] && rm -rf /home/ssm-user/.bash_history

# Waiting time
sleep 30

#-------------------------------------------------------------------------------
# Stop instance
#-------------------------------------------------------------------------------

# Shutdown
# shutdown -h now

#-------------------------------------------------------------------------------
# For normal termination of SSM "Run Command"
#-------------------------------------------------------------------------------

exit 0

#-------------------------------------------------------------------------------
# End of File
#-------------------------------------------------------------------------------
