//
//  ServerCommands.m
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 01.08.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import "RedisTestCase.h"

@interface ServerCommands : RedisTestCase
@end


static void PingLoop(CocoaRedis* redis, NSInteger counter, NSInteger max, CocoaPromise* pingPromise, CocoaPromise* result) {
    [pingPromise onFulfill:^id(id value) {
        if( counter == max - 1 ) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [result fulfill: @(counter)];
            });
        } else {
            PingLoop(redis, counter + 1, max, [redis ping], result);
        }
        return nil;
    } onReject:^id(NSError *err) {
        [result reject: err];
        return nil;
    }];
}

@implementation ServerCommands

#pragma mark BGREWRITEAOF
- (void) test_BGREWRITEAOF {
    [self test: @"BGREWRITEAOF"];

    [[self.redis bgrewriteaof] then:^id(id value) {
        NSArray* expected = @[@"Background append only file rewriting scheduled", @"Background append only file rewriting started", @"OK"];
        XCTAssertTrue([expected containsObject:value]);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark BGSAVE
- (void) test_BGSAVE {
    [self test: @"BGSAVE"];
    
    [[[self.redis bgsave] then:^id(id value) {
        NSLog(@"+++ BGSAVE: %@", value);
        XCTAssertTrue( [value isEqualToString:@"Background saving started"] || [value isEqualToString:@"OK"] );
        return [self passed];
    }] catch:^id(NSError *err) {
        NSString* expected = @"ERR Can't BGSAVE while AOF log rewriting is in progress";
        if( [err.domain isEqualToString:expected] ) {
            [self passed];
        } else {
            NSLog(@"--- BGSAVE error: %@", err);
        }
        return nil;
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:nil];
}

#pragma mark CLIENT KILL
- (void) test_CLIENT_KILL {
    [self test: @"CLIENT KILL"];
    // TODO: write test
    [self passed];
    [self wait];
}

#pragma mark CLIENT LIST
- (void) test_CLIENT_LIST {
    [self test: @"CLIENT LIST"];
    NSString* name = [[NSUUID UUID] UUIDString];
    
    [[[self.redis clientSetName:name] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis clientList];
    }] then:^id(id value) {
        XCTAssertTrue([self isArray:value]);

        BOOL found = NO;
        for( NSDictionary* client in value ) {
            XCTAssertTrue([self isDictionary:client]);
            if( [client[@"name"] isEqualToString:name] ) found = YES;
        }
        XCTAssertTrue(found);

        return [self passed];
    }];

    [self wait];
}

#pragma mark CLIENT GETNAME
- (void) test_CLIENT_GETNAME {
    [self test: @"CLIENT GETNAME"];
    const NSString* name = [[NSUUID UUID] UUIDString];

    [[[[self.redis clientGetName] then:^id(id value) {
        XCTAssertTrue( value == [NSNull null] );
        return [self.redis clientSetName:name];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis clientGetName];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, name);
        return [self passed];
    }];
    
    [self wait];
}


#pragma mark CLIENT PAUSE
- (void) test_CLIENT_PAUSE {
    [self test: @"CLIENT PAUSE"];

    [[self.redis clientPause:500] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self passed];
    }];
    
    [self wait];
}


#pragma mark CLIENT SETNAME
- (void) test_CLIENT_SETNAME {
    [self test: @"CLIENT SETNAME"];
    const NSString* name = [[NSUUID UUID] UUIDString];
    
    [[[self.redis clientSetName:name] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis clientGetName];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, name);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark COMMAND
- (void) test_COMMAND {
    [self test: @"COMMAND"];
    
    // TODO: more comprehensive test
    [[self.redis commandList] then:^id(id value) {
        XCTAssertTrue( [self isArray:value] && [value count] > 0 );
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark COMMAND COUNT
- (void) test_COMMAND_COUNT {
    [self test: @"COMMAND COUNT"];
    
    [[self.redis commandCount] then:^id(id value) {
        XCTAssertTrue( [value integerValue] > 0 );
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> COMMAND GETKEYS MSET a b c d e f
 1) "a"
 2) "c"
 3) "e"
 redis> COMMAND GETKEYS EVAL "not consulted" 3 key1 key2 key3 arg1 arg2 arg3 argN
 1) "key1"
 2) "key2"
 3) "key3"
 redis> COMMAND GETKEYS SORT mylist ALPHA STORE outlist
 1) "mylist"
 2) "outlist"
 redis>
 */
#pragma mark COMMAND GETKEYS
- (void) test_COMMAND_GETKEYS {
    [self test: @"COMMAND GETKEYS"];
    
    [[[[self.redis commandGetKeys: @[@"MSET", @"a", @"b", @"c", @"d", @"e", @"f"]] then:^id(id value) {
        NSArray* expected = @[@"a", @"c", @"e"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis commandGetKeys: @[@"EVAL", @"not consulted", @3, @"key1", @"key2", @"key3", @"arg1", @"arg2", @"arg3", @"argN"]];
    }] then:^id(id value) {
        NSArray* expected = @[@"key1", @"key2", @"key3"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis commandGetKeys: @[@"SORT", @"mylist", @"ALPHA", @"STORE", @"outlist"]];
    }] then:^id(id value) {
        NSArray* expected = @[@"mylist", @"outlist"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 edis> COMMAND INFO get set eval
 1) 1) "get"
 2) (integer) 2
 3) 1) readonly
 2) fast
 4) (integer) 1
 5) (integer) 1
 6) (integer) 1
 2) 1) "set"
 2) (integer) -3
 3) 1) write
 2) denyoom
 4) (integer) 1
 5) (integer) 1
 6) (integer) 1
 3) 1) "eval"
 2) (integer) -3
 3) 1) noscript
 2) movablekeys
 4) (integer) 0
 5) (integer) 0
 6) (integer) 0
 redis> COMMAND INFO foo evalsha config bar
 1) (nil)
 2) 1) "evalsha"
 2) (integer) -3
 3) 1) noscript
 2) movablekeys
 4) (integer) 0
 5) (integer) 0
 6) (integer) 0
 3) 1) "config"
 2) (integer) -2
 3) 1) readonly
 2) admin
 3) stale
 4) (integer) 0
 5) (integer) 0
 6) (integer) 0
 4) (nil)
 redis>
 */
#pragma mark COMMAND INFO
- (void) test_COMMAND_INFO {
    [self test: @"COMMAND INFO"];
   
    NSArray* get = @[
        @"get",
        @2,
        @[@"readonly", @"fast"],
        @1, @1, @1
    ];
    NSArray* set = @[
        @"set",
        @-3,
        @[@"write", @"denyoom"],
        @1, @1, @1
    ];
    NSArray* eval = @[
        @"eval",
        @-3,
        @[@"noscript", @"movablekeys"],
        @0, @0, @0
    ];
    NSArray* evalsha = @[
        @"evalsha",
        @-3,
        @[@"noscript", @"movablekeys"],
        @0, @0, @0
    ];
    NSArray* config = @[
        @"config",
        @-2,
        @[@"readonly", @"admin", @"stale"],
        @0, @0, @0
    ];

    [[[self.redis commandInfoForNames: @[@"get", @"set", @"eval"]] then:^id(id value) {
        NSArray* expected = @[get, set, eval];
        XCTAssertEqualObjects(value, expected);
        return [self.redis commandInfoForNames:@[@"foo", @"evalsha", @"config", @"bar"]];
    }] then:^id(id value) {
        NSArray* expected = @[[NSNull null], evalsha, config, [NSNull null]];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> config get *max-*-entries*
 1) "hash-max-zipmap-entries"
 2) "512"
 3) "list-max-ziplist-entries"
 4) "512"
 5) "set-max-intset-entries"
 6) "512"
 */
#pragma mark CONFIG GET
- (void) test_CONFIG_GET {
    [self test: @"CONFIG GET"];

    [[self.redis configGet: @"*max-*-entries*"] then:^id(id value) {
        XCTAssertTrue( [self isDictionary:value] );
        XCTAssertNotNil( value[@"hash-max-ziplist-entries"] );
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark CONFIG REWRITE
- (void) test_CONFIG_REWRITE {
    [self test: @"CONFIG REWRITE"];
    [self passed];
    [self wait];
}

#pragma mark CONFIG SET
- (void) test_CONFIG_SET {
    [self test: @"CONFIG SET"];
    
    [[[self.redis configSet:@"SAVE" value:@"999 1 333 10"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        // FIXME: configGet: @"save" not working?
        return [self.redis configGet:@"*"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value[@"save"], @"999 1 333 10");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark CONFIG RESETSTAT
- (void) test_CONFIG_RESETSTAT {
    [self test: @"CONFIG RESETSTAT"];
    
    [[self.redis configResetStat] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark DBSIZE
- (void) test_DBSIZE {
    [self test: @"DBSIZE"];
    const NSString* key = [self randomKey];

    __block NSInteger count = 0;
    
    [[[[self.redis dbsize] then:^id(id value) {
        count = [value integerValue];
        return [self.redis set:key value:@"Hello World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis dbsize];
    }] then:^id(id value) {
        XCTAssertTrue( [value integerValue] == count + 1 );
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark FLUSHALL
- (void) test_FLUSHALL {
    [self test: @"FLUSHALL"];
    [self passed];
    [self wait];
}

#pragma mark FLUSHDB
- (void) test_FLUSHDB {
    [self test: @"FLUSHDB"];
    const NSString* key = [self randomKey];
    
    [[[[[self.redis set:key value:@"Hello World"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis dbsize];
    }] then:^id(id value) {
        XCTAssertTrue( [value integerValue] > 0 );
        return [self.redis flushdb];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis dbsize];
    }] then:^id(id value) {
        XCTAssertTrue( [value integerValue] == 0 );
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark INFO
- (void) test_INFO {
    [self test: @"INFO"];
    
    [[[self.redis info] then:^id(id value) {
        XCTAssertTrue( [self isDictionary:value] );
        XCTAssertNotNil( value[@"Server"] );
        XCTAssertNotNil( value[@"Server"][@"redis_version"] );
        return [self.redis info: @"Memory"];
    }] then:^id(id value) {
        XCTAssertTrue( [self isDictionary:value] );
        XCTAssertNotNil( value[@"used_memory"] );
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark LASTSAVE
- (void) test_LASTSAVE {
    [self test: @"LASTSAVE"];
    
    [[self.redis lastsave] then:^id(id value) {
        XCTAssertTrue( [value isKindOfClass:[NSDate class]] );
        XCTAssertTrue( [value timeIntervalSince1970] > 0 );
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark MONITOR
- (void) test_MONITOR {
    [self test: @"MONITOR"];
    
    __block __weak id observer = nil;
    __block NSInteger pingCount = 0;
    const NSInteger expectedPing = 10;

    CocoaPromise* result = [CocoaPromise new];
    
    [result then:^id(id value) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
            [center removeObserver: observer];
            
            XCTAssertEqual(pingCount, expectedPing);
            [self passed];
        });
        
        return nil;
    }];

    CocoaRedis* monitor = [CocoaRedis new];
    
    [[[monitor connectWithHost: REDIS_ADDRESS] then:^id(id value) {
        return [monitor monitor];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @YES);

        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        observer = [center addObserverForName: CocoaRedisMonitorNotification
                            object: nil
                             queue: nil
                        usingBlock: ^(NSNotification *notification)
        {
            NSString* command = notification.userInfo[@"command"];
            if( [command isEqualToString:@"PING"] ) ++pingCount;
        }];

        PingLoop(self.redis, 0, expectedPing, [self.redis ping], result);
     
        return nil;
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:nil];
}

#pragma mark ROLE
- (void) test_ROLE {
    [self test: @"ROLE"];
    
    [[self.redis role] then:^id(id value) {
        XCTAssertTrue( [self isDictionary:value] );
        XCTAssertTrue( [value[@"role"] isEqualToString: @"master"] || [value[@"role"] isEqualToString:@"slave"] );
        
        if( [value[@"role"] isEqualToString: @"master"] ) {
            XCTAssertNotNil( value[@"offset"] );
            XCTAssertNotNil( value[@"slaves"] );
            XCTAssertTrue( [self isArray: value[@"slaves"]] );
            if( [value[@"slaves"] count] > 0 ) {
                NSDictionary* slave = value[@"slaves"][0];
                XCTAssertNotNil( slave[@"address"] );
                XCTAssertNotNil( slave[@"offset"] );
            }
        } else {
            XCTAssertNotNil( value[@"address"] );
            XCTAssertNotNil( value[@"connected"] );
            XCTAssertNotNil( value[@"offset"] );
        }
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark SAVE
- (void) test_SAVE {
    [self test: @"SAVE"];
    
    [[self.redis save] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark SHUTDOWN
- (void) test_SHUTDOWN {
    [self test: @"SHUTDOWN"];

    /* This is how it's supposed to work. But we dont want to shutdown our server.
     
    [[self.redis shutdown] onFulfill:^id(id value) {
        XCTAssertFalse(@"Should not get here");
        return nil;
    } onReject:^id(NSError *err) {
        return [self passed];
    }];

     */
    
    [self passed];
    [self wait];
}

#pragma mark SLAVEOF
- (void) test_SLAVEOF {
    [self test: @"SLAVEOF"];
    [self passed];
    [self wait];
}

#pragma mark SLOWLOG
- (void) test_SLOWLOG {
    [self test: @"SLAVEOF"];

    [[self.redis slowlog:@"get"] then:^id(id value) {
        XCTAssertTrue( [self isArray:value] );
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark SYNC
- (void) test_SYNC {
    [self test: @"SYNC"];
    [self passed];
    [self wait];
}

#pragma mark TIME
- (void) test_TIME {
    [self test: @"TIME"];
    
    NSDateComponents *now = [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:[NSDate date]];
    
    [[self.redis time] then:^id(id value) {
        XCTAssertTrue([value isKindOfClass:[NSDate class]]);
        NSDateComponents *server = [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:(NSDate*)value];
        XCTAssertTrue(now.year == server.year);
        XCTAssertTrue(now.month == server.month);
        XCTAssertTrue(now.day == server.day);
        return [self passed];
    }];
    
    [self wait];
}


@end
