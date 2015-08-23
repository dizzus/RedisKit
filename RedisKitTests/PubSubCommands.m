//
//  PubSubCommands.m
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 02.08.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import "RedisTestCase.h"

@interface PubSubCommands : RedisTestCase
@end

@implementation PubSubCommands

#pragma mark PSUBSCRIBE
- (void) test_PSUBSCRIBE {
    [self test: @"PSUBCRIBE"];
    
    __block id observer = nil;
    __block NSInteger helloCount = 0;

    NSString* channel1 = [[NSUUID UUID] UUIDString];
    NSString* channel2 = [[NSUUID UUID] UUIDString];

    NSString* pattern1 = [channel1 stringByAppendingString: @".*"];
    NSString* pattern2 = [channel2 stringByAppendingString: @".*"];

    CocoaRedis* listener = [CocoaRedis new];
    
    [[[[[[[listener connectWithHost: REDIS_ADDRESS] then:^id(id value) {
        return [listener psubscribePatterns: @[pattern1, pattern2]];
    }] then:^id(id value) {
        NSString* pat = value[@"pattern"];
        XCTAssertTrue( [pat isEqualToString:pattern1] || [pat isEqualToString:pattern2] );
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        observer = [center addObserverForName: CocoaRedisMessageNotification
                                       object: nil
                                        queue: nil
                                   usingBlock: ^(NSNotification *notification)
                    {
                        NSString* message = notification.userInfo[@"message"];
                        if( [message isEqualToString:@"Hello"] ) ++helloCount;
                    }];

        return [self.redis publish:[channel1 stringByAppendingString:@".a"] message:@"Hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        
        return [self.redis publish:[channel2 stringByAppendingString:@".b"] message:@"Hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [listener punsubscribe];
    }] then:^id(id value) {
        return [listener quit];
    }] then:^id(id value) {
        NSNotificationCenter *center;
        [center removeObserver: observer];

        XCTAssertEqual(helloCount, 2);
        return [self passed];
    }];

    [self waitForExpectationsWithTimeout:3 handler:nil];
}

#pragma mark PUBSUB
- (void) test_PUBSUB {
    [self test: @"PUBSUB"];
    
    NSString* channel = [[NSUUID UUID] UUIDString];
    NSString* pattern = [[[NSUUID UUID] UUIDString] stringByAppendingString: @".*"];
    
    CocoaRedis* listener = [CocoaRedis new];
    
    [[[[[[[[listener connectWithHost: REDIS_ADDRESS] then:^id(id value) {
        return [listener subscribe: channel];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value[@"channel"], channel);
        return [listener psubscribe: pattern];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value[@"pattern"], pattern);
        return [self.redis pubsubActiveChannels];
    }] then:^id(id value) {
        NSArray* expected = @[channel];
        XCTAssertEqualObjects(value, expected);
        return [self.redis pubsubSubscribers: @[channel]];
    }] then:^id(id value) {
        NSDictionary* expected = @{channel: @1};
        XCTAssertEqualObjects(value, expected);
        return [self.redis pubsubPatternsCount];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self passed];
    }] then:^id(id value) {
        return [listener quit];
    }];

    [self waitForExpectationsWithTimeout:3 handler:nil];
}

#pragma mark PUBLISH
- (void) test_PUBLISH {
    [self test: @"PUBLISH"];

    __block id observer = nil;
    __block NSInteger helloCount = 0;

    NSString* channel = [[NSUUID UUID] UUIDString];
    CocoaRedis* listener = [CocoaRedis new];
    
    [[[[[listener connectWithHost: REDIS_ADDRESS] then:^id(id value) {
        return [listener subscribe: channel];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value[@"channel"], channel);

        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        observer = [center addObserverForName: CocoaRedisMessageNotification
                                       object: nil
                                        queue: nil
                                   usingBlock: ^(NSNotification *notification)
                    {
                        NSString* message = notification.userInfo[@"message"];
                        if( [message isEqualToString:@"Hello"] ) ++helloCount;
                    }];
     
        return [self.redis publish:channel message:@"Hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis publish:channel message:@"Hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSNotificationCenter *center;
            [center removeObserver: observer];
            
            XCTAssertEqual(helloCount, 2);
            [self passed];
        });

        return [listener quit];
    }];

    [self waitForExpectationsWithTimeout:3 handler:nil];
}

#pragma mark PUNSUBSCRIBE
- (void) test_PUNSUBSCRIBE {
    [self test: @"PUNSUBSCRIBE"];

    NSString* pattern = [[[NSUUID UUID] UUIDString] stringByAppendingString: @".*"];
    CocoaRedis* listener = [CocoaRedis new];
    
    [[[[[[[listener connectWithHost: REDIS_ADDRESS] then:^id(id value) {
        return [listener psubscribe: pattern];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value[@"pattern"], pattern);
        return [self.redis pubsubPatternsCount];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [listener punsubscribe];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value[@"pattern"], pattern);
        return [self.redis pubsubPatternsCount];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self passed];
    }] then:^id(id value) {
        return [listener quit];
    }];

    [self waitForExpectationsWithTimeout:3 handler:nil];
}


#pragma mark SUBSCRIBE
- (void) test_SUBSCRIBE {
    [self test: @"SUBCRIBE"];
    
    __block id observer = nil;
    __block NSInteger count = 0;
    
    NSString* channel1 = [[NSUUID UUID] UUIDString];
    NSString* channel2 = [[NSUUID UUID] UUIDString];

    CocoaRedis* listener = [CocoaRedis new];
    
    [[[[[listener connectWithHost: REDIS_ADDRESS] then:^id(id value) {
        return [listener subscribeChannels: @[channel1, channel2]];
    }] then:^id(id value) {
        NSString* ch = value[@"channel"];
        XCTAssertTrue( [ch isEqualToString:channel1] || [ch isEqualToString:channel2] );

        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        observer = [center addObserverForName: CocoaRedisMessageNotification
                                       object: nil
                                        queue: nil
                                   usingBlock: ^(NSNotification *notification)
                    {
                        NSString* chn = notification.userInfo[@"channel"];
                        NSString* msg = notification.userInfo[@"message"];
                   
                        if( [chn isEqualToString:channel1] && [msg isEqualToString:@"Hello"] ) ++count;
                        if( [chn isEqualToString:channel2] && [msg isEqualToString:@"World"] ) ++count;
                    }];
    
        return [self.redis publish:channel1 message:@"Hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);

        return [self.redis publish:channel2 message:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            XCTAssertTrue(count == 2);

            NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
            [center removeObserver: observer];

            [self passed];
        });

        return [listener quit];
    }];

    [self waitForExpectationsWithTimeout:3 handler:nil];
}


#pragma mark UNSUBSCRIBE
- (void) test_UNSUBSCRIBE {
    [self test: @"UNSUBSCRIBE"];
    
    NSString* channel1 = [[NSUUID UUID] UUIDString];
    NSString* channel2 = [[NSUUID UUID] UUIDString];

    CocoaRedis* listener = [CocoaRedis new];
    
    [[[[[[[listener connectWithHost: REDIS_ADDRESS] then:^id(id value) {
        return [listener subscribeChannels: @[channel1, channel2]];
    }] then:^id(id value) {
        NSString* ch = value[@"channel"];
        XCTAssertTrue( [ch isEqualToString:channel1] || [ch isEqualToString:channel2] );
        
        return [self.redis pubsubActiveChannels];
    }] then:^id(id value) {
        NSSet* expected = [NSSet setWithArray: @[channel1, channel2]];
        XCTAssertTrue( [expected isSubsetOfSet: [NSSet setWithArray:value]] );
        
        return [listener unsubscribe];
    }] then:^id(id value) {
        NSString* ch = value[@"channel"];
        XCTAssertTrue( [ch isEqualToString:channel1] || [ch isEqualToString:channel2] );
        
        return [self.redis pubsubActiveChannels];
    }] then:^id(id value) {
        NSArray* expected = @[];
        XCTAssertEqualObjects(value, expected);
        
        return [self passed];
    }] then:^id(id value) {
        return [listener quit];
    }];

    [self waitForExpectationsWithTimeout:3 handler:nil];
}

@end
