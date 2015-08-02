//
//  BasicTests.m
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 25.07.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#import "CocoaRedis.h"

@interface BasicTests : XCTestCase

@end

@implementation BasicTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_Connect {
    XCTestExpectation* test = [self expectationWithDescription: @"Open connection test"];

    CocoaRedis* redis = [CocoaRedis new];
    [[[redis connectWithHost: @"localhost"] then:^id(id value) {
        XCTAssertTrue(redis.isConnected);
        [test fulfill];
        return [redis close];
    }] then:^id(id value) {
        return nil;
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_Close {
    XCTestExpectation* test = [self expectationWithDescription: @"Close connection test"];
    
    CocoaRedis* redis = [CocoaRedis new];
    [[[redis connectWithHost: @"localhost"] then:^id(id value) {
        return [redis close];
    }] then:^id(id value) {
        XCTAssertTrue(!redis.isConnected);
        [test fulfill];
        return nil;
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void) test_Version {
    XCTestExpectation* test = [self expectationWithDescription: @"Version test"];
    
    CocoaRedis* redis = [CocoaRedis new];
    [[[redis connectWithHost: @"localhost"] then:^id(id value) {
        return [redis version];
    }] then:^id(id value) {
        XCTAssertNotNil(value);
        [test fulfill];
        return nil;
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}


@end
