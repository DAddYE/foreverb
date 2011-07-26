# Version 0.2.4 (unreleased)

* Ruby 1.9.2 compatibility
* Stop process using pid instead of file
* Added specs
* Fixed `foreverb list` where in some scenarios don't return a list of processes

# Version 0.2.3

* Added global monitoring, to easily watch each `foreverb` daemon
* Look daemons through config file and unix command `ps`
* Added `start` CLI command
* Added `restart` CLI command
* Added `tail` CLI command
* Added `update` CLI command (useful to update daemons config)
* Improved documentation (aka the readme)