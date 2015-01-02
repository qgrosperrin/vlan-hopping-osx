Port of the initial tool from NCC group to OS X.
https://github.com/nccgroup/vlan-hopping

Tested with OS X 10.9.5

Changes
========================
- Auto adding VLANs. Uses `networksetup` because OS X does not support `vconfig`
- Removed check for VMware NIC. This was because the tool called `ethtool` which was not compatible with OS X.
- Fixed tshark deprecated -R option for single-pass analysis. Uses -Y instead.
- Fixed listing of network interfaces via `ifconfig`

/!\
- The `yersinia` screen session for the DTP attack does not work for some reason on my setup... Use `sudo yersinia dtp -attack 1 -interface en0` in a different terminal window while the script is waiting for the DTP attack to kick off.
/!\

License
========================
See license from NCC for details
