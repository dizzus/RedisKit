# RedisKit

RedisKit is a asynchronious client framework for [Redis server](http://redis.io), written in Objective-C.

* It is based on the [Hiredis](https://github.com/redis/hiredis) library.
* It provides asynchronious API using [PromiseKit](https://github.com/dizzus/PromiseKit) framework.
* It comes with a comprehensive test suit modeled after [Redis commands list](http://redis.io/commands).

## Installation

There are a few different installation options:

* Embedded framework
* Add source code files to your project tree

### Embedded framework

Download source code and open provided XCode project. Issue Clean and Build commands. Run tests to make sure everything works as expected. 
You should now have RedisKit.framework in your "Products" folder. Right click on it and select "Show in Finder". Using Finder copy 
RedisKit.framework in some convenient place, e.g. your Desktop.

To add RedisKit to your project:

1. In your Project Navigator create a group named "Frameworks".
2. Right click on "Frameworks" group and select "Add files to 'YourProject'", then select RedisKit.framework from the place where you previously copied it to.
3. Select your project in Project Navigator and go to "Build Phases" section.
4. Press '+' and select "New Copy Files Phase".
5. Set "Destination" to "Frameworks" from the drop-down list.
6. Press '+' and select YourProject/Frameworks/RedisKit.framework in the dialog sheet.

You should now be able to to build your project with PromiseKit embedded in your app bundle.

To start working with PromiseKit import it in your source code:

```objective-c
#import <RedisKit/RedisKit.h>
```

### Add source code files to your project tree

If for some reason you don't want to embed PromiseKit you may:

1. Download RedisKit source code. Drag-and-drop file from the following folders:
2. **Promises** - PromiseKit framework files.
3. **HiRedis** - Redis client library files.
4. **RedisKit** - RedisKit framework files.

Make sure the "Copy items into destination group's folder (if needed)" checkbox is checked and you should be good to go.

To start working with PromiseKit import it in your source code:

```objective-c
#import "CocoaRedis.h"
```

## Basic Usage


### Connection:

RedisKit is a asyncronious framework. It uses promises to represent eventual server replies or errors.
First you create an object of *CocoaRedis* class which represents a connection to Redis server. 
Then you connect to server using one of the connect methods which return a promise object. Then you attach
your callbacks to that promise: 

```objective-c
// Create server connection object
CocoaRedis *redis = [CocoaRedis new];

// Connect to server. Host can alose be passed as "host:port".
[[redis connectWithHost:@"localhost"] onFulfill:^id(id value) {
    NSLog(@"Connected to server");
    return nil;
} onReject:^id(NSError *err) {
    NSLog(@"Connection error: %@", err);
    return nil;
}];
```
You can specify a nonstandard port in the host string, e.g: @"localhost:1234".

Another example. Connect to the given server host/port. Once connection is established issue VERSION command: 

```objective-c
// Create server connection object
CocoaRedis *redis = [CocoaRedis new];

// Connect to server
[[[[redis connectWithHost:@"localhost" port:6379] then:^id(id value) {
    return [redis version];
}] then:^id(id value) {
    NSLog(@"Server version: %@", value);
    return nil;
}] catch:^id(NSError *err) {
    NSLog(@"Error: %@", err);
    return nil;
}];
```

### Executing commands:

Since RedisKit is an asyncronious framework your basic workflow looks like this:

1. Create connection object. Use one of the connect methods.
2. Use promise chaining to issue commands and proccess server replies. 

```objective-c
CocoaRedis* redis = [CocoaRedis new];

[[[[[redis connectWithHost:@"localhost"] then:^id(id value) {
    NSLog(@"Connected.");
    return [redis set: @"MyKey" value: @"Hello World"];
}] then:^id(id value) {
    return [redis get: @"MyKey"];
}] then:^id(id value) {
    NSAssert([value isEqualToString:@"Hello World"], @"Invalid value");
    return nil;
}] catch:^id(NSError *err) {
    NSLog(@"Error: %@", err);
    return nil;
}];
```

There are two ways to execute redis commands. 

1. Use #command: or #command:arguments: methods to execute any redis command, consider this example:

```objective-c
CocoaRedis* redis = [CocoaRedis new];
[[redis connectWithHost:@"localhost"] then:^id(id value) {
    return [redis command: @[@"SET", @"MyKey", @"Hello World"]];
}];
```

Redis command and it's arguments are being passed as an array. RedisKit supports the following types:

*NSString* - to pass UTF-8 encoded strings.  
*NSNumber* - to pass numbers, either integer or double.  
*NSData* - to pass binary data.

There's a convenient version of this command:

```objective-c
CocoaRedis* redis = [CocoaRedis new];
[[redis connectWithHost:@"localhost"] then:^id(id value) {
    NSArray* keys = @[@"Key1", @"Key2", @"Key3"];
    return [self command:@[@"BITOP", @"AND", @"MyKey"] arguments:keys];	
}];
```

2. Use one of the **CocoaRedis** methods. RedisKit implements almost all of the redis command set, adding
a couple of convenient methods. Please refer to *CocoaRedis.h* header file to see the full list of implemented commands.

## Getting replies from server:

Every RedisKit command returns a promise object of class *CocoaPromise* which represents the result of an asyncronious command. The result could be a value or an error. Please refer to [CocoaRedis](https://github.com/dizzus/PromiseKit) documentation if you need additional information. To handle the server reply you attach callbacks to the promise object and use chaining to execute a sequence of asyncronious commands:

```objective-c
CocoaRedis* redis = [CocoaRedis new];

// Connect to localhost
[[[[[redis connectWithHost:@"localhost"] then:^id(id value) {
    // Once connected set key to some value
    return [redis set: @"MyKey" value: @"Hello World"];
}] then:^id(id value) {
    // Set command should return "OK" reply
    NSAssert([value isEqualToString:@"OK"], @"Set error");
    // Get key value
    return [redis get: @"MyKey"];
}] then:^id(id value) {
    // Should be the same value as we've set it before.
    NSAssert([value isEqualToString:@"Hello World"], @"Invalid value");
    return nil;
}] catch:^id(NSError *err) {
    // Catch any errors
    NSLog(@"Error: %@", err);
    return nil;
}];
```

RedisKit transforms server replies into convenient Cocoa objects according to the following rules:

| Redis reply:     | Cocoa class:           |
|------------------|------------------------|
| Simple string    | NSString               |
| Multibulk string | NSString or NSData ( read below)   |
| Errors           | NSError                |
| Integer          | NSNumber               |
| Array            | NSArray                |
| Nil              | NSNull                 |

Multibulk case is special. Since most of the data stored in Redis server is usualy in a text form,
RedisKit tries to decode multibulk strings into NSString using UTF-8 encoding. If it fails to do so
it returns server reply as a binary data using NSData object.

### Binary safety:

Redis server is binary safe in the sense that both keys and values can contain non-ASCII values (e.g \x0 bytes). RedisKit supports this feature automatically. If you want to use a binary key - pass NSData object instead of NSString. Use NSData objects to send binary data to server in any command where it's applicable.

```objective-c 

	const char* binKey = "\x00\xC0\xFF\xEE";
	const char* binValue = "\xFF\x0F\xFF\x00";

    NSData* key = [NSData dataWithBytes:binKey length:4];
    
    CocoaRedis* redis = [CocoaRedis new];
    
    [[[[redis connectWithHost: @"localhost"] then:^id(id value) {
        return [redis set: key value: [NSData dataWithBytes:binValue length:4]];
    }] then:^id(id value) {
        NSAssert([value isEqualToString:@"OK"], @"Set error");
        return [redis get: key];
    }] then:^id(id value) {
        const char* bytes = NULL;
        
        if( [value isKindOfClass:[NSData class]] ) {
            bytes = [(NSData*)value bytes];
        } else
        
        if( [value isKindOfClass:[NSString class]] ) {
            NSData* data = [(NSString*)value dataUsingEncoding:NSUTF8StringEncoding];
            bytes = data.bytes;
        }
        
        NSAssert(bytes != NULL, @"Invalid reply");
        NSAssert(memcmp(binValue, bytes, 4) == 0, @"Invalid binary data");

        return [redis quit];
    }];
```

Since some binary data can be represented as a valid UTF-8 sequence it's necessary to check for return
value's class when working with binary data. You don't have to do those checks if you know that you're 
working with text data. By default RedisKit return multibulk strings as UTF-8 encoded NSStrings (read
section "Getting replies from server").


## Publish/Subscribe:

Redis server provides support for so called [Publish/Subscribe paradigm](http://redis.io/topics/pubsub).
RedisKit implements this idiom by using [NSNotificationCenter](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSNotificationCenter_Class/). One important thing to keep in mind when using pub/sub mechanism is this: once the client enters the subscribed state it is not supposed to issue any other commands, except for additional subscribe and unsubscribe commands. 

### Publishing:
```objective-c
    CocoaRedis* redis = [CocoaRedis new];
    
    [[[redis connectWithHost:@"localhost"] then:^id(id value) {
        return [redis publish:@"MyChannel" message:@"Hello World"];
    }] then:^id(id value) {
        NSLog(@"Number of subscribers that received the message: %@", value);
        return [redis quit];
    }];
```

### Subscribing:
Redis supports two subscribe modes:

1. [Pattern subscribe](http://redis.io/commands/psubscribe): Client specifies a glob-style pattern of channels he's interested in. Any data that gets published into a channel that matches given pattern is forwarded to such client. To use pattern subscribe in RedisKit you do:
```objective-c
    CocoaRedis* redis = [CocoaRedis new];
    
    [[[redis connectWithHost:@"localhost"] then:^id(id value) {
        return [redis psubscribe:@"Hello.*"];
    }] then:^id(id value) {
        NSLog(@"Subscribed: %@", value);
        return [redis quit];
    }];
```

 #psubscribe: method returns a *NSDictionary* with the following keys:
- @"count" - the number of subscribed clients
- @"pattern" - the patter which we've been subscribed to

2. [Subscribe](http://redis.io/commands/subscribe) to the given channel:
```objective-c
    CocoaRedis* redis = [CocoaRedis new];
    
    [[[redis connectWithHost:@"localhost"] then:^id(id value) {
        return [redis subscribe:@"Hello"];
    }] then:^id(id value) {
        NSLog(@"Sub: %@", value);
        return [redis quit];
    }];
```

 #subscribe: method returns a *NSDictionary* with the following keys:
- @"count" - the number of subscribed clients
- @"channel" - the channel which we've been subscribed to


### Receiving subcribtion data:

Once you've subscribed to a channel use NSNotification center to receive published data:

```objective-c
    CocoaRedis* redis = [CocoaRedis new];
    __block int helloCount = 0;
    
    [[[redis connectWithHost:@"localhost"] then:^id(id value) {
        return [redis subscribe:@"Hello"];
    }] then:^id(id value) {
		// Add out observer to notification center
		NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        observer = [center addObserverForName: CocoaRedisMessageNotification
                                       object: nil
                                        queue: nil
                                   usingBlock: ^(NSNotification *notification)
                    {
                    	// Get published message from the notification object.
                        NSString* message = notification.userInfo[@"message"];
                        if( [message isEqualToString:@"Hello"] ) ++helloCount;
                    }];
    }];
```

Add your observer to NSNotificationCenter for **CocoaRedisMessageNotification** notification name.
RedisKit passes published message and some additional information via *userInfo* dictionary.

1. Messages triggered by pattern subcribtion are represented as *NSDictionary* with keys:
- @"message" - Message data itself.
- @"channel" - channel that where the message had been publushed into.
- @"pattern" - channel pattern that triggered the subscribtion.

2. Messages triggered by simple subscribtions are represented as *NSDictionary* with keys:
- @"message" - Message data itself.
- @"channel" - channel that where the message had been publushed into.

### Unsubscribing:

To usubscribe use either #punsubscribe or #unsubscribe method. Also don't forget to remove your observer from the NSNotification center.

```objective-c
    CocoaRedis* redis = [CocoaRedis new];
    __block id observer = nil;
    
    [[[redis connectWithHost:@"localhost"] then:^id(id value) {
        return [redis subscribe:@"Hello"];
    }] then:^id(id value) {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        observer = [center addObserverForName: CocoaRedisMessageNotification
                                       object: nil
                                        queue: nil
                                   usingBlock: ^(NSNotification *notification)
                    {
                        NSString* message = notification.userInfo[@"message"];

                        if( [message isEqualTo:@"Goodbye"] ) {
                        	// Unsubscribe from all channels
                            [[redis unsubscribe] then:^id(id value) {
                            	// Remove our observer and disconnect from Redis server.
                                [[NSNotificationCenter defaultCenter] removeObserver: observer];
                                return [redis quit];
                            }];
                        }
                    }];
        
        return nil;
    }];
````

## Monitoring

Redis server has [MONITOR](http://redis.io/commands/monitor) command which allows you observe every command which is being processed on the server. This is a great debugging tool and should be used as such because it adds a noticable impact on performace. RedisKit supports this feature using *NSNotificationCenter*:

```objective-c
    __block int pingCount = 0;
    __block id observer = nil;

    CocoaRedis* redis = [CocoaRedis new];

    [[[redis connectWithHost: @"localhost"] then:^id(id value) {
        return [redis monitor];
    }] then:^id(id value) {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        observer = [center addObserverForName: CocoaRedisMonitorNotification
                                       object: nil
                                        queue: nil
                                   usingBlock: ^(NSNotification *notification)
                    {
                        NSString* command = notification.userInfo[@"command"];
                        if( [command isEqualToString:@"PING"] ) ++pingCount;
                    }];
        
        return nil;
    }];
```

Add your observer to NSNotificationCenter for **CocoaRedisMonitorNotification** notification name. RedisKit passes monitoring information via *userInfo* dictionary:

- @"time" - Timestamp when the event occured (as *NSDate* object).
- @"db" - Database number.
- @"address - Client host:port 
- @"command" - Command
- @"arguments" - Command argument, if any.


## Important note on promises

* All callbacks, attached to promise objects, are executed on a private serial queue. If you need to run your callback on some specific queue, you should
use [dispatch_async()](https://developer.apple.com/library/ios/documentation/Performance/Reference/GCD_libdispatch_Ref/#//apple_ref/c/func/dispatch_async) function.

* The callbacks which you attach to a promise **must** return a value. If you forget to do so, most likely your're going to get **EXC_BAD_ACCESS** exception inside the CocoaPromise *onFulfill:onReject:* method.

For example:

```objective-c
    CocoaRedis* redis = [CocoaRedis new];

    [[[redis connectWithHost: @"localhost"] then:^id(id value) {
        NSLog(@"Connected");
        // Forgot to return a value
    }] then:^id(id value) {
        return [redis quit];
    }];
```

XCode should've noticed that callback doesn't return value, but for some reason it doesn't always do so. 
Running that example will get you an EXC_BAD_ACCESS exception. Because there's no return statement in the
callback the compiled code is going to pickup whatever random value happens to be on the stack/CPU register at the time the callback finishes, which will in turn lead to general protection fault.

## What to read

* [Redis server official website](http://redis.io)
* [Redis server command list](http://redis.io/commands)
* [PromiseKit promises framework](https://github.com/dizzus/PromiseKit)
* [Hiredis minimalistic C client library for the Redis database](https://github.com/redis/hiredis)


## Contact

Dmitry Bakhvalov

- https://github.com/dizzus
- dizzus@gmail.com

## License

PromiseKit is available under the MIT license. See the LICENSE file for more info.





