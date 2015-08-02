//
//  HyperLogLogCommands.m
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 31.07.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import "RedisTestCase.h"

@interface HyperLogLogCommands : RedisTestCase
@end

@implementation HyperLogLogCommands

/*
 redis> PFADD hll a b c d e f g
 (integer) 1
 redis> PFCOUNT hll
 (integer) 7
 redis>
 */
#pragma mark PFADD
- (void) test_PFADD {
    [self test: @"PFADD"];
    const NSString* key = [self randomKey];

    [[[self.redis pfadd:key elements:@[@"a", @"b", @"c", @"d",  @"e",  @"f", @"g"]] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis pfcount:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @7);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> PFADD hll foo bar zap
 (integer) 1
 redis> PFADD hll zap zap zap
 (integer) 0
 redis> PFADD hll foo bar
 (integer) 0
 redis> PFCOUNT hll
 (integer) 3
 redis> PFADD some-other-hll 1 2 3
 (integer) 1
 redis> PFCOUNT hll some-other-hll
 (integer) 6
 redis>
 */
#pragma mark PFCOUNT
- (void) test_PFCOUNT {
    [self test: @"PFCOUNT"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    

    [[[[[[[self.redis pfadd:key1 elements:@[@"foo", @"bar", @"zap"]] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis pfadd:key1 elements:@[@"zap", @"zap", @"zap"]];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self.redis pfadd:key1 elements:@[@"foo", @"bar"]];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self.redis pfcount:key1];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @3);
        return [self.redis pfadd:key2 elements:@[@1, @2, @3]];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis pfcountKeys: @[key1, key2]];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @6);
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> PFADD hll1 foo bar zap a
 (integer) 1
 redis> PFADD hll2 a b c foo
 (integer) 1
 redis> PFMERGE hll3 hll1 hll2
 OK
 redis> PFCOUNT hll3
 (integer) 6
 redis>
 */
#pragma mark PFMERGE
- (void) test_PFMERGE {
    [self test: @"PFMERGE"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    const NSString* key3 = [self randomKey];
    
    [[[[[self.redis pfadd:key1 elements:@[@"foo", @"bar", @"zap", @"a"]] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis pfadd:key2 elements:@[@"a",@"b",@"c",@"foo"]];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis pfmerge:key3 sources:@[key1, key2]];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis pfcount:key3];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @6);
        return [self passed];
    }];
    
    [self wait];
}

@end
