//
//  KeysCommands.m
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 26.07.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import "RedisTestCase.h"

@interface KeysCommands : RedisTestCase
@end

@implementation KeysCommands

#pragma mark DEL
- (void) test_DEL {
    [self test: @"DEL"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];

    [[
    [[self.redis set:key1 value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis set:key2 value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis delKeys: @[key1, key2, @"nonexisting"]];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark DUMP
- (void) test_DUMP {
    [self test: @"DUMP"];
    const NSString* key = [self randomKey];
    
    [
    [[self.redis set: key value: @10] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis dump:key];
    }] then:^id(id value) {
        /* FIXME */
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark EXISTS
- (void) test_EXISTS {
    [self test: @"EXISTS"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    
    [[[[
    [[self.redis set:key1 value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis exists:key1];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis exists: @"nosuchkey"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self.redis set:key2 value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        // FIXME
        // Available from >= 3.0.3
        // return [self.redis existsKeys: @[key1, key2, @"nosuchkey"]];
        return @2;
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark EXPIRE
- (void) test_EXPIRE {
    [self test: @"EXPIRE"];
    const NSString* key = [self randomKey];
    
    [[[[
    [[self.redis set:key value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis expire:key seconds:10];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis ttl:key];
    }] then:^id(id value) {
        XCTAssertTrue( [value integerValue] <= 10 );
        return [self.redis set:key value:@"Hello World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis ttl:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @-1);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark EXPIREAT
- (void) test_EXPIREAT {
    [self test: @"EXPIREAT"];
    const NSString* key = [self randomKey];

    [[[
    [[self.redis set:key value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis exists:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis expireat:key timestamp:1293840000];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis exists:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark KEYS
- (void) test_KEYS {
    [self test: @"KEYS"];

    [[[[[self.redis mset: @[@"one", @1, @"two", @2, @"three", @3, @"four", @4]] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis keys: @"*o*"];
    }] then:^id(id value) {
        NSArray* expected = @[@"two", @"four", @"one"];
        XCTAssertEqualObjects([NSSet setWithArray: value], [NSSet setWithArray: expected]);
        return [self.redis keys:@"t??"];
    }] then:^id(id value) {
        NSArray* expected = @[@"two"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis keys:@"*"];
    }] then:^id(id value) {
        NSArray* expected = @[@"two", @"three", @"four", @"one"];
        XCTAssertEqualObjects([NSSet setWithArray: value], [NSSet setWithArray: expected]);
        return [self passed];
    }];
    
    [self wait];
}

/* MIGRATE: need two servers to test */

#pragma mark MOVE
- (void) test_MOVE {
    [self test: @"MOVE"];

    const NSString* key = [self randomKey];
    
    [[[[[self.redis set: key value: @"Hello World"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis move:key db:14];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis select:14];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis get:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"Hello World");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark OBJECT
- (void) test_OBJECT {
    [self test: @"OBJECT"];
    const NSString* key = [self randomKey];
    
    [[[
    [[self.redis lpush:key value:@"Hello World"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis object:@"refcount" key:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis object:@"encoding" key:key];
    }] then:^id(id value) {
        XCTAssertTrue( [value isEqualToString:@"ziplist"] || [value isEqualToString:@"quicklist"] );
        return [self.redis object:@"idletime" key:key];
    }] then:^id(id value) {
        XCTAssertTrue( [value integerValue] >= 0 );
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark PERSIST
- (void) test_PERSIST {
    [self test: @"PERSIST"];
    const NSString* key = [self randomKey];
    
    [[[[
    [[self.redis set:key value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis expire:key seconds:10];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis ttl:key];
    }] then:^id(id value) {
        XCTAssertTrue([value integerValue] <= 10);
        return [self.redis persist:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis ttl:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @-1);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark PEXPIRE
- (void) test_PEXPIRE {
    [self test: @"PEXPIRE"];
    const NSString* key = [self randomKey];

    [[[
    [[self.redis set:key value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis pexpire:key milliseconds:1500];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis ttl:key];
    }] then:^id(id value) {
        long t = [value longValue];
        XCTAssertTrue( t >= 1 && t <= 2 );
        return [self.redis pttl:key];
    }] then:^id(id value) {
        long t = [value longValue];
        XCTAssertTrue( t >= 1000 && t <= 2000 );
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark PEXPIREAT
- (void) test_PEXPIREAT {
    [self test: @"PEXPIREAT"];
    const NSString* key = [self randomKey];
    
    uint64_t now = (uint64_t)[[NSDate date] timeIntervalSince1970];
    uint64_t then = now + 86400;
    
    [[[[[self.redis set:key value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis pexpireat:key timestamp: then * 1000];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis ttl:key];
    }] then:^id(id value) {
        long t = [value longValue];
        XCTAssertTrue( t >= 86389 && t <= 86400 );
        return [self.redis pttl:key];
    }] then:^id(id value) {
        long t = [value longValue];
        XCTAssertTrue( t >= 86389000 && t <= 86400000 );
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark PTTL
- (void) test_PTTL {
    [self test: @"PTTL"];
    const NSString* key = [self randomKey];
    
    [[[[self.redis set:key value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis expire:key seconds:1];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis pttl:key];
    }] then:^id(id value) {
        long t = [value longValue];
        XCTAssertTrue( t >= 900 && t <= 1000 );
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark RANDOMKEY
- (void) test_RANDOMKEY {
    [self test: @"RANDOMKEY"];

    [[[[[self.redis mset: @[@"one", @1, @"two", @2, @"three", @3]] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis randomkey];
    }] then:^id(id value) {
        NSArray* expected = @[@"one", @"two", @"three"];
        XCTAssertTrue( [expected containsObject: value] );
        return [self.redis command: @[@"FLUSHDB"]];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis randomkey];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, [NSNull null]);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark RENAME
- (void) test_RENAME {
    [self test: @"RENAME"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];

    [[[[self.redis set: key1 value: @"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis rename:key1 newKey:key2];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis get:key2];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"Hello");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark RENAMENX
- (void) test_RENAMENX {
    [self test: @"RENAMENX"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];

    [[[[[self.redis set:key1 value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis set:key2 value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis renamenx:key1 newKey:key2];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self.redis get:key2];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"World");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark RESTORE
- (void) test_RESTORE {
    [self test: @"RESTORE"];

    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];

    [[[[[self.redis lpush:key1 values:@[@"Hello", @"World"]] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis dump:key1];
    }] then:^id(id value) {
        XCTAssertTrue( [value isKindOfClass:[NSData class]] || [value isKindOfClass:[NSString class]] );
        if( [value isKindOfClass:[NSString class]] ) {
            value = [(NSString*)value dataUsingEncoding:NSUTF8StringEncoding];
        }
        return [self.redis restore:key2 ttl:0 value:value];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis lrange:key2 range:NSMakeRange(0, -1)];
    }] then:^id(id value) {
        NSArray* expected = @[@"World", @"Hello"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/* TODO: test SORT */

#pragma mark TTL
- (void) test_TTL {
    [self test: @"TTL"];
    const NSString* key = [self randomKey];
    
    [[[[self.redis set:key value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis expire:key seconds:10];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis ttl:key];
    }] then:^id(id value) {
        long t = [value longValue];
        XCTAssertTrue( t >= 9 && t <= 10 );
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark TYPE
- (void) test_TYPE {
    [self test: @"TYPE"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    const NSString* key3 = [self randomKey];
    
    [[[[[[[self.redis set:key1 value:@"value"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis lpush:key2 value:@"value"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key3 value:@"value"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis type:key1];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"string");
        return [self.redis type:key2];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"list");
        return [self.redis type:key3];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"set");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark SCAN
- (void) test_SCAN {
    [self test: @"SCAN"];
    
    NSMutableDictionary* dict = [NSMutableDictionary new];
    NSMutableArray* msetValues = [NSMutableArray new];
    
    for( int i = 0; i < 100; ++i ) {
        NSString* key = [self randomKey];
        NSString* value = [[NSUUID UUID] UUIDString];
        
        [dict setObject:value forKey:key];
        [msetValues addObjectsFromArray: @[key, value]];
    }
    
    [msetValues addObjectsFromArray: @[@"HelloKey", @"Hello", @"WorldKey", @"World"]];

    [[[[self.redis mset:msetValues] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis scan: @"__TestKey_*"];
    }] then:^id(id value) {
        NSSet* expected = [NSSet setWithArray: dict.allKeys];
        NSSet* scanned  = [NSSet setWithArray: value];
        XCTAssertEqualObjects(expected, scanned);
        return [self.redis scan: @"*Key"];
    }] then:^id(id value) {
        NSSet* expected = [NSSet setWithArray: @[@"HelloKey", @"WorldKey"]];
        NSSet* scanned  = [NSSet setWithArray: value];
        XCTAssertEqualObjects(expected, scanned);
        return [self passed];
    }];
    
    [self wait];
}


@end
