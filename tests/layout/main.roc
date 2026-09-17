app [main!] { pf: platform "../target/trantor/app/platform/main.roc" }

import pf.OsStr
import pf.Stdout
import pf.Hash

## Exact hashes of fixed values, one per kind of value the format writes. These
## pin the structural layout (D-S1-6): a change to any line of `expected` is a
## change to every stored hash and needs a major version.

Shape : {
	name : Str,
	count : U64,
	delta : I32,
	ratio : F64,
	price : Dec,
	flags : List(Bool),
	big : U128,
	status : [Idle, Ready(Str, U8), Failed(Str)],
	pair : (I64, Str),
	tags : Dict(Str, U16),
}

sample : Shape
sample = {
	name: "trantor",
	count: 42,
	delta: -7,
	ratio: 0.25,
	price: 19.99,
	flags: [True, False, True],
	big: 0x0102030405060708090a0b0c0d0e0f10,
	status: Ready("go", 3),
	pair: (-1, "one"),
	tags: Dict.from_list([("a", 1), ("b", 2)]),
}

## Test types with the date contract's encoders, one per date method.
Day := { year : I32, month : U8, day : U8 }.{
	encoder_for : encoder -> (Day, state -> Try(state, err))
		where [encoder.encode_local_date : encoder, { year : I32, month : U8, day : U8 }, state -> Try(state, err)]
	encoder_for = |encoder| |day, state| encoder.encode_local_date({ year: day.year, month: day.month, day: day.day }, state)
}

Clock := { hour : U8, minute : U8, second : U8, millisecond : U16, microsecond : U16, nanosecond : U16 }.{
	encoder_for : encoder -> (Clock, state -> Try(state, err))
		where [encoder.encode_local_time : encoder, Time, state -> Try(state, err)]
	encoder_for = |encoder| |clock, state| encoder.encode_local_time(time_of(clock), state)
}

Local := { date : Date, time : Time }.{
	encoder_for : encoder -> (Local, state -> Try(state, err))
		where [encoder.encode_local_datetime : encoder, { date : Date, time : Time }, state -> Try(state, err)]
	encoder_for = |encoder| |local, state| encoder.encode_local_datetime({ date: local.date, time: local.time }, state)
}

Moment := { date : Date, time : Time, offset : { minutes : I16 } }.{
	encoder_for : encoder -> (Moment, state -> Try(state, err))
		where [encoder.encode_offset_datetime : encoder, { date : Date, time : Time, offset : { minutes : I16 } }, state -> Try(state, err)]
	encoder_for = |encoder| |moment, state| encoder.encode_offset_datetime({ date: moment.date, time: moment.time, offset: moment.offset }, state)
}

Date : { year : I32, month : U8, day : U8 }

Time : { hour : U8, minute : U8, second : U8, millisecond : U16, microsecond : U16, nanosecond : U16 }

time_of : Clock -> Time
time_of = |clock| { hour: clock.hour, minute: clock.minute, second: clock.second, millisecond: clock.millisecond, microsecond: clock.microsecond, nanosecond: clock.nanosecond }

day : Day
day = { year: -44, month: 3, day: 15 }

clock : Clock
clock = { hour: 23, minute: 59, second: 59, millisecond: 123, microsecond: 456, nanosecond: 789 }

local : Local
local = { date: { year: 10000, month: 1, day: 1 }, time: { hour: 7, minute: 32, second: 0, millisecond: 0, microsecond: 0, nanosecond: 0 } }

moment : Moment
moment = { date: { year: 2026, month: 3, day: 8 }, time: { hour: 12, minute: 0, second: 0, millisecond: 0, microsecond: 0, nanosecond: 1 }, offset: { minutes: -30 } }

bools : List(Bool)
bools = [True, False]

key : Hash.Key
key = { k0: 0x0706050403020100, k1: 0x0f0e0d0c0b0a0908 }

line : Str, U64, U64 -> Str
line = |label, sip, rapid| "${label}: of ${sip.to_str()} fast ${rapid.to_str()}"

main! : List(OsStr) => Try({}, _)
main! = |_args| {
	lines = [
		line("str", Hash.of("trantor", key), Hash.fast("trantor", 0)),
		line("empty str", Hash.of("", key), Hash.fast("", 0)),
		line("u64", Hash.of(42.U64, key), Hash.fast(42.U64, 0)),
		line("i8", Hash.of(-7.I8, key), Hash.fast(-7.I8, 0)),
		line("f64", Hash.of(0.25.F64, key), Hash.fast(0.25.F64, 0)),
		line("bool list", Hash.of(bools, key), Hash.fast(bools, 0)),
		line("record", Hash.of(sample, key), Hash.fast(sample, 0)),
		line("local date", Hash.of(day, key), Hash.fast(day, 0)),
		line("local time", Hash.of(clock, key), Hash.fast(clock, 0)),
		line("local datetime", Hash.of(local, key), Hash.fast(local, 0)),
		line("offset datetime", Hash.of(moment, key), Hash.fast(moment, 0)),
		line("seeded", Hash.of(sample, { k0: 1, k1: 2 }), Hash.fast(sample, 0x0123456789abcdef)),
	]
	Stdout.line!(Str.join_with(lines, "\n"))
}
