#!/bin/bash -v

set -e -x

# Logger
exec > >(tee /var/log/user-data_ssm-agent_installation.log || logger -t user-data -s 2> /dev/console) 2>&1

#-------------------------------------------------------------------------------
# Define Function
#-------------------------------------------------------------------------------

function get_contents() {
		if [ -x "$(which curl)" ]; then
				curl -s -f "$1"
		elif [ -x "$(which wget)" ]; then
				wget "$1" -O -
		else
				die "No download utility (curl, wget)"
		fi
}

function lowercase(){
		echo "$1" | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/"
}

function uppercase(){
		echo "$1" | sed "y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/"
}

function get_os_info () {
		OS=`lowercase \`uname\``
		KERNEL=`uname -r`
		MACH=`uname -m`
		KERNEL_GROUP=$(echo $KERNEL | cut -f1-2 -d'.')

		if [ "${OS}" = "linux" ] ; then
			if [ -f /etc/os-release ]; then
					source /etc/os-release
					DIST_TYPE=$ID
					DIST=$NAME
					REV=$VERSION_ID
			elif [ -f /etc/centos-release ]; then
					DIST_TYPE='CentOS'
					DIST=`cat /etc/centos-release | sed s/\ release.*//`
					REV=`cat /etc/centos-release | sed s/.*release\ // | sed s/\ .*//`
			elif [ -f /etc/redhat-release ]; then
					DIST_TYPE='RHEL'
					DIST=`cat /etc/redhat-release | sed s/\ release.*//`
					REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
			elif [ -f /etc/system-release ]; then
					if grep "Amazon Linux" /etc/system-release; then
						DIST_TYPE='Amazon'
					fi
					DIST=`cat /etc/system-release | sed s/\ release.*//`
					REV=`cat /etc/system-release | sed s/.*release\ // | sed s/\ .*//`
			else
					DIST_TYPE=""
					DIST=""
					REV=""
			fi
		fi

		if [[ -z "${DIST}" || -z "${DIST_TYPE}" ]]; then
			 echo "Unsupported distribution: ${DIST} and distribution type: ${DIST_TYPE}"
			 exit 1
		fi

		LOWERCASE_DIST_TYPE=`lowercase $DIST_TYPE`
		UNIQ_OS_ID="${LOWERCASE_DIST_TYPE}-${KERNEL}-${MACH}"
		UNIQ_PLATFORM_ID="${LOWERCASE_DIST_TYPE}-${KERNEL_GROUP}."
}

function exec_ssm_agent_installer_script () {
		cd /tmp
		FILE_SIZE=0
		MAX_RETRY_COUNT=3
		RETRY_COUNT=0

		while [ $RETRY_COUNT -lt $MAX_RETRY_COUNT ] ; do
			echo AWS-UpdateLinuxAmi: Downloading script from $SCRIPT_URL
			get_contents "$SCRIPT_URL" > "$SCRIPT_NAME"
			FILE_SIZE=$(du -k /tmp/$SCRIPT_NAME | cut -f1)
			echo AWS-UpdateLinuxAmi: Finished downloading script, size: $FILE_SIZE
			if [ $FILE_SIZE -gt 0 ]; then
				break
			else
				if [[ $RETRY_COUNT -lt MAX_RETRY_COUNT ]]; then
					RETRY_COUNT=$((RETRY_COUNT+1));
					echo AWS-UpdateLinuxAmi: FileSize is 0, retryCount: $RETRY_COUNT
				fi
			fi
		done

		if [ $FILE_SIZE -gt 0 ]; then
			chmod +x "$SCRIPT_NAME"
			echo AWS-UpdateLinuxAmi: Running UpdateSSMAgent script now ....
			bash -ex ./"$SCRIPT_NAME" --region "$REGION"
		else
			echo AWS-UpdateLinuxAmi: Unable to download script, quitting ....
		fi
}

function install_ssm_agent () {

		# Amazon Linux Distribution
		if [ "${DIST}" = "Amazon Linux AMI" ] || [ "${DIST}" = "Amazon Linux" ] || [ "${DIST_TYPE}" = "amzn" ]; then
			exec_ssm_agent_installer_script
			echo "Complete SSM Agent Installer Script - Linux distribution: ${DIST} - ${REV}"

		# Red Hat Enterprise Linux Distribution
		elif [ "${DIST}" = "RHEL" ] || [ "${DIST}" = "Red Hat Enterprise Linux Server" ] || [ "${DIST_TYPE}" = "rhel" ]; then
			exec_ssm_agent_installer_script
			echo "Complete SSM Agent Installer Script - Linux distribution: ${DIST} - ${REV}"

		# CemtOS Linux Distribution
		elif [ "${DIST}" = "CentOS" ] || [ "${DIST_TYPE}" = "centos" ]; then
			exec_ssm_agent_installer_script
			echo "Complete SSM Agent Installer Script - Linux distribution: ${DIST} - ${REV}"

		# Ubuntu Linux Distribution
		elif [ "${DIST}" = "Ubuntu" ] || [ "${DIST_TYPE}" = "ubuntu" ]; then
			exec_ssm_agent_installer_script
			echo "Complete SSM Agent Installer Script - Linux distribution: ${DIST} - ${REV}"

		# Debian GNU/Linux Distribution
		elif [ "${DIST}" = "Debian GNU/Linux" ] || [ "${DIST_TYPE}" = "debian" ]; then
			exec_ssm_agent_installer_script
			echo "Complete SSM Agent Installer Script - Linux distribution: ${DIST} - ${REV}"

		# SUSE Linux Enterprise Server Distribution
		elif [ "${DIST}" = "SLES" ] || [ "${DIST_TYPE}" = "sles" ]; then
			zypper --quiet --non-interactive --no-gpg-checks install "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm"

			rpm -qi amazon-ssm-agent

			systemctl start amazon-ssm-agent

			systemctl enable amazon-ssm-agent
			systemctl is-enabled amazon-ssm-agent

			echo "Complete SSM Agent Install - Linux distribution: ${DIST} - ${REV}"

		# Unknown Linux Distribution
		else
			echo "Unsupported SSM Agent Installer Script - Linux distribution: ${DIST} and distribution revision: ${REV}"
		fi
}

#-------------------------------------------------------------------------------
# Main Routine
#-------------------------------------------------------------------------------

# call the os info function to get details
get_os_info

# Information Linux Distribution
KERNEL_VERSION=$(uname -r )
KERNEL_GROUP=$(echo "${KERNEL_VERSION}" | cut -f 1-2 -d'.')
KERNEL_VERSION_WO_ARCH=$(basename ${KERNEL_VERSION} .x86_64)

echo "Distribution of the machine is ${DIST}."
echo "Distribution type of the machine is ${DIST_TYPE}."
echo "Revision of the distro is ${REV}."
echo "Kernel version of the machine is ${KERNEL_VERSION}."

# Install curl Command
if [ $(command -v curl) ]; then
		echo "Preinstalled curl command - Linux distribution: ${DIST} and distribution revision: ${REV}"
else
		if [ $(command -v yum) ]; then
				# Package Install curl Tools (Amazon Linux, Red Hat Enterprise Linux, CentOS)
				yum clean all
				yum install -y curl
		elif [ $(command -v apt-get) ]; then
				# Package Install curl Tools (Debian, Ubuntu)
				export DEBIAN_FRONTEND=noninteractive
				apt clean -y
				apt install -y curl
		elif [ $(command -v zypper) ]; then
				# Package Install curl Tools (SUSE Linux Enterprise Server)
				zypper clean --all
				zypper --quiet --non-interactive install curl
		else
				echo "Unsupported curl install - Linux distribution: ${DIST} and distribution revision: ${REV}"
		fi
fi

# Variable definition
readonly IDENTITY_URL="http://169.254.169.254/2016-06-30/dynamic/instance-identity/document/"
readonly TRUE_REGION=$(get_contents "$IDENTITY_URL" | awk -F\" '/region/ { print $4 }')
readonly DEFAULT_REGION="us-east-1"
readonly REGION="${TRUE_REGION:-$DEFAULT_REGION}"

readonly SCRIPT_NAME="aws-install-ssm-agent"
readonly SCRIPT_URL="https://aws-ssm-downloads-$REGION.s3.amazonaws.com/scripts/$SCRIPT_NAME"

# call the SSM Agent Installer script function
install_ssm_agent

exit 0
