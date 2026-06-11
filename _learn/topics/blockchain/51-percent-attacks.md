---
title: 51% attacks on proof-of-work chains
slug: 51-percent-attacks
aliases: [majority-hash-attack, blockchain-reorg-attack]
---
{% raw %}

A 51% attack is the original sin of Nakamoto consensus: whoever controls more than half the hashpower on a proof-of-work chain controls which history wins. The attacker mines a longer fork in private, spends coins on the public chain, then broadcasts the secret chain to orphan the spending transactions. "Confirmed" becomes negotiable. The risk is academic on Bitcoin (where renting that much SHA-256 is currently infeasible) and operationally real on every small-cap PoW altcoin that shares an algorithm with a bigger sibling. If you run an exchange, a bridge, or a payments processor that credits PoW deposits, this is a live threat model, not a 2013 history lesson. See [[blockchain-fundamentals]] and [[consensus-protocols]] for the substrate this attack subverts.

## Mental model

Nakamoto consensus picks the chain with the most accumulated work. Honest miners extend the tip they see. An attacker with hashrate fraction `q > 0.5` does the opposite: mines on a private tip rooted at block `H - k`, where `k` is the depth they need to reverse.

Concrete double-spend flow:

```
t0  attacker deposits 1000 BTG to Exchange, tx in block H
t0  attacker starts mining private fork from block H-1
t1  Exchange waits k=10 confirmations, credits account
t2  attacker sells BTG for BTC, withdraws BTC off-chain
t3  attacker's private fork is now H-1 -> H' -> ... -> H+12
t3  attacker broadcasts. Network reorgs to longer chain.
t3  original deposit tx is no longer in the canonical chain;
    BTG returns to attacker's wallet. BTC withdrawal is final.
```

Selfish mining (Eyal-Sirer, 2013) is the boundary case: with `q` as low as ~0.33 and good network position you can publish withheld blocks strategically to waste honest work and inflate your revenue share, without rewriting confirmed history. 51% is the regime where you can also rewrite it.

Economics decide feasibility. NiceHash and similar rental markets price hashpower by the hour for every major algorithm (Ethash, Equihash, Lyra2REv3, X16R). The relevant metric is `NiceHashable %` from `crypto51.app`: the fraction of a chain's hashrate currently available to rent. When that number is over 100% and an hour of attack costs less than the deposit you can drain, you have a customer.

## Tradecraft

You do not need custom code to model this. A vanilla node, a wallet, and rented hash are enough. Sketch on a regtest chain first:

```bash
# Bitcoin Core 27.x regtest — simulate a reorg locally
bitcoind -regtest -daemon -datadir=/tmp/honest
bitcoind -regtest -daemon -datadir=/tmp/attacker -port=18555 -rpcport=18556

# fund both, then split the network
bitcoin-cli -regtest -datadir=/tmp/honest   generatetoaddress 101 $ADDR_H
bitcoin-cli -regtest -datadir=/tmp/honest   disconnectnode "127.0.0.1:18555"

# honest chain mines deposit, attacker mines private fork
bitcoin-cli -regtest -datadir=/tmp/honest   sendtoaddress $EXCHANGE 10
bitcoin-cli -regtest -datadir=/tmp/honest   generatetoaddress 6 $ADDR_H
bitcoin-cli -regtest -datadir=/tmp/attacker generatetoaddress 12 $ADDR_A

# reconnect — longer attacker chain wins, deposit tx is evicted
bitcoin-cli -regtest -datadir=/tmp/honest addnode "127.0.0.1:18555" onetry
bitcoin-cli -regtest -datadir=/tmp/honest getchaintips
```

For real-world target reconnaissance:

```bash
# rough cost-to-attack snapshot for an Ethash-family chain
curl -s https://whattomine.com/coins.json | jq '.coins["Ethereum Classic"]'
# rented hash inventory
curl -s https://api2.nicehash.com/main/api/v2/public/simplemultialgo/info | \
  jq '.miningAlgorithms[] | select(.algorithm=="DAGGERHASHIMOTO")'
```

Historical playbook references, by chain:

- Ethereum Classic, January 2019: ~$1.1M double-spent across Coinbase and Gate.io via 100+ block reorgs. Coinbase had been crediting at 12 confirmations.
- Ethereum Classic, August 2020: three separate reorg waves over two weeks; one reorg was over 7000 blocks deep. ETC raised confirmation requirements to 50000 and introduced the MESS (Modified Exponential Subjective Scoring) finality heuristic.
- Bitcoin Gold, May 2018 and again January 2020: ~$18M and ~$72k double-spends; algorithm was Equihash 144,5, fully rentable.
- Verge, April-May 2018: timestamp manipulation plus algo-switching bug let an attacker mine many blocks per second.
- Vertcoin, December 2018: 22-block reorg, ~$100k double-spent at Bittrex.

## Detection and telemetry

You cannot prevent a reorg you do not own the hashrate to outpace; you detect it and refuse to credit until it stabilises.

- Run your own full node, never trust a hosted RPC alone. Compare `getbestblockhash` across two independent nodes on different networks.
- Alert on `reorg` log lines. Bitcoin Core writes `Warning: Large fork found ...`; Geth/Erigon emit `chain reorg` events with `oldNumHashes` and `dropped` counts. Ship these to your SIEM.
- Hunt query (example, JSON logs in Splunk-style syntax):

```
index=blockchain sourcetype=geth "reorg"
| rex field=_raw "depth=(?<depth>\d+)"
| where depth > 3
| stats count by host, depth, _time
```

- Subscribe to `newHeads` over WebSocket and track stale-block rate. A sustained jump in uncles or stale tips is the canary for selfish mining.
- For deposit pipelines, make confirmation depth a function of `current_hashrate / nicehash_available_hashrate`. ETC, BTG, RVN deserve 100+ confirmations or outright halts during rental spikes.
- Correlate with mempool telemetry from [[mempool-monitoring]] — a quiet public mempool around your deposit tx is a flag that the attacker is privately mining the fork.

## OPSEC pitfalls

- Treating "6 confirmations" as a universal constant. It was calibrated for Bitcoin's hashrate, not for a chain renting 130% of itself off NiceHash.
- Sharing a PoW algorithm with a 100x bigger sibling (ETC vs ETH pre-Merge, BCH vs BTC for SHA-256). The smaller chain inherits none of the security and all of the rentable hash.
- Trusting block explorers for finality. Many explorers display the longest chain they have seen, which during a reorg is the attacker's chain.
- Believing PoS makes this obsolete. It changes the attack surface to long-range attacks, time-bandit MEV reorgs, and stake slashing — see [[mev-attacks]] and the closing paragraphs below.
- Auditing the contract but not the deposit policy. A perfect [[smart-contract-audit-primer]] cannot save a hot wallet that credits a reorg-able chain at three confirmations.

Adjacent attacks worth naming. Time-bandit reorgs on PoS Ethereum are short reorgs (1-7 slots) mounted by colluding proposers to capture juicy MEV that landed in a recent block — economic finality via Casper FFG caps the damage at the next epoch boundary (~12.8 minutes). Long-range attacks on PoS exploit old validator keys whose stake has been withdrawn: an attacker who buys those keys cheaply can rewrite history from a checkpoint they hold the keys for. Defences are weak subjectivity checkpoints and social-layer finality, not chain weight. The broader picture lives in [[blockchain-security]].

## References

- https://bitcoin.org/bitcoin.pdf
- https://www.crypto51.app/
- https://blog.coinbase.com/ethereum-classic-etc-is-currently-being-51-attacked-33be13ce32de
- https://arxiv.org/abs/1311.0243
- https://ethereum.org/en/developers/docs/consensus-mechanisms/pos/attack-and-defense/
- https://blog.ethereum.org/2014/11/25/proof-stake-learned-love-weak-subjectivity

See also: [[blockchain-fundamentals]], [[consensus-protocols]], [[smart-contract-audit-primer]], [[mev-attacks]], [[mempool-monitoring]], [[blockchain-security]]

{% endraw %}
