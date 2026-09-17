//! An independent implementation of `HashFormat`'s documented layout, so
//! `tests/layout/expected` comes from the table in the docs rather than from
//! the Roc code it checks.

use std::hash::Hasher;

use rapidhash::v3::{rapidhash_v3_seeded, RapidSecrets};
use siphasher::sip::SipHasher13;

/// Which byte hash a structural hash ends in.
#[derive(Clone, Copy)]
pub enum Algo {
    Sip { k0: u64, k1: u64 },
    Rapid { seed: u64 },
}

impl Algo {
    fn finish(self, bytes: &[u8]) -> u64 {
        match self {
            Algo::Sip { k0, k1 } => {
                let mut h = SipHasher13::new_with_keys(k0, k1);
                h.write(bytes);
                h.finish()
            }
            Algo::Rapid { seed } => rapidhash_v3_seeded(bytes, &RapidSecrets::seed_cpp(seed)),
        }
    }
}

/// The value kinds `tests/layout` hashes.
pub enum V {
    U64(u64),
    I64(i64),
    U128(u128),
    Dec(i128),
    F64(f64),
    Bool(bool),
    Str(&'static str),
    Seq(Vec<V>),
    List(Vec<V>),
    Tag(&'static str, Vec<V>),
    Dict(Vec<(V, V)>),
}

fn word(out: &mut Vec<u8>, w: u64) {
    out.extend_from_slice(&w.to_le_bytes());
}

fn feed(out: &mut Vec<u8>, v: &V, algo: Algo) {
    match v {
        V::U64(n) => word(out, *n),
        V::I64(n) => word(out, *n as u64),
        V::U128(n) => {
            word(out, *n as u64);
            word(out, (*n >> 64) as u64);
        }
        V::Dec(attos) => feed(out, &V::U128(*attos as u128), algo),
        V::F64(f) => {
            let bits = if f.is_nan() {
                0x7ff8_0000_0000_0000
            } else if f.to_bits() == 0x8000_0000_0000_0000 {
                0
            } else {
                f.to_bits()
            };
            word(out, bits)
        }
        V::Bool(b) => word(out, *b as u64),
        V::Str(s) => {
            word(out, s.len() as u64);
            out.extend_from_slice(s.as_bytes());
        }
        V::Seq(items) => items.iter().for_each(|i| feed(out, i, algo)),
        V::List(items) => {
            word(out, items.len() as u64);
            items.iter().for_each(|i| feed(out, i, algo));
        }
        V::Tag(name, payloads) => {
            feed(out, &V::Str(name), algo);
            payloads.iter().for_each(|p| feed(out, p, algo));
        }
        V::Dict(entries) => {
            let sum = entries.iter().fold(0u64, |acc, (k, val)| {
                let mut entry = Vec::new();
                feed(&mut entry, k, algo);
                feed(&mut entry, val, algo);
                acc.wrapping_add(algo.finish(&entry))
            });
            word(out, entries.len() as u64);
            word(out, sum);
        }
    }
}

pub fn hash(v: &V, algo: Algo) -> u64 {
    let mut bytes = Vec::new();
    feed(&mut bytes, v, algo);
    algo.finish(&bytes)
}

/// `tests/layout/main.roc`'s `sample`, fields in alphabetical order.
fn sample() -> V {
    V::Seq(vec![
        V::U128(0x0102_0304_0506_0708_090a_0b0c_0d0e_0f10),                 // big
        V::U64(42),                                                         // count
        V::I64(-7),                                                         // delta
        V::List(vec![V::Bool(true), V::Bool(false), V::Bool(true)]),        // flags
        V::Str("trantor"),                                                  // name
        V::Seq(vec![V::I64(-1), V::Str("one")]),                            // pair
        V::Dec(19_990_000_000_000_000_000),                                 // price
        V::F64(0.25),                                                       // ratio
        V::Tag("Ready", vec![V::Str("go"), V::U64(3)]),                     // status
        V::Dict(vec![(V::Str("a"), V::U64(1)), (V::Str("b"), V::U64(2))]), // tags
    ])
}

/// A date method's words: year, month, day.
fn date(year: i64, month: u64, day: u64) -> V {
    V::Seq(vec![V::I64(year), V::U64(month), V::U64(day)])
}

/// A time method's words: hour through nanosecond.
fn time(hour: u64, minute: u64, second: u64, milli: u64, micro: u64, nano: u64) -> V {
    V::Seq([hour, minute, second, milli, micro, nano].into_iter().map(V::U64).collect())
}

const KEY: Algo = Algo::Sip { k0: 0x0706_0504_0302_0100, k1: 0x0f0e_0d0c_0b0a_0908 };
const SEED: Algo = Algo::Rapid { seed: 0 };

fn line(label: &str, v: &V, sip: Algo, rapid: Algo) -> String {
    format!("{label}: of {} fast {}\n", hash(v, sip), hash(v, rapid))
}

/// The expected stdout of `tests/layout/main.roc`.
pub fn expected() -> String {
    [
        line("str", &V::Str("trantor"), KEY, SEED),
        line("empty str", &V::Str(""), KEY, SEED),
        line("u64", &V::U64(42), KEY, SEED),
        line("i8", &V::I64(-7), KEY, SEED),
        line("f64", &V::F64(0.25), KEY, SEED),
        line("bool list", &V::List(vec![V::Bool(true), V::Bool(false)]), KEY, SEED),
        line("record", &sample(), KEY, SEED),
        line("local date", &date(-44, 3, 15), KEY, SEED),
        line("local time", &time(23, 59, 59, 123, 456, 789), KEY, SEED),
        line("local datetime", &V::Seq(vec![date(10000, 1, 1), time(7, 32, 0, 0, 0, 0)]), KEY, SEED),
        line("offset datetime", &V::Seq(vec![date(2026, 3, 8), time(12, 0, 0, 0, 0, 1), V::I64(-30)]), KEY, SEED),
        line("seeded", &sample(), Algo::Sip { k0: 1, k1: 2 }, Algo::Rapid { seed: 0x0123_4567_89ab_cdef }),
    ]
    .concat()
}
