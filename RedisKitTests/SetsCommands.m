//
//  SetsCommands.m
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 26.07.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import "RedisTestCase.h"

@interface SetsCommands : RedisTestCase
@end

@implementation SetsCommands

#pragma mark SADD
- (void) test_SADD {
    [self test: @"SADD"];
    const NSString* key = [self randomKey];

    [[[[[self.redis sadd:key value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self.redis smembers:key];
    }] then:^id(id value) {
        NSSet* expected = [NSSet setWithArray: @[@"Hello", @"World"]];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}


#pragma mark SCARD
- (void) test_SCARD {
    [self test: @"SCARD"];
    const NSString* key = [self randomKey];
    
    [[[[self.redis sadd:key value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis scard:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> SADD key1 "a"
 (integer) 1
 redis> SADD key1 "b"
 (integer) 1
 redis> SADD key1 "c"
 (integer) 1
 redis> SADD key2 "c"
 (integer) 1
 redis> SADD key2 "d"
 (integer) 1
 redis> SADD key2 "e"
 (integer) 1
 redis> SDIFF key1 key2
 1) "a"
 2) "b"
 */
#pragma mark SDIFF
- (void) test_SDIFF {
    [self test: @"SDIFF"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    
    [[[[[[[[self.redis sadd:key1 value:@"a"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key1 value:@"b"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key1 value:@"c"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"c"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"d"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"e"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sdiff:key1 with:key2];
    }] then:^id(id value) {
        NSSet* expected = [NSSet setWithArray: @[@"a", @"b"]];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> SADD key1 "a"
 (integer) 1
 redis> SADD key1 "b"
 (integer) 1
 redis> SADD key1 "c"
 (integer) 1
 redis> SADD key2 "c"
 (integer) 1
 redis> SADD key2 "d"
 (integer) 1
 redis> SADD key2 "e"
 (integer) 1
 redis> SDIFFSTORE key key1 key2
 (integer) 2
 redis> SMEMBERS key
 1) "a"
 2) "b"
 redis>
 */
#pragma mark SDIFFSTORE
- (void) test_SDIFFSTORE {
    [self test: @"SDIFFSTORE"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    const NSString* key3 = [self randomKey];
    
    [[[[[[[[[self.redis sadd:key1 value:@"a"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key1 value:@"b"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key1 value:@"c"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"c"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"d"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"e"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sdiffstore:key3 key:key1 with:key2];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis smembers:key3];
    }] then:^id(id value) {
        NSSet* expected = [NSSet setWithArray: @[@"a", @"b"]];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> SADD key1 "a"
 (integer) 1
 redis> SADD key1 "b"
 (integer) 1
 redis> SADD key1 "c"
 (integer) 1
 redis> SADD key2 "c"
 (integer) 1
 redis> SADD key2 "d"
 (integer) 1
 redis> SADD key2 "e"
 (integer) 1
 redis> SINTER key1 key2
 1) "c"
 redis>
 */
#pragma mark SINTER
- (void) test_SINTER {
    [self test: @"SINTER"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    
    [[[[[[[[self.redis sadd:key1 value:@"a"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key1 value:@"b"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key1 value:@"c"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"c"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"d"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"e"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sinter:key1 with:key2];
    }] then:^id(id value) {
        NSSet* expected = [NSSet setWithArray: @[@"c"]];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}


/*
 redis> SADD key1 "a"
 (integer) 1
 redis> SADD key1 "b"
 (integer) 1
 redis> SADD key1 "c"
 (integer) 1
 redis> SADD key2 "c"
 (integer) 1
 redis> SADD key2 "d"
 (integer) 1
 redis> SADD key2 "e"
 (integer) 1
 redis> SINTERSTORE key key1 key2
 (integer) 1
 redis> SMEMBERS key
 1) "c"
 redis>
  */
#pragma mark SINTERSTORE
- (void) test_SINTERFSTORE {
    [self test: @"SINTERSTORE"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    const NSString* key3 = [self randomKey];
    
    [[[[[[[[[self.redis sadd:key1 value:@"a"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key1 value:@"b"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key1 value:@"c"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"c"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"d"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"e"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sinterstore:key3 key:key1 with:key2];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis smembers:key3];
    }] then:^id(id value) {
        NSSet* expected = [NSSet setWithArray: @[@"c"]];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}


/*
 redis> SADD myset "one"
 (integer) 1
 redis> SISMEMBER myset "one"
 (integer) 1
 redis> SISMEMBER myset "two"
 (integer) 0
 redis>
 */
#pragma mark SISMEMBER
- (void) test_SISMEMBER {
    [self test: @"SISMEMBER"];
    const NSString* key = [self randomKey];
    
    [[[[self.redis sadd:key value:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sismember:key value:@"one"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sismember:key value:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self passed];
    }];
    
    [self wait];
}


#pragma mark SMEMBERS
- (void) test_SMEMBERS {
    [self test: @"SMEMBERS"];
    const NSString* key = [self randomKey];
    
    [[[[self.redis sadd:key value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key value:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis smembers:key];
    }] then:^id(id value) {
        NSSet* expected = [NSSet setWithArray: @[@"Hello", @"World"]];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> SADD myset "one"
 (integer) 1
 redis> SADD myset "two"
 (integer) 1
 redis> SADD myotherset "three"
 (integer) 1
 redis> SMOVE myset myotherset "two"
 (integer) 1
 redis> SMEMBERS myset
 1) "one"
 redis> SMEMBERS myotherset
 1) "three"
 2) "two"
 redis>
 */
#pragma mark SMOVE
- (void) test_SMOVE {
    [self test: @"SMOVE"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    
    [[[[[[[self.redis sadd:key1 value:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key1 value:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis smove:key1 destination:key2 value:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis smembers:key1];
    }] then:^id(id value) {
        NSSet* expected = [NSSet setWithArray: @[@"one"]];
        XCTAssertEqualObjects(value, expected);
        return [self.redis smembers:key2];
    }] then:^id(id value) {
        NSSet* expected = [NSSet setWithArray: @[@"three", @"two"]];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark SPOP
- (void) test_SPOP {
    [self test: @"SPOP"];
    const NSString* key = [self randomKey];
   
    NSMutableSet* expected = [NSMutableSet setWithObjects: @"one", @"two", @"three", nil];
    
    [[[[[[self.redis sadd:key value:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key value:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key value:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis spop:key];
    }] then:^id(id value) {
        XCTAssertTrue([expected containsObject: value]);
        [expected removeObject:value];
        return [self.redis smembers:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> SADD myset one two three
 (integer) 3
 redis> SRANDMEMBER myset
 "three"
 redis> SRANDMEMBER myset 2
 1) "three"
 2) "two"
 redis> SRANDMEMBER myset -5
 1) "two"
 2) "one"
 3) "three"
 4) "three"
 5) "two"
 redis>
 */

#pragma mark SRANDMEMBER
- (void) test_SRANDMEMBER {
    [self test: @"SRANDMEMBER"];
    const NSString* key = [self randomKey];

    NSArray* members = @[@"one", @"two", @"three"];
    NSMutableSet* expected = [NSMutableSet setWithArray:members];
    
    [[[[[self.redis sadd:key values:members] then:^id(id value) {
        XCTAssertEqualObjects(value, @3);
        return [self.redis srandmember:key];
    }] then:^id(id value) {
        XCTAssertTrue( [expected containsObject:value] );
        return [self.redis srandmember:key count:2];
    }] then:^id(id value) {
        XCTAssertTrue([value count] == 2);
        XCTAssertTrue([value isSubsetOfSet: expected]);
        return [self.redis srandmember:key count:-5];
    }] then:^id(id value) {
        for(NSString* s in value) {
            XCTAssertTrue([expected containsObject:s]);
        }
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> SADD myset "one"
 (integer) 1
 redis> SADD myset "two"
 (integer) 1
 redis> SADD myset "three"
 (integer) 1
 redis> SREM myset "one"
 (integer) 1
 redis> SREM myset "four"
 (integer) 0
 redis> SMEMBERS myset
 1) "three"
 2) "two"
 redis>
 */
#pragma mark SREM 
- (void) test_SREM {
    [self test: @"SREM"];
    const NSString* key = [self randomKey];
    
    [[[[[[[self.redis sadd:key value:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key value:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key value:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis srem:key value:@"one"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis srem:key value:@"four"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self.redis smembers:key];
    }] then:^id(id value) {
        NSSet* expected = [NSSet setWithArray: @[@"three",@"two"]];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> SADD key1 "a"
 (integer) 1
 redis> SADD key1 "b"
 (integer) 1
 redis> SADD key1 "c"
 (integer) 1
 redis> SADD key2 "c"
 (integer) 1
 redis> SADD key2 "d"
 (integer) 1
 redis> SADD key2 "e"
 (integer) 1
 redis> SUNION key1 key2
 1) "a"
 2) "b"
 3) "c"
 4) "e"
 5) "d"
 redis>
 */
#pragma mark SUNION
- (void) test_SUNION {
    [self test: @"SUNION"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    
    [[[[[[[[self.redis sadd:key1 value:@"a"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key1 value:@"b"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key1 value:@"c"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"c"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"d"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"e"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sunion:key1 with:key2];
    }] then:^id(id value) {
        NSSet* expected = [NSSet setWithArray: @[@"a", @"b", @"c", @"d", @"e"]];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> SADD key1 "a"
 (integer) 1
 redis> SADD key1 "b"
 (integer) 1
 redis> SADD key1 "c"
 (integer) 1
 redis> SADD key2 "c"
 (integer) 1
 redis> SADD key2 "d"
 (integer) 1
 redis> SADD key2 "e"
 (integer) 1
 redis> SUNIONSTORE key key1 key2
 (integer) 5
 redis> SMEMBERS key
 1) "a"
 2) "b"
 3) "c"
 4) "e"
 5) "d"
 redis>
 */
#pragma mark SUNIONSTORE
- (void) test_SUNIONSTORE {
    [self test: @"SUNIONSTORE"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    const NSString* key3 = [self randomKey];
    
    [[[[[[[[[self.redis sadd:key1 value:@"a"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key1 value:@"b"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key1 value:@"c"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"c"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"d"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sadd:key2 value:@"e"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis sunionstore:key3 key:key1 with:key2];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @5);
        return [self.redis smembers:key3];
    }] then:^id(id value) {
        NSSet* expected = [NSSet setWithArray: @[@"a", @"b", @"c", @"d", @"e"]];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}


#pragma mark SSCAN
- (void) test_SSCAN {
    [self test: @"SSCAN"];
    const NSString* key = [self randomKey];

    NSMutableArray* values = [NSMutableArray new];
    NSMutableSet* helloSet = [NSMutableSet new];
    NSMutableSet* worldSet = [NSMutableSet new];
    
    for( int i = 0; i < 50; ++i ) {
        NSString* uuid = [[NSUUID UUID] UUIDString];
        NSString* value = [NSString stringWithFormat:@"Hello_%@", uuid];
        [values addObject: value];
        [helloSet addObject: value];
    }
    for( int i = 0; i < 50; ++i ) {
        NSString* uuid = [[NSUUID UUID] UUIDString];
        NSString* value = [NSString stringWithFormat:@"World_%@", uuid];
        [values addObject: value];
        [worldSet addObject: value];
    }
    
    [[[[self.redis sadd:key values:values] then:^id(id value) {
        XCTAssertTrue([value integerValue] == values.count);
        return [self.redis sscan:key match:@"Hello*"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, helloSet);
        return [self.redis sscan:key match:@"World*"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, worldSet);
        return [self passed];
    }];
    
    [self wait];
}


@end
