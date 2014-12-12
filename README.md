Port of the initial tool from NCC group to OS X.
https://github.com/nccgroup/vlan-hopping

Tested with OS X 10.9.5

Removed functionality
========================
- Auto adding VLANs. This has to be done manually now because OS X does not support vconfig
- Check for VMware NIC. This was because the tool called `ethtool` which was not compatible.
- Fixed tshark deprecated -R option for single-pass analysis. Uses -Y instead.

License
========================
See license from NCC for details
