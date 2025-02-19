# Description

Config files other than `config.general.json` are optional.

JSON5 format, so comments can be left in the config files.

Optional parameters that have a value in the sample will default to that value if you omit them.

`*_interval` and `*_timeout` parameters support both numeric values (seconds) and text values ("hours:minutes:seconds" or "minutes:seconds").

## Cover control

Devices need to have these 3 commands learned: `open` `stop` `closed`

If you are currently using different names for the commands, you can find the config file in a similar location: `config/.storage/broadlink_remote_a043b032da90_codes`
