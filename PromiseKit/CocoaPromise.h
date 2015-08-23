//
//  CocoaPromise.h
//  CocoaPromise
//
//  Created by Дмитрий Бахвалов on 21.06.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, CocoaPromiseState) {
    kCocoaPromisePendingState,
    kCocoaPromiseFulfilledState,
    kCocoaPromiseRejectedState
};

@interface CocoaPromise : NSObject {
@private NSMutableArray* _callbacks;
}

@property (readonly) CocoaPromiseState state;
@property (readonly, strong) id value;
@property (readonly) NSError* reason;

- (instancetype) init;
- (instancetype) onFulfill: (id(^)(id value))onFulfill onReject: (id(^)(NSError* err))onReject;

- (instancetype) then: (id (^)(id value))onFulfill;
- (instancetype) catch: (id(^)(NSError* err))onReject;

- (void) fulfill: (id)value;
- (void) reject: (NSError*)err;

@end