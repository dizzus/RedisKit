//
//  StringsCommands.m
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 25.07.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import "RedisTestCase.h"

@interface StringsCommands : RedisTestCase
@end

@implementation StringsCommands

#pragma mark APPEND
- (void)test_APPEND {
    [self test: @"APPEND"];
    const NSString* key = [self randomKey];
    
    [[[
    [[self.redis exists:key] then:^id(id value) {
        //XCTAssertEqualObjects(value, @0);
        XCTAssertEqual([value integerValue], 0);

        return [self.redis append:key value:@"Hello"];
    }] then:^id(id value) {
        //XCTAssertEqualObjects(value, @5);
        XCTAssertEqual([value integerValue], 5);

        return [self.redis append:key value:@" World"];
    }] then:^id(id value) {
        //XCTAssertEqualObjects(value, @11);
        XCTAssertEqual([value integerValue], 11);

        return [self.redis get:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"Hello World");
        return [self passed];
    }];

    [self wait];
}

#pragma mark BITCOUNT
- (void) test_BITCOUNT {
    [self test: @"BITCOUNT"];
    const NSString* key = [self randomKey];
    
    [[[
    [[self.redis set:key value:@"foobar"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis bitcount:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @26);
        return [self.redis bitcount:key start:0 end:0];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @4);
        return [self.redis bitcount:key start:1 end:1];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @6);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark BITOP
- (void) test_BITOP {
    [self test: @"BITOP"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    const NSString* dest = [self randomKey];
    
    [[[
    [[self.redis set:key1 value:@"foobar"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis set:key2 value:@"abcdef"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis bitopAnd:dest keys:@[key1, key2]];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @6);
        return [self.redis get:dest];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"`bc`ab");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark BITPOS
- (void) test_BITPOS {
    [self test: @"BITPOS"];
    const NSString* key = [self randomKey];

    const NSData* v1 = [NSData dataWithBytes:"\xff\xf0\x00" length:3];
    const NSData* v2 = [NSData dataWithBytes:"\x00\xff\xf0" length:3];
    const NSData* v3 = [NSData dataWithBytes:"\x00\x00\x00" length:3];
    
    [[[[[[
    [[self.redis set:key value:v1] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis bitpos:key value:0];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @12);
        return [self.redis set:key value:v2];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis bitpos:key value:1 start:0];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @8);
        return [self.redis bitpos:key value:1 start:2];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @16);
        return [self.redis set:key value:v3];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis bitpos:key value:1];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @-1);
        return [self passed];
    }];

    [self wait];
}

#pragma mark DECR
- (void) test_DECR {
    [self test: @"DECR"];
    const NSString* key = [self randomKey];
    
    [[[
    [[self.redis set:key value:@10] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis decr:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @9);
        return [self.redis set:key value: @"234293482390480948029348230948"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis decr:key];
    }] catch:^id(NSError *err) {
        XCTAssertEqualObjects(err.domain, @"ERR value is not an integer or out of range");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark DECRBY
- (void) test_DECRBY {
    [self test: @"DECRBY"];
    const NSString* key = [self randomKey];

    [
    [[self.redis set:key value:@10] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis decrby:key value:3];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @7);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark GET
- (void) test_GET {
    [self test: @"GET"];

    const NSString* key = [self randomKey];
    
    [[
    [[self.redis get: @"nonexisting"] then:^id(id value) {
        XCTAssertEqualObjects(value, [NSNull null]);
        return [self.redis set:key value:@"Hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis get:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"Hello");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark GETBIT
- (void) test_GETBIT {
    [self test: @"GETBIT"];
    const NSString* key = [self randomKey];
    
    [[[
    [[self.redis setbit:key offset:7 value:1] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self.redis getbit:key offset:0];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self.redis getbit:key offset:7];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis getbit:key offset:100];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark GETRANGE
- (void) test_GETRANGE {
    [self test: @"GETRANGE"];
    const NSString* key = [self randomKey];
    
    [[[[
    [[self.redis set:key value:@"This is a string"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis getrange:key start:0 end:3];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"This");
        return [self.redis getrange:key start:-3 end:-1];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"ing");
        return [self.redis getrange:key start:0 end:-1];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"This is a string");
        return [self.redis getrange:key start:10 end:100];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"string");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark GETSET
- (void) test_GETSET {
    [self test: @"GETSET"];
    const NSString* key = [self randomKey];

    [[
    [[self.redis set:key value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis getset:key value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"Hello");
        return [self.redis get:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"World");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark INCR
- (void) test_INCR {
    [self test: @"INCR"];
    const NSString* key = [self randomKey];
    
    [[
    [[self.redis set:key value:@10] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis incr:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @11);
        return [self.redis get:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"11");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark INCRBY
- (void) test_INCRBY {
    [self test: @"INCR"];
    const NSString* key = [self randomKey];

    [
    [[self.redis set:key value:@10] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis incrby:key value:5];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @15);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark INCRBYFLOAT
- (void) test_INCRBYFLOAT {
    [self test: @"INCRBYFLOAT"];
    const NSString* key = [self randomKey];

    [[[
    [[self.redis set:key value:@10.50] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis incrbyfloat:key value:0.1];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @10.6);
        return [self.redis set:key value: @5.0e3];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis incrbyfloat:key value:2.0e2];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @5200);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark MGET
- (void) test_MGET {
    [self test: @"MGET"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    
    [[
    [[self.redis set:key1 value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis set:key2 value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis mget: @[key1, key2]];
    }] then:^id(id value) {
        NSArray* expected = @[@"Hello", @"World"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark MSET
- (void) test_MSET {
    [self test: @"MGET"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];

    [[
    [[self.redis mset: @[key1, @"Hello", key2, @"World"]] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis get:key1];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"Hello");
        return [self.redis get:key2];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"World");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark MSETNX
- (void) test_MSETNX {
    [self test: @"MSETNX"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    const NSString* key3 = [self randomKey];
    
    [[
    [[self.redis msetnx: @[key1, @"Hello", key2, @"there"]] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis msetnx: @[key2, @"there", key3, @"world"]];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self.redis mget: @[key1, key2, key3]];
    }] then:^id(id value) {
        NSArray* expected = @[@"Hello", @"there", [NSNull null]];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark PSETEX
- (void) test_PSETEX {
    [self test: @"PSETEX"];
    const NSString* key = [self randomKey];
    
    [
    [[self.redis psetex:key milliseconds:1000 value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis pttl:key];
    }] then:^id(id value) {
        XCTAssertTrue( [value longValue] <= 1000 );
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark SET
- (void) test_SET {
    [self test: @"SET"];
    const NSString* key = [self randomKey];
    
    [
    [[self.redis set:key value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis get:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"Hello");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark SETBIT
- (void) test_SETBIT {
    [self test: @"SETBIT"];
    const NSString* key = [self randomKey];
    
    [[[
    [[self.redis setbit:key offset:7 value:1] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self.redis setbit:key offset:7 value:0];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis setbit:key offset:2 value:1];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self.redis get:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @" ");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark SETEX
- (void) test_SETEX {
    [self test: @"SETEX"];
    const NSString* key = [self randomKey];
    
    [[
    [[self.redis setex:key seconds:10 value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis ttl:key];
    }] then:^id(id value) {
        XCTAssertTrue( [value integerValue] <= 10 );
        return [self.redis get:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"Hello");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark SETNX
- (void) test_SETNX {
    [self test: @"SETNX"];
    const NSString* key = [self randomKey];

    [[
    [[self.redis setnx:key value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis setnx:key value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self.redis get:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"Hello");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark SETRANGE
- (void) test_SETRANGE {
    [self test: @"SETRANGE"];
    const NSString* key = [self randomKey];

    [[
    [[self.redis set:key value:@"Hello World"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis setrange:key offset:6 value:@"Redis"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @11);
        return [self.redis get:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"Hello Redis");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark STRLEN
- (void) test_STRLEN {
    [self test: @"STRLEN"];
    const NSString* key = [self randomKey];
    
    [[
    [[self.redis set:key value:@"Hello world"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis strlen:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @11);
        return [self.redis strlen: @"nonexisting"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self passed];
    }];
    
    [self wait];
}


@end
