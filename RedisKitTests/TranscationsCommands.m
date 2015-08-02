//
//  TranscationsCommands.m
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 31.07.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import "RedisTestCase.h"

@interface TranscationsCommands : RedisTestCase
@end

@implementation TranscationsCommands

#pragma mark DISCARD
- (void) test_DISCARD {
    [self test:@"DISCARD"];

    [[[self.redis multi] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis discard];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark EXEC
- (void) test_EXEC {
    [self test:@"EXEC"];
    const NSString* key1 = [self randomKey];
    const NSString* key2 = [self randomKey];
    const NSString* key3 = [self randomKey];
    
    [[[[[[[[self.redis multi] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis set:key1 value:@"Hello"];
    }] then:^id(id value) {
        return [self.redis set:key2 value:@"There"];
    }] then:^id(id value) {
        return [self.redis set:key3 value:@"World"];
    }] then:^id(id value) {
        return [self.redis del:key2];
    }] then:^id(id value) {
        return [self.redis mget:@[key1, key2, key3]];
    }] then:^id(id value) {
        return [self.redis exec];
    }] then:^id(id value) {
        NSArray* expected = @[@"OK",@"OK",@"OK",@1, @[@"Hello", [NSNull null], @"World"]];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark MULTI
- (void) test_MULTI {
    [self test:@"MULTI"];
    
    [[self.redis multi] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark UNWATCH
- (void) test_UNWATCH {
    [self test:@"UNWATCH"];
    
    [[[self.redis multi] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis unwatch];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"QUEUED");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark WATCH
- (void) test_WATCH {
    [self test:@"WATCH"];
    [self passed];
    [self wait];
}


@end
