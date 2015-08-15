//
//  HashesCommands.m
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 28.07.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import "RedisTestCase.h"

@interface HashesCommands : RedisTestCase
@end

@implementation HashesCommands

/*
 
 redis> HSET myhash field1 "foo"
 (integer) 1
 redis> HDEL myhash field1
 (integer) 1
 redis> HDEL myhash field2
 (integer) 0
 redis>

 */
#pragma mark HDEL
- (void) test_HDEL {
    [self test: @"HDEL"];
    const NSString* key = [self randomKey];

    [[[[self.redis hset:key field:@"field1" value:@"foo"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hdel:key field:@"field1"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hdel:key field:@"field2"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> HSET myhash field1 "foo"
 (integer) 1
 redis> HEXISTS myhash field1
 (integer) 1
 redis> HEXISTS myhash field2
 (integer) 0
 redis>
 */
#pragma mark HEXISTS
-  (void) test_HEXISTS {
    [self test: @"HEXISTS"];
    const NSString* key = [self randomKey];
    
    [[[[self.redis hset:key field:@"field1" value:@"foo"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hexists:key field:@"field1"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hexists:key field:@"field2"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self passed];
    }];
    
    [self wait];
}


/*
 redis> HSET myhash field1 "foo"
 (integer) 1
 redis> HGET myhash field1
 "foo"
 redis> HGET myhash field2
 (nil)
 redis>
 */
#pragma mark HGET
- (void) test_HGET {
    [self test: @"HGET"];
    const NSString* key = [self randomKey];

    [[[[self.redis hset:key field:@"field1" value:@"foo"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hget:key field:@"field1"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"foo");
        return [self.redis hget:key field:@"field2"];
    }] then:^id(id value) {
        XCTAssertTrue([value isKindOfClass: [NSNull class]]);
        return [self passed];
    }];
    
    [self wait];
}


/*
 edis> HSET myhash field1 "Hello"
 (integer) 1
 redis> HSET myhash field2 "World"
 (integer) 1
 redis> HGETALL myhash
 1) "field1"
 2) "Hello"
 3) "field2"
 4) "World"
 redis>
 */
#pragma mark HGETALL
- (void) test_HGETALL {
    [self test: @"HGETALL"];
    const NSString* key = [self randomKey];
    
    [[[[self.redis hset:key field:@"field1" value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hset:key field:@"field2" value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hgetall:key];
    }] then:^id(id value) {
        NSDictionary* expected = @{@"field1":@"Hello", @"field2":@"World"};
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}


/*
 redis> HSET myhash field 5
 (integer) 1
 redis> HINCRBY myhash field 1
 (integer) 6
 redis> HINCRBY myhash field -1
 (integer) 5
 redis> HINCRBY myhash field -10
 (integer) -5
 redis>
 */
#pragma mark HINCRBY
- (void) test_HINCRBY {
    [self test: @"HINCRBY"];
    const NSString* key = [self randomKey];
    
    [[[[[self.redis hset:key field:@"field" value:@5] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hincrby:key field:@"field" value:1];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @6);
        return [self.redis hincrby:key field:@"field" value:-1];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @5);
        return [self.redis hincrby:key field:@"field" value:-10];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @-5);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> HSET mykey field 10.50
 (integer) 1
 redis> HINCRBYFLOAT mykey field 0.1
 "10.6"
 redis> HSET mykey field 5.0e3
 (integer) 0
 redis> HINCRBYFLOAT mykey field 2.0e2
 "5200"
 redis>
 */

#pragma mark HINCRBYFLOAT
- (void) test_HINCRBYFLOAT {
    [self test: @"HINCRBY"];
    const NSString* key = [self randomKey];

    [[[[[self.redis hset:key field:@"field" value:@10.5] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hincrbyfloat:key field:@"field" value:0.1];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @10.6);
        return [self.redis hset:key field:@"field" value:@5.0e3];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self.redis hincrbyfloat:key field:@"field" value:2.0e2];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @5200);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> HSET myhash field1 "Hello"
 (integer) 1
 redis> HSET myhash field2 "World"
 (integer) 1
 redis> HKEYS myhash
 1) "field1"
 2) "field2"
 redis>
 */
#pragma mark HKEYS
- (void) test_HKEYS {
    [self test: @"HKEYS"];
    const NSString* key = [self randomKey];

    [[[[self.redis hset:key field:@"field1" value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hset:key field:@"field2" value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hkeys:key];
    }] then:^id(id value) {
        NSSet* expected = [NSSet setWithArray: @[@"field1", @"field2"]];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> HSET myhash field1 "Hello"
 (integer) 1
 redis> HSET myhash field2 "World"
 (integer) 1
 redis> HLEN myhash
 (integer) 2
 redis>
 */
#pragma mark HLEN
- (void) test_HLEN {
    [self test: @"HLEN"];
    const NSString* key = [self randomKey];
    
    [[[[self.redis hset:key field:@"field1" value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hset:key field:@"field2" value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hlen:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self passed];
    }];
    
    [self wait];
}


/*
 redis> HSET myhash field1 "Hello"
 (integer) 1
 redis> HSET myhash field2 "World"
 (integer) 1
 redis> HMGET myhash field1 field2 nofield
 1) "Hello"
 2) "World"
 3) (nil)
 redis>
 */
#pragma mark HMGET
- (void) test_HMGET {
    [self test: @"HMGET"];
    const NSString* key = [self randomKey];
    
    [[[[self.redis hset:key field:@"field1" value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hset:key field:@"field2" value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hmget:key fields:@[@"field1", @"field2", @"nofield"]];
    }] then:^id(id value) {
        NSArray* expected = @[@"Hello", @"World", [NSNull null]];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> HMSET myhash field1 "Hello" field2 "World"
 OK
 redis> HGET myhash field1
 "Hello"
 redis> HGET myhash field2
 "World"
 redis>
 */
#pragma mark HMSET
- (void) test_HMSET {
    [self test: @"HMSET"];
    const NSString* key = [self randomKey];
    
    [[[[self.redis hmset:key values:@[@"field1", @"Hello", @"field2", @"World"]] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis hget:key field:@"field1"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"Hello");
        return [self.redis hget:key field:@"field2"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"World");
        return [self passed];
    }];
    
    [self wait];
}

/*
 edis> HSET myhash field1 "Hello"
 (integer) 1
 redis> HGET myhash field1
 "Hello"
 redis>
 */
#pragma mark HSET
- (void) test_HSET {
    [self test: @"HSET"];
    const NSString* key = [self randomKey];
    
    [[[self.redis hset:key field:@"field1" value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hget:key field:@"field1"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"Hello");
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> HSETNX myhash field "Hello"
 (integer) 1
 redis> HSETNX myhash field "World"
 (integer) 0
 redis> HGET myhash field
 "Hello"
 redis>
 */
#pragma mark HSETNX
- (void) test_HSETNX {
    [self test: @"HSETNX"];
    const NSString* key = [self randomKey];
    
    [[[[self.redis hsetnx:key field:@"field" value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hsetnx:key field:@"field" value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self.redis hget:key field:@"field"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"Hello");
        return [self passed];
    }];
    
    [self wait];
}


/*
 redis> HMSET myhash f1 HelloWorld f2 99 f3 -256
 OK
 redis> HSTRLEN myhash f1
 (integer) 10
 redis> HSTRLEN myhash f2
 (integer) 2
 redis> HSTRLEN myhash f3
 (integer) 4
 redis>
 */
#pragma mark HSTRLEN
- (void) test_HSTRLEN {
    [[self test:@"HSTRLEN" requires:@"3.2.0"] then:^id(id unused) {

        const NSString* key = [self randomKey];
        
        return
        [[[[[self.redis hmset:key values:@[@"f1", @"HelloWorld", @"f2", @99, @"f3", @-256]] then:^id(id value) {
            XCTAssertEqualObjects(value, @"OK");
            return [self.redis hstrlen:key field:@"f1"];
        }] then:^id(id value) {
            XCTAssertEqualObjects(value, @10);
            return [self.redis hstrlen:key field:@"f2"];
        }] then:^id(id value) {
            XCTAssertEqualObjects(value, @2);
            return [self.redis hstrlen:key field:@"f3"];
        }] then:^id(id value) {
            XCTAssertEqualObjects(value, @4);
            return [self passed];
        }];

    }];
    
    [self wait];
}

/*
 redis> HSET myhash field1 "Hello"
 (integer) 1
 redis> HSET myhash field2 "World"
 (integer) 1
 redis> HVALS myhash
 1) "Hello"
 2) "World"
 redis>
*/
#pragma mark HVALS
- (void) test_HVALS {
    [self test: @"HVALS"];
    const NSString* key = [self randomKey];

    [[[[self.redis hset:key field:@"field1" value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hset:key field:@"field2" value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis hvals:key];
    }] then:^id(id value) {
        NSArray* expected = @[@"Hello", @"World"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}


#pragma mark HSCAN
- (void) test_HSCAN {
    [self test: @"HSCAN"];
    const NSString* key = [self randomKey];
    
    NSMutableArray* values = [NSMutableArray new];
    NSMutableDictionary* helloDict = [NSMutableDictionary new];
    NSMutableDictionary* worldDict = [NSMutableDictionary new];
    
    for( int i = 0; i < 50; ++i ) {
        NSString* key = [NSString stringWithFormat:@"Hello_%@", [[NSUUID UUID] UUIDString]];
        NSString* value = [[NSUUID UUID] UUIDString];
        [values addObjectsFromArray: @[key, value]];
        helloDict[key] = value;
    }
    
    for( int i = 0; i < 50; ++i ) {
        NSString* key = [NSString stringWithFormat:@"World_%@", [[NSUUID UUID] UUIDString]];
        NSString* value = [[NSUUID UUID] UUIDString];
        [values addObjectsFromArray: @[key, value]];
        worldDict[key] = value;
    }
    
    [[[[self.redis hmset:key values:values] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis hscan:key match:@"Hello*"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, helloDict);
        return [self.redis hscan:key match:@"World*"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, worldDict);
        return [self passed];
    }];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}


@end
