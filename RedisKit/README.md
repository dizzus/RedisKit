# PromiseKit

PromiseKit is a very lightweight and simple implementation of [Promises/A+ spec](https://github.com/promises-aplus/promises-spec) in Objective-C.

* It consists of two Objective-C files and has no external dependencies. 
* It uses GCD and hence should work on MacOS X 10.7+ and iOS 5.0+.
* It comes with a comprehensive test suit modeled after Promises/A+ specs.

## Installation

There are a few different installation options:

* Embedded framework
* Add source code files to your project tree

### Embedded framework

Download source code and open provided XCode project. Issue Clean and Build commands. Run tests to make sure everything works as expected. 
You should now have PromiseKit.framework in your "Products" folder. Right click on it and select "Show in Finder". Using Finder copy 
PromiseKit.framework in some convenient place, e.g. your Desktop.

To add PromiseKit to your project:

1. In your Project Navigator create a group named "Frameworks".
2. Right click on "Frameworks" group and select "Add files to 'YourProject'", then select PromiseKit.framework from the place where 
you previously copied it to.
3. Select your project in Project Navigator and go to "Build Phases" section.
4. Press '+' and select "New Copy Files Phase".
5. Set "Destination" to "Frameworks" from the drop-down list.
6. Press '+' and select YourProject/Frameworks/PromiseKit.framework in the dialog sheet.

You should now be able to to build your project with PromiseKit embedded in your app bundle.

To start working with PromiseKit import it in your source code:

```objective-c
#import <PromiseKit/PromiseKit.h>
```

### Add source code files to your project tree

If for some reason you don't want to embed PromiseKit you may:

1. Download PromiseKit source code.
2. Add files **CocoaPromise.h** and **CocoaPromise.m** to your project source tree. Simply drag-n-drop them into your project.
Make sure the "Copy items into destination group's folder (if needed)" checkbox is checked and you should be good to go.

To start working with PromiseKit import it in your source code:

```objective-c
#import "CocoaPromise.h"
```

## Basic Usage

```objective-c
// Create promise object
CocoaPromise *promise = [CocoaPromise new];

// Attach callbacks to promise
[promise onFulfill:^id(id value) {
    // This code runs when promise is fulfilled
} onReject: ^id(NSError* err) {
    // This code runs when promise is rejected
}];

// To fulfill promise 
[promise fulfill: @"Hello, world"];

// To reject promise 
[promise reject: [NSError errorWithDomain:@"Some error" code:0 userInfo:nil]];
```

There's a convenient method to attach a callback to promise when you don't care for errors.

```objective-c
CocoaPromise* promise = [CocoaPromise new];

[promise then: ^id(id value) {
    // This code runs when promise is fulfilled
}];

```

There's also a method to attach a callback when you're interested only in errors:

```objective-c
CocoaPromise* promise = [CocoaPromise new];

[promise catch: ^id(NSError* err) {
    // This code runs when promise is rejected
}];

```

## Chaining

The real power of promises comes from the ability to chain them together. Each of these methods:

* onFulfilled:onRejected:
* then:
* catch:

return a new promise. The return value from your callback is passed to that newly created promise, consider this:

```objective-c
CocoaPromise* p = [CocoaPromise new];

[[p then:^id(id value) {
    NSLog(@"Value #1: %@", value);
    return @"Hello, world";
}] then:^id(id value) {
    NSLog(@"Value #2: %@", value);
    return nil;
}];

[p fulfill: @42];
```

Once promise *p* is fulfilled with value *42* the first callback gets called with this value. The *then:* method returns
a new promise which we attach our second callback to. The return value "Hello, world" thus becomes the fulfillment value of
that second promise. This technique allows us to pass values from one async callback to another avoiding the infamous callback Pyramid of Doom.

If your callback returns *NSError* or *@throw* an NSError this automatically rejects the chained promise.
Consider this example:

```objective-c
CocoaPromise* p = [CocoaPromise new];

[[[p then:^id(id value) {
    NSLog(@"Value #1: %@", value);
    return [NSError errorWithDomain:@"Some error" code:0 userInfo:nil];
}] then:^id(id value) {
    NSLog(@"Value #2: %@", value);
    return nil;
}] catch: ^id(NSError* err) {
	NSLog(@"Error: %@", err);
    return nil;
}];

[p fulfill: @42];
```

What happens here is that promise *p* gets fulfilled with value *42* which is passed on to the first 
callback. The first callback returns an *NSError* which rejects the second chained promise. Since the second chained promise doesn't have *onRejected:* callback attached this moves the promise to rejected state, which
in turn triggers the *catch:* method on the third chained promise.

It is possible to recover from errors by returing a non-error object from *catch:* method:

```objective-c
CocoaPromise* p = [CocoaPromise new];

[[[p then: ^id(id value) {
	// Should not get here.
}] catch: ^id(NSError* err) {
	NSLog(@"Error: %@, returning default value", err);
    return @"Hello, world!";
}] then: ^id(id value) {
	NSLog(@"Value: %@", value);
}];

[p reject: [NSError errorWithDomain:@"Some error" code:0 userInfo:nil]];
```
In this example we reject a promise with error, which triggers our catch: callback. We return a string from that callback which in turn gets passed to next chained promise.


You can fulfill promise with another promise. It is also possible to return promise from a callback.

```objective-c
CocoaPromise* p1 = [CocoaPromise new];

[[p1 then: ^id(id value) {
	NSLog(@"Value #1: %@", value);
    CocoaPromise* p2 = [CocoaPromise new];
    
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW,(int64_t)(3 * NSEC_PER_SEC));
    dispatch_after(time, dispatch_get_main_queue(), ^{
    	[p2 fulfill: @"Hello, world!";
	});
    
    return p2;
}] then: ^id(id value) {
	NSLog(@"Value #2: %@", value);
}];

[p1 fulfill: @42];
```
In this example we fulfill the first promise with value 42 and return another promise from our first callback.
After 3 seconds the second promise is going to be fullfilled, which in turn is going to trigger our second callback
with value "Hello, world!".

Check out test suit that comes with PromiseKit to see more examples.

## Important note on callbacks

* All callbacks are executed on a private serial queue. If you need to run your callback on some specific queue, you should
use [dispatch_async()](https://developer.apple.com/library/ios/documentation/Performance/Reference/GCD_libdispatch_Ref/#//apple_ref/c/func/dispatch_async) function.


* The callbacks which you attach to a promise **must** return a value. If you forget to do so, most likely your're going to get **EXC_BAD_ACCESS** exception inside the CocoaPromise *onFulfill:onReject:* method.

For example:

```objective-c
CocoaPromise* p = [CococaPromise new];
[p then: ^id(id value) {
	NSLog(@"Value: %@", value);
    // Forgot to return a value
}];
[p fulfill: @42];

```

XCode should've noticed that callback doesn't return value, but for some reason it doesn't always do so. 
Running that example will get you an EXC_BAD_ACCESS exception. Because there's no return statement in the
callback the compiled code is going to pickup whatever random value happens to be on the stack/CPU register at the time the callback finishes, which will in turn lead to general protection fault.

## What to read

* [Promises/A+ specification](https://promisesaplus.com)


## Contact

Dmitry Bakhvalov

- https://github.com/dizzus
- dizzus@gmail.com

## License

PromiseKit is available under the MIT license. See the LICENSE file for more info.

