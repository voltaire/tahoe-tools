#!/bin/sh

# Author: joepie91 (http://joepie91.cryto.net/)
# Thanks to MK_FG for helping to fix the exit issue.

echo "[!] NOTE: This tool will make the following changes to the target machine:"
echo "[*]   Create tahoe user"
echo "[*]   Update your apt repository lists"
echo "[*]   Install nano, build-essential, python, python-dev"
echo "[*]   Download, unpack, and build Tahoe-LAFS"
echo "[*]   Start Tahoe-LAFS"
echo "[!] If you do not wish to continue, press ctrl+C now. Otherwise, press enter to continue."

echo "[?] Enter the hostname of the server you want to set up:"
read HOST
ssh -t -T "root@$HOST" 2>/dev/null <<'ENDSSH'
echo "[!] Your final chance to abort before installation starts..."
echo "[!] Hit ctrl+C to abort, or wait 4 seconds for the installation to start."
sleep 4s
echo "[!] Installing dependencies..."
apt-get update >/dev/null 2>/dev/null
apt-get install -y nano build-essential python python-dev >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then echo "[X] Installing dependencies failed."; exit 1; fi
echo "[+] Installed dependencies."

useradd -m tahoe >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then echo "[X] Adding tahoe user failed."; exit 1; fi
echo "[+] Added tahoe user."

exec su tahoe
if [ $? -ne 0 ]; then echo "[X] Switching to tahoe user failed."; exit 1; fi

cd ~
if [ $? -ne 0 ]; then echo "[X] Navigation to home directory failed."; exit 1; fi

wget https://tahoe-lafs.org/source/tahoe-lafs/releases/allmydata-tahoe-1.9.1.tar.gz >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then echo "[X] Downloading Tahoe-LAFS failed."; exit 1; fi
echo "[+] Downloaded Tahoe-LAFS."

tar -xzvf allmydata-tahoe-1.9.1.tar.gz >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then echo "[X] Unpacking Tahoe-LAFS failed."; exit 1; fi
echo "[+] Unpacked Tahoe-LAFS."

cd allmydata-tahoe-1.9.1
if [ $? -ne 0 ]; then echo "[X] Navigating to Tahoe-LAFS source directory failed."; exit 1; fi

echo "[!] I am now going to build Tahoe-LAFS, this is going to take a while. It's recommended to use this time to retrieve a beverage of your choice :)"
echo "[!] Building..."
python setup.py build >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then echo "[X] Building Tahoe-LAFS failed."; exit 1; fi
echo "[+] Successfully built Tahoe-LAFS."

cd bin
if [ $? -ne 0 ]; then echo "[X] Navigation to Tahoe-LAFS binary directory failed."; exit 1; fi

./tahoe create-node >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then echo "[X] Creation of Tahoe-LAFS storage node failed."; exit 1; fi
echo "[+] Storage node created."

stat --format=%Y ~/.tahoe/tahoe.cfg > ~/tahoe_setup_time
ENDSSH

if [ $? -ne 0 ]; then
	echo "[X] An error occurred during setup, the script will now exit."
	exit 1
fi

echo "[!] You will now have to edit the Tahoe-LAFS storage node configuration file. After saving and exiting the editor, your Tahoe-LAFS storage node will attempt to start."
echo "[!] Press enter to continue."
read
echo "[ ] There goes..."
ssh -t "root@$HOST" 2>/dev/null nano /home/tahoe/.tahoe/tahoe.cfg
ssh -t -T "root@$HOST" 2>/dev/null <<'ENDSSH'
exec su tahoe

OLDTIME="$(cat ~/tahoe_setup_time)"
rm ~/tahoe_setup_time

if [ "$(stat --format=%Y ~/.tahoe/tahoe.cfg)" == $OLDTIME ]; then echo "[X] You did not save the config file, cancellation assumed and installation aborted."; exit 1; fi

echo "[+] Configuration done."

cd ~/allmydata-tahoe-1.9.1/bin
./tahoe start >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then echo "[X] Starting the Tahoe-LAFS node failed, something went wrong."; exit 1; fi
ENDSSH

if [ $? -ne 0 ]; then
	echo "[X] An error occurred during setup, the script will now exit."
	exit 1
fi

echo "[+] Node started, you're done!"
