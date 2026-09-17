app [main!] { pf: platform "../target/trantor/app/platform/main.roc" }

import pf.OsStr
import pf.Stdout
import pf.Hash

## README.md's examples, verbatim, so the README keeps compiling.

Request : { path : Str, tags : List(Str), page : U32 }

## A response-cache key over a decoded request. Clients control the request,
## so the key is secret and the hash is keyed.
cache_key : Request, Hash.Key -> U64
cache_key = |request, secret| Hash.of(request, secret)

## An element id from a slug the program already holds.
element_id : Str -> U32
element_id = |slug| U64.to_u32_wrap(Hash.fast(slug, 0))

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

main! : List(OsStr) => Try({}, _)
main! = |_args| {
	secret = { k0: 11, k1: 22 }
	a = cache_key({ path: "/a", tags: ["x"], page: 1 }, secret)
	b = cache_key({ page: 1, tags: ["x"], path: "/a" }, secret)
	c = cache_key({ path: "/a", tags: ["x"], page: 2 }, secret)
	Stdout.line!("same request, same key: ${Str.inspect(a == b)}")?
	Stdout.line!("different page, different key: ${Str.inspect(a != c)}")?
	Stdout.line!("id is stable: ${Str.inspect(element_id("slug") == element_id("slug"))}")?
	bio : { bio : NullableStr, optional : Try(I64, [Missing]) }
	bio = { bio: NullableStr.Val("hi"), optional: Err(Missing) }
	none : { bio : NullableStr, optional : Try(I64, [Missing]) }
	none = { bio: NullableStr.Null, optional: Err(Missing) }
	Stdout.line!("nullable and optional fields hash: ${Str.inspect(Hash.of(bio, secret) != Hash.of(none, secret))}")
}
