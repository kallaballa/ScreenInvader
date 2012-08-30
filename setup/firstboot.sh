#!/bin/bash
#
# ScreenInvader - A shared media experience. Instant and seamless.
#  Copyright (C) 2012 Amir Hassan <amir@viel-zu.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

[ -z "$LC_ALL" ] && export LC_ALL=C
cd `dirname $0`
chvt 2
janosh="/lounge/bin/janosh"
ask="dialog --stdout --ok-label Next --cancel-label Back"

function askHowNet() {
  $ask --radiolist "Network Configuration" 11 42 4 \
	dhcp "Automatic configuration" on \
	manual "Manual configuration" off
}

function askNetConnection() {
  $ask --radiolist "Network Connection" 9 32 2 \
    Wifi "Wireless" on \
    Ethernet "Wired" off
}

function askWifiSSID() {
  $ask --nocancel --inputbox "Wireless Network (SSID)" 7 30
}

function askWifiEncryption() {
  $ask  --radiolist "Wireless Encryption" 10 38 3 \
    WPA-PSK "WPA Passphrase" on \
    WEP "WEP Passphrase" off \
    NONE "No encryptiion"  off
}

function askWifiPassphrase() {
  $ask --insecure --passwordbox "Wireless Passphrase" 7 30
}


function askHostname() {
  $ask --nocancel --inputbox "Please specify a hostname:" 7 30
}

function askManualNetwork() {
  $ask  --form "Manual Network Configuration" 12 38 0 \
	"Address:"	1 1 "" 1 12 20 0 \
	"Netmask:"	2 1 "" 2 12 20 0 \
	"Gateway:"	3 1 "" 3 12 20 0 \
	"DNS:"		4 1 "" 4 12 20 0
}

function askDoReboot() {
  $ask --yesno 'Finish configuration and reboot?' 6 43
}

function makeHostname() {
  $janosh -t makeHostname -s /network/hostname "$1"
}

function makeDNS() {
  $janosh -t makeDns -s /network/nameserver "$1"
}

function makeDHCPNet() {
  $janosh -t makeNetworkDhcp
}

function makeManualNet() {
  $janosh -t makeNetworkMan /network/address "$1" /network/netmask "$2" /network/gateway "$3"
}

function makeWifi() {
  $janosh -t makeWifi /network/wifi/ssid "$1" /network/wifi/encryption/value "$2" /network/wifi/passphrase "$3"
  }

function doConf() {
	${1}Conf
}

function hostnameConf(){
  hostname=
  while [ -z "$hostname" ]; do  
    hostname=$(askHostname)
  done

  makeHostname "$hostname"
  doConf "connection"
}

function connectionConf() {
  howconf=$(askNetConnection)
  if [ $? == 0 ]; then
    if [ "$howconf" == "Wifi" ]; then
      doConf "wireless"
    elif  [ "$howconf" == "Ethernet" ]; then
      doConf "network"
    fi
  else
    doConf "hostname"
  fi
}

function wirelessConf() {
  ssid=$(askWifiSSID)
  if [ $? == 0 ]; then
    encrypt=$(askWifiEncryption)
    if [ "$encrypt" == "WPA-PSK" -o "$encrypt" == "WEP" ]; then
      passphrase=$(askWifiPassphrase)
    fi
    makeWifi "$ssid" "$encrypt" "$passphrase"
    doConf "network"
  else
    doConf "connection"
  fi
}

function networkConf() {
  howconf=$(askHowNet)
  if [ $? == 0 ]; then
    if [ "$howconf" == "dhcp" ]; then
      makeDHCPNet
    elif  [ "$howconf" == "manual" ]; then
      netconf=$(askManualNetwork)
      if [ $? == 0 ]; then
        set $netconf
        makeManualNet "$1" "$2" "$3"
        makeDNS "$4"
      else
        doConf "network"
      fi
    fi
  else
    doConf "connection"
  fi
}

function rebootConf(){
  if askDoReboot; then
   finish
  else
   doConf "hostname"
  fi
}

function finish() {
  update-rc.d autofs defaults
  update-rc.d thttpd defaults
  update-rc.d mpd defaults
  update-rc.d xserver defaults

  mkdir -p /share
  mkdir -p /var/cache/debconf/
  mkdir -p /var/run/mpd/
  mkdir -p /var/lib/mpd
  chown -R mpd:audio  /var/lib/mpd
  chown -R mpd:audio /var/run/mpd/
  chmod a+rwx /var/run/mpd/
  chown -R lounge:lounge /lounge/

  usermod -s /bin/bash root
  makeInittab

  shutdown -r now
}

doConf "hostname"

