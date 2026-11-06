# AyuGram for iOS

An independent Telegram client for iOS built on [Swiftgram](https://github.com/Swiftgram/Telegram-iOS), which is itself based on [Telegram for iOS](https://github.com/TelegramMessenger/Telegram-iOS).

## Features

- **Ghost mode** — hide read receipts, online status, typing, recording and story views, separately or all at once.
- **Message history** — keep deleted and edited messages from chosen chats on your device, with photos, videos, voice and round messages; save voice messages as M4A.
- **Content** — save and forward from restricted chats, allow screenshots.
- **Message filters** — regex rules that hide matching messages from chats.
- **Appearance** — alternate app icons, app badge styles, customizable deleted and edited marks, snow effect.
- **Plugins** — install JavaScript plugins from files, with commands, message hooks and per-plugin settings.

Everything AyuGram stores stays on the device. The only request it makes on its own is downloading `update.json` from this repository to check for updates.

## Branches

| Branch | Build | Contents |
| --- | --- | --- |
| `standard` | Standard | Swiftgram with the AyuGram features |
| `custom` | Custom | `standard` plus the appearance options |
| `upstream` | — | Unmodified Swiftgram this project is based on |

The first commit on `standard` is the unmodified Swiftgram source. Every change AyuGram makes is in the commits after it, so you can compare `upstream...standard` (and `standard...custom`) on GitHub to see exactly what is different.

## Building

The app is built by GitHub Actions as unsigned IPAs. Sign them with your own certificate (AltStore, SideStore, Sideloadly, ESign, Feather, …) or run them in LiveContainer.

1. Fork or clone this repository.
2. In **Settings → Secrets and variables → Actions**, add:
   - `TELEGRAM_API_ID` and `TELEGRAM_API_HASH` — your own, from [my.telegram.org](https://my.telegram.org)
   - `APPLE_TEAM_ID` — your 10-character Apple team ID
   - `APP_BUNDLE_ID` — the bundle identifier to build with
3. Open **Actions → AyuGram iOS → Run workflow** and choose the variant.
4. Download the IPA from the run's artifacts.

`ci/` contains the build driver and the checks that run before the full build.

## Updating to a new Swiftgram or Telegram version

Fetch the new upstream revision into the `upstream` branch, then merge `upstream` into `standard` and `standard` into `custom`, resolving any conflicts.

## Publishing an update

1. Build a new version. The build number is in `build-manifest.json` next to the IPA.
2. Post the IPA in the channel.
3. Edit `update.json` on `standard`: set `build` to the new build number, `version` to the version you want to show, and `url` to the post link.

Everyone on an older build sees the update notice on the next launch. Only put a build number in `update.json` once that build is actually published.

## License

GPL-2.0, the same as Telegram for iOS and Swiftgram. See [LICENSE](LICENSE).

## Disclaimer

This project is not affiliated with Telegram or Swiftgram. It uses its own `api_id`, and the Telegram name and logo belong to their owners.
