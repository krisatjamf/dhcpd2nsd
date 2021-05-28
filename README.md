
* full disclosure: i wrote this script in 3 hours to shuffle my dhcp leases and reservations into my local dns domain powered by NSD. YMMV


you will need to modify the script to point to the zone file you want populated, the script will add the hosts to that domain.

the script uses a slightly modified TTL (59 seconds less than the zone default) to mark hosts that it has populated

note: the script will also delete any enteries with a matching TTL who's lease or reservation is no longer valid.


and Finally:  i'd recommend running it from a cronjob, you can do it as often as you like, i use the following as a nice middle ground.

the script won't make any changes unless there is a change to make so run it as often as you want, just remember it does SIGHUP nsd each time it makes a change

 */5     *       *       *       *       /path/to/dhcpd2nsd.pl
