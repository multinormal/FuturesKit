# FuturesKit

## Introduction

FuturesKit is a Swift 3 package that aims to make is easier to write asynchronous code
by providing a simple pure-Swift implementation of 
[futures and promises](https://en.wikipedia.org/wiki/Futures_and_promises)

FuturesKit provides a small set of types, functions, and operators that allow asynchronous 
programming concepts to be "lifted" up into the type system. The generic types that FuturesKit 
provides allows you to explicitly model the eventual results of asynchronous operations (e.g., 
values such as the result of a network request or an SQL query, or an update to your user's GPS 
location). FuturesKit's functions and operators allow you to avoid writing multiply-nested blocks
of callbacks; instead, you write nice, linear code that applies transforms to values that represent
the eventual results of asynchronous operations. It is easy to combine the eventual results of
multiple asynchronous operations. It is easy to define what happens when an asynchronous 
operations fails.

FuturesKit uses Grand Central Dispatch (GCD, libdispatch) to perform the required
asynchronous and synchronous operations. FuturesKit was originally inspired by 
[BrightFutures](https://github.com/Thomvis/BrightFutures). While the APIs for FuturesKit and
BrightFutures are similar, their implementations are quite different. At a high level, one example 
of this difference is that FuturesKit's `Future` is a value type, while BrightFutures's `Future` 
is a reference type: using value types can make it much easier to reason about memory management.

## Installation

To use FuturesKit, add the URL to its GitHub repo to your module's dependencies. For example:

```swift
import PackageDescription

let package = Package(
    name: "MyApp",
    targets: [],
    dependencies: [
        .Package(url: "https://github.com/multinormal/FuturesKit.git",
                 majorVersion: 1)
    ]
)
```

## Contributing

You are encouraged to contribute to FuturesKit with a focus on identifying and fixing bugs rather
than adding major new features and making FuturesKit more complex. If you find a bug, please write
a unit test that exercises that bug and create a pull request. Ideally, please create a second
pull request based on the unit test that fixes the bug. 

To build FuturesKit, check out the repository and run `swift build`. To run the unit tests, run
`swift test`.

## Documentation

### Creating and using `Future`s

The following is a brief overview of how to use FuturesKit. Detailed explanations follow below.

1. Make sure you `import FuturesKit` at the top of any Swift file in which you need to access 
   FuturesKit.
2. Create a `Future` from a function using the `future` function, or from a callback-based API 
   by creating a `Promise` (see the "Promises" section below for details).
3. If the `Future`'s value is given by a function, that function will be executed asynchronously
   on a background queue.
4. If the `Future`'s value is given by a callback-based API via a `Promise`, that API's threading 
   model will will be used (see the "Promises" section below for details).
5. Transform and compose `Future`s as necessary using the provided operators and functions (see the
   Transforming and composing `Future`s section below for details).
6. Add callbacks a `Future` using its `onSuccess` and `onError` methods. You can add multiple callbacks
   to a `Future`, but the order in which they will be called is not guaranteed.
7. Those callbacks will be executed asynchronously on the main queue when the `Future` completes.
8. Adding a callback to an already-completed`Future` will immediately call the callback asynchronously 
   on the main queue.
9. A callback will only be called once in the lifetime of the `Future` (unless you add the callback
   multiple times).
10. Make sure you **retain any `Future` whose value you need to use**. If the reference count of a
   `Future` becomes zero before it has succeeded or failed the `Future` and its callbacks will be 
   deallocated from memory and the callbacks will not be called. If you transform or compose `Future`s,
   and only need the value of the resulting `Future`, you only need to retain that `Future`, not the
   intermediate `Future`s.

### FutureKit's Types

FuturesKit provides three types:

1. `Future<T>`: represents the eventual result of an asynchronous computation that, if 
   successful, provides a value of type `T`. If the asynchronous computation is not successful,
   the `Future` will fail with an error.
2. `Promise<T>`: allows you to convert a non-`Future` based asynchronous computation into 
   a `Future`-based computation. `T` is the type of the value that the `Promise` and its 
   `Future` represent.
3. `GuaranteedFuture<T>`: represents a `Future` that will either succeed with the result of
   the asynchronous computation, or will succeed with a fallback value if the asynchronous 
   computation fails.

### Creating a simple `Future`

The easiest way to create a `Future` is to use the `future` function:

```swift
func someLongRunningComputation() -> Int {
  // Do something that takes a long time...
}

let myFuture = future {someLongRunningComputation()}
```

This creates a `Future<Int>` that asynchronously runs the long computation on a background thread.
Block notation can be used to create `Future`s.

If you have a value that you need to wrap in a `Future`, use `futureFromValue`:

```swift
let anotherFuture = futureFromValue("Hello")
```

This creates a `Future<String>` that represents the value `"Hello"`. The call is synchronous and the
`Future` completes immediately because the value is immediately available. It may seem odd to create
`Future`s that do not model asynchronous computations, but in some cases it can be useful to do so
(unit testing is one of these cases). Overuse is probably a sign you are not doing things correctly, 
however.

We will see how to use `Future`s below, but first we will learn another way to create `Future`s, using
`Promise`s.

### `Promise`s

A `Promise` is used to convert a callback-based API to `Future`-based code. A `Promise` is
either "kept" with the successful result of an asynchronous operation, or it is "broken"
with an error. The `Future` corresponding to a `Promise` is obtained and used to represent
the eventual result of the callback-based API call.

Many of the APIs provided by Apple use a callback-based API, and so the starting point for
working with these APIs is to create a `Promise` that is manipulated within the 
callback-based API, and then to create the corresponding `Future` that can be used elsewhere.

Creating a `Promise` and then a `Future` may seem a little verbose, but in practice
creating a `Promise` is a relatively uncommon thing to do. While you might have many view controllers
in your app that need to make network requests, you probably only need write the code to create a 
`Promise<NetworkRequest>` and its corresponding `Future<NetworkRequest>` once. Each view controller
can then call that code to get and retain one or more `Future`s that represents the network requests.

Here is a real-world example of how a `Promise` is used to convert the callback-based API
used in CoreMotion to `Future`-based code.

```swift
// Create a Promise to capture the result of a query to the pedometer.
let promise = Promise<CMPedometerData>()

// Define a CoreMotion-compatible handler, which will be called when the query
// to the pedometer completes.
func handler(pedometerData: CMPedometerData?, error: Error?) {
  if let error = error {
    promise.brokenWithError(error)
    return
  }
  guard let pedometerData = pedometerData else {
    let error = Error(domain: "my.domain", code: 1, userInfo: nil) // Customize for your scenario.
    promise.brokenWithError(error)
    return
  }
  promise.keptWithValue(pedometerData)
}

// Querying the pedometer can take some time to complete, so must be done on a concurrent thread.
let queue = DispatchQueue(label: "my.domain", attributes: DispatchQueue.Attributes.concurrent)
queue.async {
  let startDate = Date(timeIntervalSinceNow: -24 * 60 * 60) // 24 hours ago.
  let endDate = Date() // Now.
  pedometer.queryPedometerData(from: startDate, to: endDate, withHandler: handler)
}

// Now get the Future instance that represents the eventual result of the pedometer query.
let pedometerFuture = promise.future
```

The `pedometerFuture` would then be transformed, composed with other `Future`s, ultimately
retained, and would have callbacks added via `onSuccess` and `onError`.

### `Future`s

Conceptually, all `Future`s have a `Promise`. If the `Promise` is "kept", then the `Future`
succeeds and the value of the asynchronous computation becomes available. If the `Promise`
is "broken", then the `Future` fails. You work with the resulting value or error by adding
blocks to the `Future` instance.

`Future` runs asynchronous computations on a background queue. When the `Future` succeeds or
fails, code in the blocks added to the `Future` is run on the main thread. This is useful for 
two reasons:

1. It is really hard for humans to keep track of which thread code is running on. The model used
by FuturesKit makes this much simpler.
2. Updates to view objects (e.g., on iOS) must be performed on the main thread. Writing this code
in the success and error blocks ensures this is done correctly.

If it is untenable for a `Future` to fail, use a `GuaranteedFuture<T>` instead, which will supply 
a default fallback value if the `Future` fails.

Here is a concrete example of how the `Future` created above to represent the result of
a pedometer query can be used to update a label.

```swift
pedometerFuture.onSuccess {pedometerData in
  self.label.text = "\(pedometerData.numberOfSteps)"
}.onError {error in
  self.label.text = "0"
  // Log the error...
}.end()
```

There are a few things to note here:

1. Success and error blocks are added to the `Future` using `onSuccess` and `onError`.
2. The `pedometerData` value in the `onSuccess` block is of type `CMPedometerData`. This is because
   the `Future` and `Promise` it originate from are parameterised with type `CMPedometerData`.
3. The `onSuccess` and `onError` blocks can be chained. Indeed it is possible to add multiple 
   success or error blocks to the same `Future`. However, there are no guarantees about the order 
   in which distinct success and error blocks will be called, so if this is important, use a single
   block.
4. The `end()` call terminates the chain. This call has no runtime cost, it simply
   serves to prevent a compiler warning about failing to use the return value from the chain. 
   It is essentially equivalent to the `let _ = ...` syntax.

### You must retain `Future`s!

One of the most important things to understand about `Future`s is that **for the result of a `Future`
to made available to its blocks, the `Future` (or a transformed or composed version of that `Future` )
must be retained somewhere**.

It is perfectly safe to transform a `Future` into another `Future` using one or more of the operators 
and functions described below, and for those intermediate `Futures` to go out of scope without being 
retained. However, ultimately each "useful" `Future` must be retained somewhere (in an iOS app, this 
will often be in a view controller). If Swift's automatic reference counting memory management system 
detects that a `Future` has zero references, the `Future` will be removed from memory. This will cause 
all of the success and error blocks attached to the `Future` to be removed, and they will not be called!

### Transforming and composing `Future`s

One of the main benefits of FuturesKit is the ability to transform and compose `Future`s. This
allows you to write asynchronous code in a linear manner without deeply nested callback code, and
to allow the type system to help you reason about your code.

There are numerous functions to transform and compose `Future`s. Almost all of these functions are 
made available via an overloaded `•` operator (which can be typed with Option+8, or whatever
shortcut applies for your Mac's keyboard layout). Using a single overloaded operator allows `Future`s 
to be composed easily, and saves you from needing to look up the correct function name! While operator
overloading has often proven be problematic in other languages, it works quite well in FuturesKit, 
especially when Xcode is used to display the inferred types of variables and results of the transforms 
and compositions.

**Transforming a `Future<T>` to a `Future<U>`:**

```swift
func • <T,U>(f: @escaping (T) throws -> U, t: Future<T>) -> Future<U>
```

Given a function `f` that maps from type `T` to type `U`, and a `Future` `t` of type `T`, 
`f • t` is a `Future` of type `U`. Function `f` may throw, in which case the resulting
`Future` will fail.

```swift
func • <T,U>(f: @escaping (T) throws -> Future<U>, t: Future<T>) -> Future<U>
```

Given a function `f` that maps from type `T` to a `Future` of type `U`, and a `Future` `t` 
of type `T`, `f • t` is a `Future` of type `U`. Function `f` may throw, in which case the 
resulting `Future` will fail.

**Mapping a function that returns a `Future` or `GuaranteedFuture` over a `SequenceType`:**

```swift
func • <S:Sequence, T>(f: (S.Iterator.Element) throws -> Future<T>, s: S) -> Future<[T]>
```

Given a function `f` that maps from an element of a sequence of type `S` to a `Future` of type `T`, 
and a sequence of type `S`, `f • s` is a `Future` of type `[T]`. Function `f` may throw, in 
which case the resulting `Future` will fail.

```swift
func • <S:Sequence, T>(f: (S.Iterator.Element) -> GuaranteedFuture<T>, s: S) -> GuaranteedFuture<[T]>
```

Given a function `f` that maps from an element of a sequence of type `S` to a `GuaranteedFuture` of 
type `T`, and a sequence of type `S`, `f • s` is a `GuaranteedFuture` of type `[T]`.

```swift
func • <S:Sequence, T>(f: @escaping (S.Iterator.Element) throws -> GuaranteedFuture<T>, s: S) -> Future<[T]>
```

Given a function `f` that maps from an element of a sequence of type `S` to a `GuaranteedFuture` of type 
`T`, and a sequence of type `S`, `f • s` is a `Future` of type `[T]`. Since function `f` may throw, the 
result type cannot be a `GuaranteedFuture`. If `f` throws, the resulting `Future` will fail.

**Composing multiple `Future`s (or `GuaranteedFuture`s) into a single `Future` (or `GuaranteedFuture`s) of a tuple:**

```swift
func • <T,U>(t: Future<T>, u: Future<U>) -> Future<(T, U)>
```

Given a `Future` `t` of type `T` and a `Future` `u` of type `U`, `t • u` is a `Future` of type
`(T, U)`. If one or both of `t` and `u` fail, the resulting `Future` will fail.

```swift
func • <S,T,U>(s: Future<S>, tu: Future<(T, U)>) -> Future<(S,T,U)>
```

Given a `Future` `s` of type `S` and a `Future` `tu` of type `(T, U)`, `s • tu` is a `Future` of type
`(S, T, U)`. If one or both of `s` and `tu` fail, the resulting `Future` will fail.

```swift
func • <T,U>(t: GuaranteedFuture<T>, u: GuaranteedFuture<U>) -> GuaranteedFuture<(T, U)>
```

Given a `GuaranteedFuture` `t` of type `T` and a `GuaranteedFuture` `u` of type `U`, `t • u` is a 
`GuaranteedFuture` of type `(T, U)`.

```swift
func • <S,T,U>(s: GuaranteedFuture<S>, tu: GuaranteedFuture<(T, U)>) -> GuaranteedFuture<(S,T,U)>
```

Given a `GuaranteedFuture` `s` of type `S` and a `GuaranteedFuture` `tu` of type `(T, U)`, `s • tu` is 
a `GuaranteedFuture` of type `(S, T, U)`.

```swift
func • <S,T,U,V>(s: GuaranteedFuture<S>, tu: GuaranteedFuture<(T, U, V)>) -> GuaranteedFuture<(S,T,U,V)>
```

Given a `GuaranteedFuture` `s` of type `S` and a `GuaranteedFuture` `tu` of type `(T, U, V)`, `s • tu` is 
a `GuaranteedFuture` of type `(S, T, U, V)`.

```swift
func • <T,U>(t: Future<T>, u: GuaranteedFuture<U>) -> Future<(T, U)>
```

Given a `Future` `t` of type `T` and a `GuaranteedFuture` `u` of type `U`, `t • u` is a 
`Future` of type `(T, U)`. Since `t` may fail, the result type cannot be a `GuaranteedFuture`.
If `t` fails, the resulting `Future` will fail.

```swift
func • <T,U>(t: GuaranteedFuture<T>, u: Future<U>) -> Future<(T, U)>
```

Given a `GuaranteedFuture` `t` of type `T` and a `Future` `u` of type `U`, `t • u` is a 
`Future` of type `(T, U)`. Since `u` may fail, the result type cannot be a `GuaranteedFuture`.
If `u` fails, the resulting `Future` will fail.

**Applying functions to `GuaranteedFuture`s:**

```swift
func • <T,U>(f: @escaping (T) -> U, t: GuaranteedFuture<T>) -> GuaranteedFuture<U>
```

Given a function `f` that maps from type `T` to type `U`, and a `GuaranteedFuture` `t` of type `T`, 
`f • t` is a `GuaranteedFuture` of type `U`.

```swift
func • <T,U>(f: @escaping (T) throws -> U, t: GuaranteedFuture<T>) -> Future<U>
```

Given a function `f` that maps from type `T` to type `U`, and a `GuaranteedFuture` `t` of type `T`, 
`f • t` is a `Future` of type `U`. Since function `f` may throw, the result type cannot be
a `GuaranteedFuture`. If `f` throws, the resulting `Future` will fail.

```swift
func • <T,U>(f: @escaping (T) throws -> Future<U>, t: GuaranteedFuture<T>) -> Future<U>
```

Given a function `f` that maps from type `T` to a `Future ` of type `U`, and a `GuaranteedFuture` 
`t` of type `T`, `f • t` is a `Future` of type `U`. Since function `f` may throw, the result type
cannot be a `GuaranteedFuture`. If `f` throws, the resulting `Future` will fail.

**Applying a predicate to a `Future`:**

```swift
func •? <T>(p: @escaping (T) throws -> Bool, t: Future<T>) -> Future<T>
```

Given a predicate function `p` that tests whether a value of type `T` satisfies some criterion
(i.e., returns `true` if the criterion is satisfied) and a `Future` of type `T`, `p •? t` is a
`Future` of type `T` that will fail if the eventual result of type `T` does not satisfy the
predicate `p`. Function `f` may throw, in which case the resulting `Future` will fail. **Using
the `•?` operator can result in race conditions. See the note on invalidating callbacks below.**

**Flattening a nested `Future`:**

```swift
func flatten<T>(_ future: Future<Future<T>>) -> Future<T>
```

Given a `Future` `future` of type `Future<T>` (i.e., a future of a future), `flatten(future)`
is a `Future` of type `T`.

**Transforming a function to operate on arguments of type `Future`:**

```swift
func lift<S, T, U>(_ f: @escaping (S, T) throws -> U) -> (Future<S>, Future<T>) -> Future<U>
```

Given a function `f` that maps from type `(S, T)` to type `U`, `lift(f)` is a function that
maps from type `(Future<S>, Future<T>)` to a `Future` of type `U`. In other words, `lift` takes
a function whose arguments are not `Future`s and returns a function whose arguments are `Future`s.
Function `f` may throw, in which case the resulting `Future` will fail.

**Waiting for a `Future` to complete:**

```swift
func await<T>(_ future: Future<T>) throws -> T
```

Given a `Future` `future` of type `T`, `await(future)` halts the current thread until the `Future`
succeeds or fails. If the `Future` succeeds, the `Future`'s value of type `T` is returned. If the
`Future` fails, an error is thrown. As this function halts the current thread, extreme caution must
be used, and in general the use of this function is strongly discouraged outside of unit tests. In
particular, care should be taken not to call this function on a "special" thread, such as the main
thread in an iOS app. No attempt is made to ensure that this function is not called on the main 
thread.

**Reducing a `SequenceType` of `Future`s:**

From Foundation:
```swift
func reduce<T>(initial: T, @noescape combine: (T, Self.Generator.Element) throws -> T) rethrows -> T
```

To perform a reduce on a `SequenceType` of `Futures`, use `lift` along with `SequenceType`'s `reduce`
method (see the unit test examples).

**IMPORTANT:** The functions passed to the above methods will NOT be executed on the
main thread, so any side effects that require execution on the main thread (such as updates
to views) will cause problems. The `onSuccess` and `onError` methods run their callbacks on the 
main thread, and these are the appropriate ways in which to perform side effects that must be 
executed on the main thread.


## Invalidating callbacks (and avoiding race conditions):

It is not possible to explicitly remove or cancel a callback once it has been added.
However, it is a common use case that a callback should not be run if a certain
condition is met. For example, a callback that updates a reusable view should not be
run if the view has been reused, since the value provided by the `Future` would refer
to an outdated view. Here is the recommended way to model this scenario:

1. In the callback added using `onSuccess`, check that the condition is met.
2. Only use the `Future`'s value in the callback if the condition is met.

It is tempting to model the problem by transforming the `Future` using the `•?`
operator (using a predicate that tests if if the condition is met,) into a second `Future` 
and then adding a callback to the second `Future`. However, this approach is subject to a 
race condition that can result in the callback being called even if the predicate is false:

1. The first `Future` completes when the condition that the predicate tests is true.
2. The second `Future` therefore also completes.
3. The condition becomes false.
3. The second `Future`'s callbacks are run, even though the condition is false.

Neither approach described above cancel the operation that provides the `Future`
with its value (since other callbacks may need and legitimately be able to use the
value). Cancelling, pausing, resuming, and obtaining progress are deliberately out of the design
scope of FuturesKit. If you need to do these things, consider implementing the function that
provides the value to the `Future` using 
[Foundation's `Progress` class](https://developer.apple.com/reference/foundation/progress).
