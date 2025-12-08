#!/bin/sh
set -x
@echo on
####################################################################
# Privateness Core infrastructure testing v0.11.1                  #
#                                                                  # 
# Skywire, Privateness and Emercoin daemons + DNS-reverse-proxy    #
####################################################################

# Execute as root ---> sudo su

# sleep 3
# Initial Skywire configuration and start.

skywire-autoconfig 
# sleep 5
echo "Do take note of the public key that is displayed"


systemctl start skywire

read -p "Press Enter to continue" </dev/tty

 echo "
###########################################################
# Validation that Privateness chain is Synched with       #
# the explorer based on block height and best block hash  #
###########################################################
#"
#sleep 3
#"Privateness explorer result blockchain/head/seq and block_hash"
curl https://ness-explorer.magnetosphere.net/api/health | grep seq
privateness-cli status | grep seq
#sleep 2
curl https://ness-explorer.magnetosphere.net/api/health | grep block_hash
privateness-cli status | grep block_hash
#sleep 2
# echo "Privateness-cli result, the two "seq" and the hashes must be same"
read -p "Press Enter to continue" </dev/tty


 echo "
###########################################################
# Validation that Emercoin chain is Synched with          #
# the explorer based on block height and best block hash  #
###########################################################
# "
#sleep 5
echo "Emercoin explorer result"
curl https://explorer.emercoin.com/api/stats/block_height
# sleep 5
echo "Emercoin-cli result must be same number as explorer's"
emc getblockchaininfo | grep blocks
#sleep 5
curl https://explorer.emercoin.com/api/block/latest | grep blockhash
emc getbestblockhash
echo "Emercoin-cli result must be same number as explorer's"

read -p "Press Enter to continue" </dev/tty
#sleep 5
echo "
###########################################################
# Validation that EmerNVS is accessible locally           #
# + EmerDNS resolution as well as clearnet DNS           #
###########################################################
"
# sleep 5
emc name_show dns:private.ness | python ./emercoin-value.py
# sleep 10

ping private.ness -c 2
# sleep 3

emc name_show dns:vpn.sky | python ./emercoin-value.py
# sleep 3

ping vpn.sky -c 2
# sleep 3

ping emercoin.com -c 2
# sleep 3


#sleep 2
read -p "Press Enter to continue" </dev/tty


echo "

############################################################################################
# Starting Skywire VPN with server called by EmerDNS name                                  #
# Open http://EmerDNS-Name:8000 on another computer to validate in visor console                     #
# Output expected is simply "Starting"                                                           #
############################################################################################
"
# sleep 5
skywire-cli vpn start $(dig +short ness.sky TXT |  sed 's/"//g')

# There shouldn't be any errors. Check your internet connection and that you have ROOT privileges if anything is wrong.
# Thank you Legend for testing this. You are appreciated.
