# trantor-hash

Structural hashes of any value that can be encoded: records, tag
unions, lists, tuples, dicts and every scalar.

```toml
[deps]
trantor-cli  = { path = "../trantor-cli" }
trantor-hash = { path = "../trantor-hash" }
```

## Two Hash Implmenetions

```roc
import pf.Hash

Request : { path : Str, tags : List(Str), page : U32 }

## A response-cache key over a decoded request. Clients control the request,
## so the key is secret and the hash is keyed.
cache_key : Request, Hash.Key -> U64
cache_key = |request, secret| Hash.of(request, secret)

## An element id from a slug the program already holds.
element_id : Str -> U32
element_id = |slug| U64.to_u32_wrap(Hash.fast(slug, 0))
```

- **`Hash.of(value, key)`** is SipHash-1-3 under a 128-bit `Hash.Key`
  (`{ k0 : U64, k1 : U64 }`). Use it whenever the inputs can come from someone
  who would like two of them to collide. Two inputs that collide share whatever
  the hash selects, so a cache keyed by a weak hash serves one client another's
  response. Pick the key at random when the process starts and keep it secret.
- **`Hash.fast(value, seed)`** is rapidhash v3 under a `U64` seed. It is several
  times faster and spreads its bits well enough to keep only the low 32. It is
  not keyed; seed-independent collisions are published for its family. Use it
  for ids and tables over your own data.

## On Hash Equality

- Equal values hash equal.
- Record fields hash in lexicographic order, so the authored/packed order does not matter.
- A `Dict` will hash equal if all keys and values match.
- A `Set` reaches the format as a list, so its hash follows insertion
  order. Hash `Set.to_list(set).sort_with(...)` when that matters.
- `-0.0` and `0.0` hash equal, and so does every NaN.
- Strings and lists carry their lengths and tags carry their names, so
  `["ab", "c"]` and `["a", "bc"]` differ, as do two tags with the same payload.

The exact bytes each kind of value contributes are listed in `HashFormat.roc`.

A value hashes only if it has an encoder `HashFormat` can use:

- A `Try` encodes when its error is a tag union, so `Try(I64, [Missing])`
  fields hash; `Try(a, Str)` has no encoder on the current compiler (the
  builtin `Json` cannot encode it either).
- Dates hash through the date methods, as their fields in order (year, month,
  day; hour through nanosecond; an offset's minutes last): trantor-encoding's
  `Toml.LocalDate` and its siblings, and trantor-temporal's `PlainDate` and
  `PlainTime`. A `PlainDate`'s calendar is not part of its hash.
- A nominal with a hand-written `encoder_for` hashes only if that encoder is
  generic over the format, not typed to one format's state:

  ```roc
  NullableStr := [Null, Val(Str)].{
      encoder_for : enc -> (NullableStr, state -> Try(state, err))
          where [enc.encode_null : state -> Try(state, err), enc.encode_str : Str, state -> Try(state, err)]
      encoder_for = |_encoding| {
          Enc : enc
          |nullable, state| match nullable {
              Null => Enc.encode_null(state)
              Val(inner) => Enc.encode_str(inner, state)
          }
      }
  }
  ```

## Stability

This module *mostly* exists because the Roc stdlib hasher isn't public apparently
because they don't want to guarantee hash stability. There are currently no plans
to change the hashing other than removing the `Set` caveat. Any change in hashing
behavior will trigger a major version bump.

## Modules

- **`Hash`**: `of`, `fast` and `Key`.
- **`SipHash`** and **`RapidHash`**: the incremental byte hashers underneath,
  `new`, `write`, `write_u64` and `finish`. Writing bytes in pieces gives the
  same hash as writing them at once.
