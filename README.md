# plex-token-cli

A tiny shell script that generates a [Plex](https://plex.tv) authentication
token using Plex's device-link flow — no username/password, nothing sent to
any third party. It's a CLI port of the browser-based
[plex-token-generator](https://github.com/ndm13/plex-token-generator).

## Requirements

- `bash`
- `curl`
- `jq`

## Usage

```sh
./plex-token.sh
```

You'll be asked for a product name (press Enter for the default). The script
then prints a PIN:

```
Go to https://plex.tv/link and enter: ABCD
```

Open that URL in any browser, sign in to Plex if needed, and enter the PIN.
The script polls every 5 seconds and prints your token once you've authorized:

```
Success! Your Plex token:
xxxxxxxxxxxxxxxxxxxx
```

The PIN expires after a few minutes (the script tells you exactly how long);
just re-run if it lapses.

## Scripting

Status messages go to stderr and the bare token goes to stdout, so you can
capture just the token:

```sh
./plex-token.sh > token.txt
```

## How it works

1. `POST https://plex.tv/api/v2/pins` — requests a PIN tied to a freshly
   generated client identifier (so Plex treats each run as a new device).
2. You authorize the PIN at `https://plex.tv/link`.
3. `GET https://plex.tv/api/v2/pins/{id}` — polled until it returns your
   `authToken`.

## Credits & license

A CLI port of [ndm13/plex-token-generator](https://github.com/ndm13/plex-token-generator),
which implements the same Plex device-link flow as a browser app. Licensed
under the [MIT License](LICENSE).
