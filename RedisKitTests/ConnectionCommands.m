//
//  ConnectionCommands.m
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 30.07.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import "RedisTestCase.h"

@interface ConnectionCommands : RedisTestCase
@end

@implementation ConnectionCommands

/*
 redis> ECHO "Hello World!"
 "Hello World!"
 redis>
 */
#pragma mark ECHO
- (void) test_ECHO {
    [self test: @"ECHO"];

    [[self.redis echo:@"Hello World!"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"Hello World!");
        return [self passed];
    }];
    
    [self wait];
}

/*
 redis> PING
 PONG
 redis>
 */
#pragma mark PING
- (void) test_PING {
    [self test: @"PING"];
    
    [[self.redis ping] then:^id(id value) {
        XCTAssertEqualObjects(value, @"PONG");
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark QUIT
- (void) test_QUIT {
    [self test: @"QUIT"];

    [[[self.redis quit] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis ping];
    }] onFulfill:^id(id value) {
        XCTAssert(NO, @"Should not get here");
        return nil;
    } onReject:^id(NSError *err) {
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark SELECT
- (void) test_SELECT {
    [self test: @"SELECT"];
    const NSString* key = [self randomKey];

    [[[[[[self.redis set:key value:@"Hello"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis select:0];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis get:key];
    }] then:^id(id value) {
        XCTAssertTrue( [value isKindOfClass:[NSNull class]] );
        return [self.redis select:15];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis get:key];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"Hello");
        return [self passed];
    }];
    
    [self wait];
}


@end
