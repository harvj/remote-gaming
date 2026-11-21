# Remote Gaming P1.6 visual review

Staging candidate `v0.4.5-rc.2` was captured at `6ecfe39304ebf57d092432d97872f1d5bb30f8c5`. Before captures come from the original `v0.4.4` comparison at `04d6bf58045b40b47eaf19d272507a265ce20b25`. Desktop is 1440 CSS px and mobile is 390 CSS px. Select any image to open its full-resolution PNG.

The directory, Modern Art entry and Pandemic status candidate captures were taken on hosted staging while signed out. The authenticated Modern Art lobby, tabletop and account-control captures were taken locally in Chromium using the relevant source revision and disposable Auth and gameplay fixtures. The baseline hosted images are preserved as supplied. The two mobile baseline entry captures contain identical pixels.

The candidate review records a long identifier clipping in the tabletop title at 390 CSS px. The lobby session link wraps. The tabletop uses 52% outer and 32% nested fills, with 12 px, 8 px and 6 px shared corner radii. The tabletop scroll screenshots show the pinned navigation and content fade.

## Directory

Hosted entry captures.

| Viewport | Before | Candidate | Candidate hover |
| --- | --- | --- | --- |
| 1440 CSS px | [![Directory, 1440 CSS px, before](before-directory-desktop.png)](before-directory-desktop.png) | [![Directory, 1440 CSS px, candidate](directory-desktop.png)](directory-desktop.png) | [![Directory, 1440 CSS px, Log In hover](directory-desktop-login-hover.png)](directory-desktop-login-hover.png) |
| 390 CSS px | [![Directory, 390 CSS px, before](before-directory-mobile.png)](before-directory-mobile.png) | [![Directory, 390 CSS px, candidate](directory-mobile.png)](directory-mobile.png) | [![Directory, 390 CSS px, Log In hover](directory-mobile-login-hover.png)](directory-mobile-login-hover.png) |

## Modern Art entry

Hosted entry captures.

| Viewport | Before | Candidate | Candidate hover |
| --- | --- | --- | --- |
| 1440 CSS px | [![Modern Art entry, 1440 CSS px, before](before-modern-art-entry-desktop.png)](before-modern-art-entry-desktop.png) | [![Modern Art entry, 1440 CSS px, candidate](modern-art-entry-desktop.png)](modern-art-entry-desktop.png) | [![Modern Art entry, 1440 CSS px, Log In hover](modern-art-entry-desktop-login-hover.png)](modern-art-entry-desktop-login-hover.png) |
| 390 CSS px | [![Modern Art entry, 390 CSS px, before](before-modern-art-entry-mobile.png)](before-modern-art-entry-mobile.png) | [![Modern Art entry, 390 CSS px, candidate](modern-art-entry-mobile.png)](modern-art-entry-mobile.png) | [![Modern Art entry, 390 CSS px, Log In hover](modern-art-entry-mobile-login-hover.png)](modern-art-entry-mobile-login-hover.png) |

## Modern Art lobby

Authenticated disposable fixtures. The candidate images also show the account control in its default state.

| Viewport | Before | Candidate |
| --- | --- | --- |
| 1440 CSS px | [![Modern Art lobby, 1440 CSS px, before](before-modern-art-lobby-desktop.png)](before-modern-art-lobby-desktop.png) | [![Modern Art lobby, 1440 CSS px, candidate](modern-art-lobby-desktop.png)](modern-art-lobby-desktop.png) |
| 390 CSS px | [![Modern Art lobby, 390 CSS px, before](before-modern-art-lobby-mobile.png)](before-modern-art-lobby-mobile.png) | [![Modern Art lobby, 390 CSS px, candidate](modern-art-lobby-mobile.png)](modern-art-lobby-mobile.png) |

## Modern Art tabletop

Authenticated disposable fixtures at the top of the page.

| Viewport | Before | Candidate |
| --- | --- | --- |
| 1440 CSS px | [![Modern Art tabletop, 1440 CSS px, before](before-modern-art-tabletop-desktop.png)](before-modern-art-tabletop-desktop.png) | [![Modern Art tabletop, 1440 CSS px, candidate](modern-art-tabletop-desktop.png)](modern-art-tabletop-desktop.png) |
| 390 CSS px | [![Modern Art tabletop, 390 CSS px, before](before-modern-art-tabletop-mobile.png)](before-modern-art-tabletop-mobile.png) | [![Modern Art tabletop, 390 CSS px, candidate](modern-art-tabletop-mobile.png)](modern-art-tabletop-mobile.png) |

## Sticky navigation

Authenticated disposable tabletop fixtures after scrolling.

| Viewport | Before | Candidate |
| --- | --- | --- |
| 1440 CSS px | [![Sticky navigation, 1440 CSS px, before](before-navigation-scrolled-desktop.png)](before-navigation-scrolled-desktop.png) | [![Sticky navigation, 1440 CSS px, candidate](navigation-scrolled-desktop.png)](navigation-scrolled-desktop.png) |
| 390 CSS px | [![Sticky navigation, 390 CSS px, before](before-navigation-scrolled-mobile.png)](before-navigation-scrolled-mobile.png) | [![Sticky navigation, 390 CSS px, candidate](navigation-scrolled-mobile.png)](navigation-scrolled-mobile.png) |

## Account control

Authenticated disposable fixtures. `jim` is the verified username claim supplied by the fixture.

| Viewport | Hover | Expanded |
| --- | --- | --- |
| 1440 CSS px | [![Account control hovered at 1440 CSS px](account-hover-desktop.png)](account-hover-desktop.png) | [![Account control expanded at 1440 CSS px](account-expanded-desktop.png)](account-expanded-desktop.png) |
| 390 CSS px | [![Account control hovered at 390 CSS px](account-hover-mobile.png)](account-hover-mobile.png) | [![Account control expanded at 390 CSS px](account-expanded-mobile.png)](account-expanded-mobile.png) |

## Pandemic status

Hosted staging captures.

| Viewport | Candidate | Candidate hover |
| --- | --- | --- |
| 1440 CSS px | [![Pandemic status, 1440 CSS px, candidate](pandemic-status-desktop.png)](pandemic-status-desktop.png) | [![Pandemic status, 1440 CSS px, Log In hover](pandemic-status-desktop-login-hover.png)](pandemic-status-desktop-login-hover.png) |
| 390 CSS px | [![Pandemic status, 390 CSS px, candidate](pandemic-status-mobile.png)](pandemic-status-mobile.png) | [![Pandemic status, 390 CSS px, Log In hover](pandemic-status-mobile-login-hover.png)](pandemic-status-mobile-login-hover.png) |

## Modern Art card-color comparison

Both columns are local Chromium captures using the same disposable table layout and deterministic deal. The before fixture reproduces the original review’s missing artist colors and auction icons. The after fixture uses the canonical catalog definitions. The colors and icons match the v0.4.4 card renderer and the original game definitions.

| Viewport | Before · missing fixture metadata | After · canonical fixture metadata |
| --- | --- | --- |
| 1440 CSS px | [![Scrolled desktop tabletop before fixture correction](card-colors-before-desktop-scrolled.png)](card-colors-before-desktop-scrolled.png) | [![Scrolled desktop tabletop with all five artist colors and auction icons](card-colors-after-desktop-scrolled.png)](card-colors-after-desktop-scrolled.png) |
| 390 CSS px | [![Scrolled mobile tabletop before fixture correction](card-colors-before-mobile-scrolled.png)](card-colors-before-mobile-scrolled.png) | [![Scrolled mobile tabletop with solid colored card faces](card-colors-after-mobile-scrolled.png)](card-colors-after-mobile-scrolled.png) |

The staging catalog contains color and icon values for all 25 Modern Art definitions. The scrolled captures show the header pinned and the fade at its lower edge. Outside that band the card renderer uses opaque sRGB colors. The browser regression checks the five artist swatches, the same card face in live play and replay, opacity and compositing properties, and the active fade at mobile width.

## Final identifier check

The corrected candidate lets the full tabletop identifier wrap beside the game status. The lobby keeps its existing wrapping behavior, with the session link clear of the date and player badge. These authenticated Chromium captures use a disposable table and the published oak artwork.

| View | Desktop · 1440 CSS px | Mobile · 390 CSS px |
| --- | --- | --- |
| Tabletop before | [![Desktop tabletop before the identifier fix](modern-art-tabletop-desktop.png)](modern-art-tabletop-desktop.png) | [![Mobile tabletop with the clipped identifier](modern-art-tabletop-mobile.png)](modern-art-tabletop-mobile.png) |
| Tabletop after | [![Desktop tabletop with the full identifier](identifier-tabletop-desktop.png)](identifier-tabletop-desktop.png) | [![Mobile tabletop with the complete wrapped identifier](identifier-tabletop-mobile.png)](identifier-tabletop-mobile.png) |
| Lobby after | [![Desktop lobby session link](identifier-lobby-desktop.png)](identifier-lobby-desktop.png) | [![Mobile lobby session link wrapping clear of the badge and date](identifier-lobby-mobile.png)](identifier-lobby-mobile.png) |
| Tabletop scrolled after | [![Desktop cards and the sticky navigation fade](identifier-tabletop-desktop-scrolled.png)](identifier-tabletop-desktop-scrolled.png) | [![Mobile cards and the sticky navigation fade](identifier-tabletop-mobile-scrolled.png)](identifier-tabletop-mobile-scrolled.png) |

### Shell acceptance for the final candidate

- **SH-01.** Browser checks cover initial header geometry at 320, 390, 700, 701 and 1440 CSS px, keyboard and touch access, and disclosures in narrow or short viewports. The selected mode is `header_scroll_mode=sticky`. Its header remains pinned above the content-only fade. Signed v1.1.0 requires the header to leave the reading area on scroll and grants Remote Gaming no exception. The selected mode therefore blocks production acceptance under that publication. [Infrastructure PR #8](https://github.com/harvj/infrastructure/pull/8)
- **SH-06.** Chromium exercises art-load fallback, dark preference, reduced motion with a spatial fade, and forced colors with usable account controls and the fade disabled. The light hover and disclosure treatment measures 9.56:1. The published oak record still specifies a glyph shadow, while the candidate uses shadow-free navigation and footer text. Signed acceptance requires agreement on that Site Art treatment. [Site Art presentation contract](https://github.com/harvj/site-art/blob/544064a/ops/presentation-spec-v1.md)

## Verification and release dependencies

- The candidate’s recorded application and Chrome suite passed 115 examples. Hosted Chromium checked the directory, Modern Art entry and Pandemic status at 320, 390, 700, 701 and 1440 CSS px. Browser accessibility checks covered keyboard focus and return, reduced motion, forced colors and disclosure in a short viewport. The candidate review recorded 39 passing Infrastructure Shell reference tests. [Candidate CI](https://github.com/harvj/remote-gaming/actions/runs/44959759471)
- The signed Shell baseline during capture was `v1.1.0`, which requires the header to leave the reading area on scroll. Infrastructure PR #8 merged at `46c9a088b907a7ebbe3626f71e1832f881e84da5` and adds selectable flow and sticky modes. This review records `header_scroll_mode=sticky`. The amendment requires scroll evidence for SH-01, including a content-only fade, reachable focus and anchors, and readable controls. SH-06 covers reduced motion, forced colors and unavailable effects. Production rollout requires acceptance against the applicable signed publication and owner visual approval. [Infrastructure PR #8](https://github.com/harvj/infrastructure/pull/8)
- Auth needs to supply a verified `preferred_username` through an approved staging identity channel. Remote Gaming accepts the claim from a validated ID token or approved, grant-bound Shell introspection. At capture time, live Auth discovery omitted the username claim and the Shell introspection mapping excluded staging. The account control displays `Signed in` when no verified name is supplied. [Auth discovery](https://auth.harvj.com/.well-known/openid-configuration) · [Auth Shell provider contract](https://github.com/harvj/auth/blob/6dcdca285346dc14749c5833ea1ba994d9297cac/docs/integrations/application-shell-v1.md)
