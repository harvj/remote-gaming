# P1.7 Modern Art practice

Owner-only practice tables run a three-seat Modern Art game against Maya Chen and Daniel Reyes. These Chromium captures use a disposable table, deterministic deal, a fixture Auth login, and the published oak artwork. Desktop is 1440 CSS px and mobile is 390 CSS px. Select a screenshot to open the full-resolution image.

| Phase | Desktop | Mobile |
| --- | --- | --- |
| Opening hand | [![Ten paintings at the desktop practice table](hand-desktop.png)](hand-desktop.png) | [![Opening hand and season rail at mobile width](hand-mobile.png)](hand-mobile.png) |
| Sealed bidding | [![Desktop sealed auction](auction-desktop.png)](auction-desktop.png) | [![Mobile sealed bid entry](auction-mobile.png)](auction-mobile.png) |
| Bank settlement | | [![Mobile artist values and bank payout](settlement-mobile.png)](settlement-mobile.png) |
| Final results | [![Desktop final standings](results-desktop.png)](results-desktop.png) | [![Mobile final standings](results-mobile.png)](results-mobile.png) |

## Rules and staging operation

The legacy tabletop records card plays and observations from physical auctions. The practice table shares the original deck, artists, auction icons, and card styling. It adds digital bidding, private balances, season valuation, and deterministic settlement on a separate disposable table. The published rulebook supplies the auction and scoring rules. The practice adapter gives the owner the first offer, and a cashless fixed-price seller may offer at zero so the auction can progress. Hidden bids reveal together, and opponent hands and balances stay private until the rules call for disclosure. [Publisher’s Modern Art rulebook](https://www.cmon.com/wp-content/uploads/2023/06/MA_Rulebbok_Artbook_v18-low.pdf)

Sign into the staging Modern Art lobby as the owner and choose **Modern Art practice tables**. Start a table or resume one from the list. The table provides phase guidance and a separate rules reference. Use **Remove this disposable table** to delete its state and command history.

The practice link, routes, and Cable subscription require the designated private staging host, verified owner login, and staging opt-in. The feature uses its own table and does not affect an existing physical or historical session.

## Shared game rules and historical market

These Chromium captures use disposable practice and historical replay fixtures.

| View | Desktop | Mobile |
| --- | --- | --- |
| Game Rules drawer | [![Rules drawer over the desktop tabletop](rules-drawer-desktop.png)](rules-drawer-desktop.png) | [![Rules drawer over the mobile tabletop](rules-drawer-mobile.png)](rules-drawer-mobile.png) |
| Replay and missing bid history | [![Historical replay with bid history marked Not recorded](replay-bids-not-recorded-desktop.png)](replay-bids-not-recorded-desktop.png) | [![Mobile historical replay with the recorded market](replay-bids-not-recorded-mobile.png)](replay-bids-not-recorded-mobile.png) |

[Rules audit and historical compatibility](rules-and-history.md)

## Recorded human auctions

These desktop and mobile Chromium captures use private human-table fixtures. The live human table, recorded replay and AI practice reuse the same auction layout, rules drawer, artist market, cards, and settlement and standings components.

| Auction | Desktop | Mobile |
| --- | --- | --- |
| Open | [![Open auction desktop](human-open-desktop.png)](human-open-desktop.png) | [![Open auction mobile](human-open-mobile.png)](human-open-mobile.png) |
| Once Around | [![Once Around desktop](human-once-around-desktop.png)](human-once-around-desktop.png) | [![Once Around mobile](human-once-around-mobile.png)](human-once-around-mobile.png) |
| Sealed | [![Sealed auction desktop](human-sealed-desktop.png)](human-sealed-desktop.png) | [![Sealed auction mobile](human-sealed-mobile.png)](human-sealed-mobile.png) |
| Fixed Price | [![Fixed Price desktop](human-fixed-desktop.png)](human-fixed-desktop.png) | [![Fixed Price mobile](human-fixed-mobile.png)](human-fixed-mobile.png) |
| Double | [![Double auction desktop](human-double-desktop.png)](human-double-desktop.png) | [![Double auction mobile](human-double-mobile.png)](human-double-mobile.png) |

**Create New** in the staging Modern Art lobby starts a human-bidding table. The host can add named acceptance seats with the existing revocable staging grants. Start the game once three to five seats are present. **Replay history** opens the recorded command timeline with the authenticated player’s visibility applied at each action. AI practice remains a separate owner-only option. Production human gameplay stays disabled until separately approved.

## Historical tabletop comparison

These Chromium captures use the read-only presentation data from staging session `kesir-ample-gifa-ghnw` with a disposable local sign-in. The original renderer and the canonical tabletop receive the same recorded source data. The record contains 117 unversioned frames, so the tabletop shows the stored result without reconstructing a bid history or inventing action numbers.

| View | Desktop | Mobile |
| --- | --- | --- |
| Historical table before | [![Legacy historical view on desktop](kesir-before-desktop.png)](kesir-before-desktop.png) | [![Legacy historical view on mobile](kesir-before-mobile.png)](kesir-before-mobile.png) |
| Historical table after | [![Canonical historical tabletop on desktop](kesir-after-desktop.png)](kesir-after-desktop.png) | [![Canonical historical tabletop on mobile](kesir-after-mobile.png)](kesir-after-mobile.png) |
| Bob McMurray’s badges | [![Recorded badges and German flag on desktop](kesir-bob-badges-desktop.png)](kesir-bob-badges-desktop.png) | [![Bob’s badges wrap in the mobile player box](kesir-bob-badges-mobile.png)](kesir-bob-badges-mobile.png) |

Compare the **Opening hand** practice screens above for the season rail, auction, market, hand, and player-box composition. Historical market valuations, bid history, and cash display **Not recorded** where unsupported. The rank, role flag, score, winner status, profile statistics, and last win come from the record and its existing player metadata.

Digital practice and human games number committed player commands in their durable order. Each command retains its number in Recent Actions, full history, and replay. Settlement and reveal detail stay grouped with the command that caused them. A sealed bid retains its place while its amount and bidder stay private until reveal. Historical entries use their existing frame references when available.

## Hand sorting

These Chromium captures use the same deterministic opening deal in a disposable practice table with fixture Auth and the published oak artwork. The earlier opening-hand captures show the presentation before the shared controls. The new captures are scrolled to the hand with **Artist** sorting and **Group by artist** enabled.

| State | Desktop, 1440 CSS px | Mobile, 390 CSS px |
| --- | --- | --- |
| Before | [![Desktop opening hand before the shared sorting controls](hand-desktop.png)](hand-desktop.png) | [![Mobile opening hand before the shared sorting controls](hand-mobile.png)](hand-mobile.png) |
| After | [![Desktop hand sorted and grouped by artist](hand-sort-desktop.png)](hand-sort-desktop.png) | [![Mobile hand sorted and grouped by artist](hand-sort-mobile.png)](hand-sort-mobile.png) |

**Sort hand** cycles through Recorded order, Artist, and Auction type. Grouping is independent. Both preferences are local to the table and browser tab, and the hand retains its authoritative order in the game record.
