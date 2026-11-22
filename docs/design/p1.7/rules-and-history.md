# Modern Art rules and historical compatibility

The practice engine and the historical frame engine have different sources of truth. Historical frames record the physical table’s painting plays, game transitions, and later observations or corrections. The practice engine is authoritative for its digital auction commands, private cash and bids, purchases, and bank settlement. A historical reported sale is an observation about an outcome and does not establish individual bids, passes, or balances.

## Rules comparison

- The historical engine advances after an ordinary painting play because physical participants handled the auction. The digital engine waits for the successful legal bid, pass, or fixed-price decision and records settlement in command order.
- The historical engine records double pairing and releases a single double through passes. The digital engine also applies the second card’s auction type, transfers the hammer and proceeds to its seller, and lets the original seller keep an unpaired painting.
- The historical engine tracks seasons and the fifth painting, with physical payouts supplied as available. The digital engine computes ranking tiles, cumulative values for ranked artists, bank payouts and the final cash standings from its own state.
- The three-seat practice adapter gives the owner the first offer and uses a deterministic seed for replay. The original tabletop rules choose the first auctioneer by age. The display retains the legacy edition’s artist names and auction icons. [Publisher’s Modern Art rulebook](https://www.cmon.com/wp-content/uploads/2023/06/MA_Rulebbok_Artbook_v18-low.pdf)

## Compatibility boundary

New staged human games use the same digital rules and authoritative command path as practice, without automated decisions. The server resolves the authenticated browser to a participant before projecting private information or accepting commands. The owner signs in through Auth. Staging acceptance peers use revocable grants tied to their specific seats. Production human participation remains gated and is intended for independently authenticated users. Digital replay reconstructs each revision from the original deal and recorded commands, and applies the same sealed-bid reveal boundary as live play.

Keep historical replay on its existing frame interpreter and project only the facts that interpreter supports. Bid histories remain **Not recorded** where the physical-era records lack them. The shared rules drawer, season rail, market and painting cards apply to both paths. Recorded sales and correction history retain their original source and wording. Replay remains unavailable when the frame history is incomplete or unsupported.
