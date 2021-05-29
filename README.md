
# dhcpd2nsd.pl 

dhcpd2nsd will process extract leases from dhcpd.leases, and DHCP reservations from dhcpd.conf and process them into the designated NSD zonefile

the script uses a slightly modified TTL (59 seconds less than the zone by default) to mark hosts that it has populated and to determine which enteries it can remove

there are various config options which will control the behavior of the script, however in general the script will only make changes to the zone file when dhcpd has added or removed a client

below is the *suggested* cronjob for running the script, but as stated on a network with a low rate of change you can run it as frequently as you want, just be aware that it DOES
send a SIGHUP to nsd when it does find a change to make

```
*/5     *       *       *       *       /path/to/dhcpd2nsd.pl
```



* full disclosure: i wrote this script in 3 hours to shuffle my dhcp leases and reservations into my local dns domain powered by NSD. YMMV


