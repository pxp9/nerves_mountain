# MountainNerves

Define your board

``` bash
export MIX_TARGET=rpi5
```

Compiling the firmware

``` bash
mix firmware
```

Flashing for first time

``` bash
NERVES_BOT_TOKEN="token" NERVES_TG_OWNER="user_id" NERVES_WIFI_SSID="ssid1,ssid2,ssid3" NERVES_WIFI_PASSPHRASE="pass1,pass2,pass3" mix burn
```

Flashing over SSH is running

``` bash
mix upload <IP>
```

## Learn more

- Official docs: <https://hexdocs.pm/nerves/getting-started.html>
- Official website: <https://nerves-project.org/>
- Forum: <https://elixirforum.com/c/nerves-forum>
- Elixir Slack \#nerves channel: <https://elixir-slack.community/>
- Elixir Discord \#nerves channel: <https://discord.gg/elixir>
- Source: <https://github.com/nerves-project/nerves>
