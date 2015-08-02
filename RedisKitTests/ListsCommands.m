//
//  ListsCommands.m
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 26.07.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import "RedisTestCase.h"

@interface ListsCommands : RedisTestCase
@end

@implementation ListsCommands

#pragma mark BLPOP
- (void) test_BLPOP {
    [self test: @"BLPOP"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    
    [[[self.redis rpush:key1 values: @[@"a", @"b", @"c"]] then:^id(id value) {
        XCTAssertEqualObjects(value, @3);
        return [self.redis blpopKeys: @[key1, key2] timeout:0];
    }] then:^id(id value) {
        NSArray* expected = @[key1, @"a"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark BRPOP
- (void) test_BRPOP {
    [self test: @"BRPOP"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    
    [[[self.redis rpush:key1 values: @[@"a", @"b", @"c"]] then:^id(id value) {
        XCTAssertEqualObjects(value, @3);
        return [self.redis brpopKeys: @[key1, key2] timeout:0];
    }] then:^id(id value) {
        NSArray* expected = @[key1, @"c"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark BRPOPLPUSH
- (void) test_BRPOPLPUSH {
    [self test: @"BRPOPLPUSH"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];

    [[[[[[[self.redis rpush:key1 value:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis rpush:key1 value:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis rpush:key1 value:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @3);
        return [self.redis brpop:key1 lpush:key2 timeout:1];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"three");
        return [self.redis lrange:key1 start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"one", @"two"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis lrange:key2 start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"three"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];

    [self wait];
}

/*
 redis> LPUSH mylist "World"
 (integer) 1
 redis> LPUSH mylist "Hello"
 (integer) 2
 redis> LINDEX mylist 0
 "Hello"
 redis> LINDEX mylist -1
 "World"
 redis> LINDEX mylist 3
 (nil)
 redis>
 */
#pragma mark LINDEX
- (void) test_LINDEX {
    [self test: @"LINDEX"];
    const NSString* key = [self randomKey];
   
    [[[[[[self.redis lpush:key value:@"World"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis lpush:key value:@"Hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis lindex:key value:0];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"Hello");
        return [self.redis lindex:key value:-1];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"World");
        return [self.redis lindex:key value:3];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, [NSNull null]);
        return [self passed];
    }];
    
    [self wait];
}


/*
 edis> RPUSH mylist "Hello"
 (integer) 1
 redis> RPUSH mylist "World"
 (integer) 2
 redis> LINSERT mylist BEFORE "World" "There"
 (integer) 3
 redis> LRANGE mylist 0 -1
 1) "Hello"
 2) "There"
 3) "World"
 redis>
 */
#pragma mark LINSERT
- (void) test_LINSERT {
    [self test: @"LINSERT"];
    const NSString* key = [self randomKey];
    
    [[[[[self.redis rpush:key value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis rpush:key value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis linsert:key before:@"World" value:@"There"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @3);
        return [self.redis lrange:key start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"Hello", @"There", @"World"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> LPUSH mylist "World"
 (integer) 1
 redis> LPUSH mylist "Hello"
 (integer) 2
 redis> LLEN mylist
 (integer) 2
 redis>
 */
#pragma mark LLEN
- (void) test_LLEN {
    [self test: @"LLEN"];
    const NSString* key = [self randomKey];
   
    [[[[self.redis lpush:key value:@"World"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis lpush:key value:@"Hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis llen:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> RPUSH mylist "one"
 (integer) 1
 redis> RPUSH mylist "two"
 (integer) 2
 redis> RPUSH mylist "three"
 (integer) 3
 redis> LPOP mylist
 "one"
 redis> LRANGE mylist 0 -1
 1) "two"
 2) "three"
 redis>
 */
#pragma mark LPOP
- (void) test_LPOP {
    [self test: @"LPOP"];
    const NSString* key = [self randomKey];
   
    [[[[[[self.redis rpush:key value:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis rpush:key value:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis rpush:key value:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @3);
        return [self.redis lpop:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"one");
        return [self.redis lrange:key start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"two", @"three"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark LPUSH
- (void) test_LPUSH {
    [self test: @"LPUSH"];
    const NSString* key = [self randomKey];
    
    [[
      [[self.redis lpush:key value: @"world"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis lpush:key value:@"hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis lrange:key start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"hello", @"world"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 edis> LPUSH mylist "World"
 (integer) 1
 redis> LPUSHX mylist "Hello"
 (integer) 2
 redis> LPUSHX myotherlist "Hello"
 (integer) 0
 redis> LRANGE mylist 0 -1
 1) "Hello"
 2) "World"
 redis> LRANGE myotherlist 0 -1
 (empty list or set)
 redis>
 */
#pragma mark LPUSHX

- (void) test_LPUSHX {
    [self test: @"LPUSHX"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    
    [[[[[[self.redis lpush:key1 value:@"World"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis lpushx:key1 value:@"Hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis lpushx:key2 value:@"Hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self.redis lrange:key1 start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"Hello", @"World"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis lrange:key2 start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark LRANGE
- (void) test_LRANGE {
    [self test: @"LRANGE"];
    const NSString* key = [self randomKey];
    
    [[[[[[
          [[self.redis rpush:key value:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis rpush:key value:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis rpush:key value:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @3);
        return [self.redis lrange:key start:0 stop:0];
    }] then:^id(id value) {
        NSArray* expected = @[@"one"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis lrange:key start:-3 stop:2];
    }] then:^id(id value) {
        NSArray* expected = @[@"one", @"two", @"three"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis lrange:key start:-100 stop:100];
    }] then:^id(id value) {
        NSArray* expected = @[@"one", @"two", @"three"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis lrange:key start:5 stop:10];
    }] then:^id(id value) {
        NSArray* expected = @[];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> RPUSH mylist "hello"
 (integer) 1
 redis> RPUSH mylist "hello"
 (integer) 2
 redis> RPUSH mylist "foo"
 (integer) 3
 redis> RPUSH mylist "hello"
 (integer) 4
 redis> LREM mylist -2 "hello"
 (integer) 2
 redis> LRANGE mylist 0 -1
 1) "hello"
 2) "foo"
 redis>
 */
#pragma mark LREM
- (void) test_LREM {
    [self test: @"LREM"];
    const NSString* key = [self randomKey];
    
    [[[[[[[self.redis rpush:key value:@"hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis rpush:key value:@"hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis rpush:key value:@"foo"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @3);
        return [self.redis rpush:key value:@"hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @4);
        return [self.redis lrem:key count:-2 value:@"hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis lrange:key start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"hello", @"foo"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> RPUSH mylist "one"
 (integer) 1
 redis> RPUSH mylist "two"
 (integer) 2
 redis> RPUSH mylist "three"
 (integer) 3
 redis> LSET mylist 0 "four"
 OK
 redis> LSET mylist -2 "five"
 OK
 redis> LRANGE mylist 0 -1
 1) "four"
 2) "five"
 3) "three"
 redis>
 */

#pragma mark LSET
- (void) test_LSET {
    [self test: @"LSET"];
    const NSString* key = [self randomKey];
    
    [[[[[[[self.redis rpush:key value:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis rpush:key value:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis rpush:key value:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @3);
        return [self.redis lset:key index:0 value:@"four"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis lset:key index:-2 value:@"five"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis lrange:key start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"four", @"five", @"three"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> RPUSH mylist "one"
 (integer) 1
 redis> RPUSH mylist "two"
 (integer) 2
 redis> RPUSH mylist "three"
 (integer) 3
 redis> LTRIM mylist 1 -1
 OK
 redis> LRANGE mylist 0 -1
 1) "two"
 2) "three"
 redis>
 */

#pragma mark LTRIM
- (void) test_LTRIM {
    [self test: @"LTRIM"];
    const NSString* key = [self randomKey];
    
    [[[[[[self.redis rpush:key value:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis rpush:key value:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis rpush:key value:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @3);
        return [self.redis ltrim:key start:1 stop:-1];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis lrange:key start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"two", @"three"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark RPOP
- (void) test_RPOP {
    [self test: @"RPOP"];
    const NSString* key = [self randomKey];
    
    [[[[[[self.redis rpush:key value:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis rpush:key value:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis rpush:key value:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @3);
        return [self.redis rpop:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"three");
        return [self.redis lrange:key start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"one", @"two"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark RPOPLPUSH
- (void) test_RPOPLPUSH {
    [self test: @"RPOPLPUSH"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    
    [[[[[[[self.redis rpush:key1 value:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis rpush:key1 value:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis rpush:key1 value:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @3);
        return [self.redis rpop:key1 lpush:key2];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"three");
        return [self.redis lrange:key1 start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"one", @"two"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis lrange:key2 start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"three"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark RPUSH
- (void) test_RPUSH {
    [self test: @"RPUSH"];
    const NSString* key = [self randomKey];
    
    [[[[self.redis rpush:key value:@"hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis rpush:key value:@"world"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis lrange:key start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"hello", @"world"];
        XCTAssertEqualObjects(expected, value);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> RPUSH mylist "Hello"
 (integer) 1
 redis> RPUSHX mylist "World"
 (integer) 2
 redis> RPUSHX myotherlist "World"
 (integer) 0
 redis> LRANGE mylist 0 -1
 1) "Hello"
 2) "World"
 redis> LRANGE myotherlist 0 -1
 (empty list or set)
 redis>
 */

#pragma mark RPUSHX
- (void) test_RPUSHX {
    [self test: @"RPUSHX"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    
    [[[[[[self.redis rpush:key1 value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis rpushx:key1 value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis rpushx:key2 value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self.redis lrange:key1 start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"Hello", @"World"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis lrange:key2 start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}




@end
