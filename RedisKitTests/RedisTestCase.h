//
//  RedisTestCase.h
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 31.07.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#import "CocoaRedis.h"

#define REDIS_ADDRESS @"localhost"

@interface RedisTestCase : XCTestCase

@property CocoaRedis* redis;
@property XCTestExpectation* test;

- (void) test: (NSString*)name;
- (CocoaPromise*) test: (NSString*)name requires: (NSString*)ver;
- (CocoaPromise*) passed;
- (void) wait;
- (NSString*)randomKey;

- (BOOL) isArray: (id)value;
- (BOOL) isDictionary: (id)value;
- (BOOL) isBulkStringReply: (id)value;

@end
