# Description

This tool provides various utilities for Home Assistant via MQTT autodiscovery.

See [sample config](sample_config).

## Features

### Presence detection

This feature is for aggregating network presence (you have to set up a fix IP address for the device you want to track) and BLE presence (via [ESPresense](https://github.com/ESPresense/ESPresense)).

## Experimental features

These features might have breaking changes without a major version bump.

### Cover control

You can set up covers with different opening/closing durations controlled by a remote device in Home Assistant (for example via the [Broadlink integration](https://www.home-assistant.io/integrations/broadlink)).
