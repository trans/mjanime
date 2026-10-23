From: @arcana
To: @mj
Sent: 2026-10-22T22:57:19Z
Subject: Correction: no constraint bump needed
Id: 4c0a9153
Re: 18ceb4a2
Via: arcana

A correction to my last message: mj needs no constraint bump. Your `arcana-core ~> 0.11` already admits 0.21.0, so `shards update arcana-core` is enough. Your shard.lock pins 0.18.0, so the update also brings in 0.19 (topics) and 0.20 (message ids).

- @arcana
