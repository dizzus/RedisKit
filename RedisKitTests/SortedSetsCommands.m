//
//  SortedSetsCommands.m
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 29.07.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import "RedisTestCase.h"

@interface SortedSetsCommands : RedisTestCase
@end

@implementation SortedSetsCommands

/*
 redis> ZADD myzset 1 "one"
 (integer) 1
 redis> ZADD myzset 1 "uno"
 (integer) 1
 redis> ZADD myzset 2 "two" 3 "three"
 (integer) 2
 redis> ZRANGE myzset 0 -1 WITHSCORES
 1) "one"
 2) "1"
 3) "uno"
 4) "1"
 5) "two"
 6) "2"
 7) "three"
 8) "3"
 */
#pragma mark ZADD
- (void) test_ZADD {
    [self test: @"ZADD"];
    const NSString* key = [self randomKey];

    [[[[[self.redis zadd:key score:1 member:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:1 member:@"uno"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key values: @[@2, @"two", @3, @"three"]];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis zrangeWithScores:key start:0 stop:-1];
    }] then:^id(id value) {
        NSDictionary* expected = @{@"one":@1.0, @"uno":@1.0, @"two":@2.0, @"three":@3.0};
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> ZADD myzset 1 "one"
 (integer) 1
 redis> ZADD myzset 2 "two"
 (integer) 1
 redis> ZCARD myzset
 (integer) 2
 redis>
 */
#pragma mark ZCARD
- (void) test_ZCARD {
    [self test: @"ZCARD"];
    const NSString* key = [self randomKey];
    
    [[[[self.redis zadd:key score:1 member:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:2 member:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zcard:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> ZADD myzset 1 "one"
 (integer) 1
 redis> ZADD myzset 2 "two"
 (integer) 1
 redis> ZADD myzset 3 "three"
 (integer) 1
 redis> ZCOUNT myzset -inf +inf
 (integer) 3
 redis> ZCOUNT myzset (1 3
 (integer) 2
 redis>
 */
#pragma mark ZCOUNT
- (void) test_ZCOUNT {
    [self test: @"ZCOUNT"];
    const NSString* key = [self randomKey];
    
    [[[[[[self.redis zadd:key score:1 member:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:2 member:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:3 member:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zcount:key min:@"-inf" max:@"+inf"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @3);
        return [self.redis zcount:key min:@"(1" max:@3];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> ZADD myzset 1 "one"
 (integer) 1
 redis> ZADD myzset 2 "two"
 (integer) 1
 redis> ZINCRBY myzset 2 "one"
 "3"
 redis> ZRANGE myzset 0 -1 WITHSCORES
 1) "two"
 2) "2"
 3) "one"
 4) "3"
 redis>
 */
#pragma mark ZINCRBY
- (void) test_ZINCRBY {
    [self test: @"ZINCRBY"];
    const NSString* key = [self randomKey];
    
    [[[[[self.redis zadd:key score:1 member:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:2 member:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zincrby:key value:2 member:@"one"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @3.0);
        return [self.redis zrangeWithScores:key start:0 stop:-1];
    }] then:^id(id value) {
        NSDictionary* expected = @{@"one":@3.0, @"two":@2.0};
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> ZADD zset1 1 "one"
 (integer) 1
 redis> ZADD zset1 2 "two"
 (integer) 1
 redis> ZADD zset2 1 "one"
 (integer) 1
 redis> ZADD zset2 2 "two"
 (integer) 1
 redis> ZADD zset2 3 "three"
 (integer) 1
 redis> ZINTERSTORE out 2 zset1 zset2 WEIGHTS 2 3
 (integer) 2
 redis> ZRANGE out 0 -1 WITHSCORES
 1) "one"
 2) "5"
 3) "two"
 4) "10"
 redis>
 */
#pragma mark ZINTERSTORE
- (void) test_ZINTERSTORE {
    [self test: @"ZINTERSTORE"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    const NSString* key3 = [self randomKey];
    
    [[[[[[[[self.redis zadd:key1 score:1 member:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key1 score:2 member:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key2 score:1 member:@"one"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key2 score:2 member:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key2 score:3 member:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zinterstore:key3 keys:@[key1, key2] weights:@[@2, @3]];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis zrangeWithScores:key3 start:0 stop:-1];
    }] then:^id(id value) {
        NSDictionary* expected = @{@"one":@5.0, @"two":@10.0};
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> ZADD myzset 0 a 0 b 0 c 0 d 0 e
 (integer) 5
 redis> ZADD myzset 0 f 0 g
 (integer) 2
 redis> ZLEXCOUNT myzset - +
 (integer) 7
 redis> ZLEXCOUNT myzset [b [f
 (integer) 5
 redis>
 */
#pragma mark ZLEXCOUNT
- (void) test_ZLEXCOUNT {
    [self test: @"ZLEXCOUNT"];
    const NSString* key = [self randomKey];

    [[[[[self.redis zadd:key values:@[@0, @"a", @0, @"b", @0, @"c", @0, @"d", @0, @"e"]] then:^id(id value) {
        XCTAssertEqualObjects(value, @5);
        return [self.redis zadd:key values:@[@0, @"f", @0, @"g"]];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis zlexcount:key min:@"-" max:@"+"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @7);
        return [self.redis zlexcount:key min:@"[b" max:@"[f"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @5);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> ZADD myzset 1 "one"
 (integer) 1
 redis> ZADD myzset 2 "two"
 (integer) 1
 redis> ZADD myzset 3 "three"
 (integer) 1
 redis> ZRANGE myzset 0 -1
 1) "one"
 2) "two"
 3) "three"
 redis> ZRANGE myzset 2 3
 1) "three"
 redis> ZRANGE myzset -2 -1
 1) "two"
 2) "three"
 redis>
 */
#pragma mark ZRANGE
- (void) test_ZRANGE {
    [self test: @"ZRANGE"];
    const NSString* key = [self randomKey];
    
    [[[[[[[self.redis zadd:key score:1 member:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:2 member:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:3 member:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zrange:key start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"one", @"two", @"three"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis zrange:key start:2 stop:3];
    }] then:^id(id value) {
        NSArray* expected = @[@"three"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis zrange:key start:-2 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"two", @"three"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> ZADD myzset 0 a 0 b 0 c 0 d 0 e 0 f 0 g
 (integer) 7
 redis> ZRANGEBYLEX myzset - [c
 1) "a"
 2) "b"
 3) "c"
 redis> ZRANGEBYLEX myzset - (c
 1) "a"
 2) "b"
 redis> ZRANGEBYLEX myzset [aaa (g
 1) "b"
 2) "c"
 3) "d"
 4) "e"
 5) "f"
 redis>
 */
#pragma mark ZRANGEBYLEX
- (void) test_ZRANGEBYLEX {
    [self test: @"ZRANGEBYLEX"];
    const NSString* key = [self randomKey];

    [[[[[self.redis zadd:key values:@[@0, @"a", @0, @"b", @0, @"c", @0, @"d", @0, @"e", @0, @"f", @0, @"g",]] then:^id(id value) {
        XCTAssertEqualObjects(value, @7);
        return [self.redis zrangebylex:key min:@"-" max:@"[c"];
    }] then:^id(id value) {
        NSArray* expected = @[@"a", @"b", @"c"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis zrangebylex:key min:@"-" max:@"(c"];
    }] then:^id(id value) {
        NSArray* expected = @[@"a", @"b"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis zrangebylex:key min:@"[aaa" max:@"(g"];
    }] then:^id(id value) {
        NSArray* expected = @[@"b", @"c", @"d", @"e", @"f"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}


/*
 redis> ZADD myzset 0 a 0 b 0 c 0 d 0 e 0 f 0 g
 (integer) 7
 redis> ZREVRANGEBYLEX myzset [c -
 1) "c"
 2) "b"
 3) "a"
 redis> ZREVRANGEBYLEX myzset (c -
 1) "b"
 2) "a"
 redis> ZREVRANGEBYLEX myzset (g [aaa
 1) "f"
 2) "e"
 3) "d"
 4) "c"
 5) "b"
 redis>
 */
#pragma mark ZREVRANGEBYLEX
- (void) test_ZREVRANGEBYLEX {
    [self test: @"ZREVRANGEBYLEX"];
    const NSString* key = [self randomKey];
    
    [[[[[self.redis zadd:key values:@[@0, @"a", @0, @"b", @0, @"c", @0, @"d", @0, @"e", @0, @"f", @0, @"g",]] then:^id(id value) {
        XCTAssertEqualObjects(value, @7);
        return [self.redis zrevrangebylex:key min:@"[c" max:@"-"];
    }] then:^id(id value) {
        NSArray* expected = @[@"c", @"b", @"a"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis zrevrangebylex:key min:@"(c" max:@"-"];
    }] then:^id(id value) {
        NSArray* expected = @[@"b", @"a"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis zrevrangebylex:key min:@"(g" max:@"[aaa"];
    }] then:^id(id value) {
        NSArray* expected = @[@"f", @"e", @"d", @"c", @"b"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> ZADD myzset 1 "one"
 (integer) 1
 redis> ZADD myzset 2 "two"
 (integer) 1
 redis> ZADD myzset 3 "three"
 (integer) 1
 redis> ZRANGEBYSCORE myzset -inf +inf
 1) "one"
 2) "two"
 3) "three"
 redis> ZRANGEBYSCORE myzset 1 2
 1) "one"
 2) "two"
 redis> ZRANGEBYSCORE myzset (1 2
 1) "two"
 redis> ZRANGEBYSCORE myzset (1 (2
 (empty list or set)
 redis>
 */
#pragma mark ZRANGEBYSCORE
- (void) test_ZRANGEBYSCORE {
    [self test: @"ZRANGEBYSCORE"];
    const NSString* key = [self randomKey];
    
    [[[[[[[[self.redis zadd:key score:1 member:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:2 member:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:3 member:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zrangebyscore:key min:@"-inf" max:@"+inf"];
    }] then:^id(id value) {
        NSArray* expected = @[@"one", @"two", @"three"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis zrangebyscore:key min:@1 max:@2];
    }] then:^id(id value) {
        NSArray* expected = @[@"one", @"two"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis zrangebyscore:key min:@"(1" max:@"2"];
    }] then:^id(id value) {
        NSArray* expected = @[@"two"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis zrangebyscore:key min:@"(1" max:@"(2"];
    }] then:^id(id value) {
        NSArray* expected = @[];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];

    [self wait];
}


/*
 redis> ZADD myzset 1 "one"
 (integer) 1
 redis> ZADD myzset 2 "two"
 (integer) 1
 redis> ZADD myzset 3 "three"
 (integer) 1
 redis> ZRANK myzset "three"
 (integer) 2
 redis> ZRANK myzset "four"
 (nil)
 redis>
 */
#pragma mark ZRANK
- (void) test_ZRANK {
    [self test: @"ZRANK"];
    const NSString* key = [self randomKey];
    
    [[[[[[self.redis zadd:key score:1 member:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:2 member:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:3 member:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zrank:key member:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis zrank:key member:@"four"];
    }] then:^id(id value) {
        XCTAssertTrue( [value isKindOfClass:[NSNull class]] );
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> ZADD myzset 1 "one"
 (integer) 1
 redis> ZADD myzset 2 "two"
 (integer) 1
 redis> ZADD myzset 3 "three"
 (integer) 1
 redis> ZREM myzset "two"
 (integer) 1
 redis> ZRANGE myzset 0 -1 WITHSCORES
 1) "one"
 2) "1"
 3) "three"
 4) "3"
 redis>
 */
#pragma mark ZREM
- (void) test_ZREM {
    [self test: @"ZREM"];
    const NSString* key = [self randomKey];
    
    [[[[[[self.redis zadd:key score:1 member:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:2 member:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:3 member:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zrem:key member:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zrangeWithScores:key start:0 stop:-1];
    }] then:^id(id value) {
        NSDictionary* expected = @{@"one":@1.0, @"three":@3.0};
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
    
}

/*
 redis> ZADD myzset 0 aaaa 0 b 0 c 0 d 0 e
 (integer) 5
 redis> ZADD myzset 0 foo 0 zap 0 zip 0 ALPHA 0 alpha
 (integer) 5
 redis> ZRANGE myzset 0 -1
 1) "ALPHA"
 2) "aaaa"
 3) "alpha"
 4) "b"
 5) "c"
 6) "d"
 7) "e"
 8) "foo"
 9) "zap"
 10) "zip"
 redis> ZREMRANGEBYLEX myzset [alpha [omega
 (integer) 6
 redis> ZRANGE myzset 0 -1
 1) "ALPHA"
 2) "aaaa"
 3) "zap"
 4) "zip"
 redis>
 */

#pragma mark ZREMRANGEBYLEX
- (void) test_ZREMRANGEBYLEX {
    [self test: @"ZREMRANGEBYLEX"];
    const NSString* key = [self randomKey];

    [[[[[[self.redis zadd:key values:@[@0, @"aaaa", @0, @"b", @0, @"c", @0, @"d", @0, @"e"]] then:^id(id value) {
        XCTAssertEqualObjects(value, @5);
        return [self.redis zadd:key values:@[@0,@"foo",@0,@"zap",@0,@"zip",@0,@"ALPHA",@0,@"alpha"]];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @5);
        return [self.redis zrange:key start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"ALPHA", @"aaaa", @"alpha", @"b", @"c", @"d", @"e", @"foo", @"zap", @"zip"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis zremrangebylex:key min:@"[alpaha" max:@"[omega"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @6);
        return [self.redis zrange:key start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"ALPHA", @"aaaa", @"zap", @"zip"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> ZADD myzset 1 "one"
 (integer) 1
 redis> ZADD myzset 2 "two"
 (integer) 1
 redis> ZADD myzset 3 "three"
 (integer) 1
 redis> ZREMRANGEBYRANK myzset 0 1
 (integer) 2
 redis> ZRANGE myzset 0 -1 WITHSCORES
 1) "three"
 2) "3"
 redis>
 */
#pragma mark ZREMRANGEBYRANK
- (void) test_ZREMRANGEBYRANK {
    [self test: @"ZREMRANGEBYRANK"];
    const NSString* key = [self randomKey];
   
    [[[[[[self.redis zadd:key score:1 member:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:2 member:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:3 member:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zremrangebyrank:key start:0 stop:1];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis zrangeWithScores:key start:0 stop:-1];
    }] then:^id(id value) {
        NSDictionary* expected = @{@"three":@3};
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
      
    [self wait];
}

/*
 redis> ZADD myzset 1 "one"
 (integer) 1
 redis> ZADD myzset 2 "two"
 (integer) 1
 redis> ZADD myzset 3 "three"
 (integer) 1
 redis> ZREMRANGEBYSCORE myzset -inf (2
 (integer) 1
 redis> ZRANGE myzset 0 -1 WITHSCORES
 1) "two"
 2) "2"
 3) "three"
 4) "3"
 redis>
 */
#pragma mark ZREMRANGEBYSCORE
- (void) test_ZREMRANGEBYSCORE {
    [self test: @"ZREMRANGEBYSCORE"];
    const NSString* key = [self randomKey];
    
    [[[[[[self.redis zadd:key score:1 member:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:2 member:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:3 member:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zremrangebyscore:key min:@"-inf" max:@"(2"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zrangeWithScores:key start:0 stop:-1];
    }] then:^id(id value) {
        NSDictionary* expected = @{@"two":@2, @"three":@3};
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> ZADD myzset 1 "one"
 (integer) 1
 redis> ZADD myzset 2 "two"
 (integer) 1
 redis> ZADD myzset 3 "three"
 (integer) 1
 redis> ZREVRANGE myzset 0 -1
 1) "three"
 2) "two"
 3) "one"
 redis> ZREVRANGE myzset 2 3
 1) "one"
 redis> ZREVRANGE myzset -2 -1
 1) "two"
 2) "one"
 redis>
 */
#pragma mark ZREVRANGE
- (void) test_ZREVRANGE {
    [self test: @"ZREVRANGE"];
    const NSString* key = [self randomKey];
    
    [[[[[[[self.redis zadd:key score:1 member:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:2 member:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:3 member:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zrevrange:key start:0 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"three", @"two", @"one"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis zrevrange:key start:2 stop:3];
    }] then:^id(id value) {
        NSArray* expected = @[@"one"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis zrevrange:key start:-2 stop:-1];
    }] then:^id(id value) {
        NSArray* expected = @[@"two", @"one"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> ZADD myzset 1 "one"
 (integer) 1
 redis> ZADD myzset 2 "two"
 (integer) 1
 redis> ZADD myzset 3 "three"
 (integer) 1
 redis> ZREVRANGEBYSCORE myzset +inf -inf
 1) "three"
 2) "two"
 3) "one"
 redis> ZREVRANGEBYSCORE myzset 2 1
 1) "two"
 2) "one"
 redis> ZREVRANGEBYSCORE myzset 2 (1
 1) "two"
 redis> ZREVRANGEBYSCORE myzset (2 (1
 (empty list or set)
 redis>
 */
#pragma mark ZREVRANGEBYSCORE
- (void) test_ZREVRANGEBYSCORE {
    [self test: @"ZREVRANGEBYSCORE"];
    const NSString* key = [self randomKey];
    
    [[[[[[[[self.redis zadd:key score:1 member:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:2 member:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:3 member:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zrevrangebyscore:key min:@"+inf" max:@"-inf"];
    }] then:^id(id value) {
        NSArray* expected = @[@"three", @"two", @"one"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis zrevrangebyscore:key min:@2 max:@1];
    }] then:^id(id value) {
        NSArray* expected = @[@"two", @"one"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis zrevrangebyscore:key min:@2 max:@"(1"];
    }] then:^id(id value) {
        NSArray* expected = @[@"two"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis zrevrangebyscore:key min:@"(2" max:@"(1"];
    }] then:^id(id value) {
        NSArray* expected = @[];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> ZADD myzset 1 "one"
 (integer) 1
 redis> ZADD myzset 2 "two"
 (integer) 1
 redis> ZADD myzset 3 "three"
 (integer) 1
 redis> ZREVRANK myzset "one"
 (integer) 2
 redis> ZREVRANK myzset "four"
 (nil)
 redis>
 */
#pragma mark ZREVRANK
- (void) test_ZREVRANK {
    [self test: @"ZREVRANK"];
    const NSString* key = [self randomKey];
    
    [[[[[[self.redis zadd:key score:1 member:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:2 member:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key score:3 member:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zrevrank:key member:@"one"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @2);
        return [self.redis zrevrank:key member:@"four"];
    }] then:^id(id value) {
        XCTAssertTrue( [value isKindOfClass:[NSNull class]] );
        return [self passed];
    }];
       
    [self wait];
}

/*
 redis> ZADD myzset 1 "one"
 (integer) 1
 redis> ZSCORE myzset "one"
 "1"
 redis>
 */
#pragma mark ZSCORE
- (void) test_ZSCORE {
    [self test: @"ZSCORE"];
    const NSString* key = [self randomKey];
    
    [[[self.redis zadd:key score:1 member:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zscore:key member:@"one"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1.0);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> ZADD zset1 1 "one"
 (integer) 1
 redis> ZADD zset1 2 "two"
 (integer) 1
 redis> ZADD zset2 1 "one"
 (integer) 1
 redis> ZADD zset2 2 "two"
 (integer) 1
 redis> ZADD zset2 3 "three"
 (integer) 1
 redis> ZUNIONSTORE out 2 zset1 zset2 WEIGHTS 2 3
 (integer) 3
 redis> ZRANGE out 0 -1 WITHSCORES
 1) "one"
 2) "5"
 3) "three"
 4) "9"
 5) "two"
 6) "10"
 redis>
 */
#pragma mark ZUNIONSTORE
- (void) test_ZUNIONSTORE {
    [self test: @"ZUNIONSTORE"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    const NSString* key3 = [self randomKey];
    
    [[[[[[[[self.redis zadd:key1 score:1 member:@"one"] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key1 score:2 member:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key2 score:1 member:@"one"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key2 score:2 member:@"two"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zadd:key2 score:3 member:@"three"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis zunionstore:key3 keys:@[key1, key2] weights:@[@2, @3]];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @3);
        return [self.redis zrangeWithScores:key3 start:0 stop:-1];
    }] then:^id(id value) {
        NSDictionary* expected = @{@"one":@5, @"three":@9, @"two":@10};
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark ZSCAN
- (void) test_ZSCAN {
    [self test: @"ZSCAN"];
    const NSString* key = [self randomKey];
    
    NSMutableArray* values = [NSMutableArray new];
    NSMutableDictionary* helloDict = [NSMutableDictionary new];
    NSMutableDictionary* worldDict = [NSMutableDictionary new];
    
    for( int i = 0; i < 50; ++i ) {
        NSString* key = [NSString stringWithFormat:@"Hello_%@", [[NSUUID UUID] UUIDString]];
        NSNumber* value = [NSNumber numberWithDouble: (double) arc4random()];
        [values addObjectsFromArray: @[value, key]];
        helloDict[key] = value;
    }
    
    for( int i = 0; i < 50; ++i ) {
        NSString* key = [NSString stringWithFormat:@"World_%@", [[NSUUID UUID] UUIDString]];
        NSNumber* value = [NSNumber numberWithDouble: (double) arc4random()];
        [values addObjectsFromArray: @[value, key]];
        worldDict[key] = value;
    }
    
    [[[[self.redis zadd:key values:values] then:^id(id value) {
        XCTAssertEqualObjects(value, @100);
        return [self.redis zscan:key match:@"Hello*"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, helloDict);
        return [self.redis zscan:key match:@"World*"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, worldDict);
        return [self passed];
    }];
    
    [self wait];
}


@end
