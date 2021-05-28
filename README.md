
* full disclosure: i wrote this script in 3 hours to shuffle my dhcp leases and reservations into my local dns domain powered by NSD. YMMV


you will need to modify the script to point to the zone file you want populated, the script will add the hosts to that domain.

the script uses a slightly modified TTL (59 seconds less than the zone default) to mark hosts that it has populated
