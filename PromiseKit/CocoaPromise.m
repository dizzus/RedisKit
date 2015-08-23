//
//  CocoaPromise.m
//  CocoaPromise
//
//  Created by Дмитрий Бахвалов on 21.06.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import "CocoaPromise.h"


@implementation CocoaPromise

- (instancetype)init {
    self = [super init];
    if( self ) {
        _state = kCocoaPromisePendingState;
        _value = nil;
        _callbacks = [NSMutableArray new];
    }
    return self;
}

- (NSError *)reason {
    NSAssert(self.state == kCocoaPromiseRejectedState, @"CocoaPromise: promise is not rejected");
    NSAssert([self.value isKindOfClass: [NSError class]], @"CocoaPromise: invalid reason");
    return (NSError*) self.value;
}

- (void)fulfill:(id)value {
    NSAssert(self.state == kCocoaPromisePendingState, @"CocoaPromise: fulfilling already resolved promise: %p", self);
    resolve(self, value);
}

- (void)reject:(NSError *)err {
    NSAssert(self.state == kCocoaPromisePendingState, @"CocoaPromise: rejecting already resolved promise");
    [self transitToState: kCocoaPromiseRejectedState withValue: err];
}

- (instancetype) onFulfill: (id(^)(id))onFulfill onReject: (id(^)(NSError*))onReject {
    CocoaPromise* chainedPromise = [CocoaPromise new];
    
    dispatch_block_t block = ^{
        @try {
            id result = nil;
            switch( self.state ) {
                case kCocoaPromiseFulfilledState:
                    result = onFulfill ? onFulfill(self.value) : self.value;
                    break;
                case kCocoaPromiseRejectedState:
                    if( onReject ) result = onReject(self.value); else @throw self.value;
                    break;
                default:
                    NSAssert(NO, @"CocoaPromise: resolving a pending promise");
                    break;
            }
            resolve(chainedPromise, result);
        } @catch (NSError* err) {
            [chainedPromise transitToState: kCocoaPromiseRejectedState withValue: err];
        }
    };
    
    if( self.state != kCocoaPromisePendingState ) {
        dispatch_async([CocoaPromise sharedQueue], block);
    } else {
        [_callbacks addObject: block];
    }
    
    return chainedPromise;
}

- (instancetype)then:(id (^)(id))onFulfill {
    return [self onFulfill: onFulfill onReject: nil];
}

- (instancetype)catch:(id (^)(NSError *))onReject {
    return [self onFulfill: nil onReject: onReject];
}

+ (dispatch_queue_t)sharedQueue {
    static dispatch_queue_t sharedQueue = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedQueue = dispatch_queue_create("CocoaPromise serial queue", DISPATCH_QUEUE_SERIAL);
    });
    
    return sharedQueue;
}

- (void) transitToState: (CocoaPromiseState)newState withValue: (id)newValue {
    NSAssert(self.state == kCocoaPromisePendingState, @"CocoaPromise: already resolved");
    NSAssert(newState != kCocoaPromisePendingState, @"CocoaPromise: transiting into pending state");

    if( [newValue isKindOfClass: [NSError class]] ) newState = kCocoaPromiseRejectedState;
    
    _state = newState;
    _value = newValue;
    
    dispatch_queue_t queue = [CocoaPromise sharedQueue];
    
    for( dispatch_block_t block in _callbacks ) {
        dispatch_async(queue, block);
    }

    _callbacks = nil;
}

static void resolve(CocoaPromise* promise, id value) {
    NSCAssert(promise != value, @"CocoaPromise: resolving promise with self");
    
    if( [value isKindOfClass: [CocoaPromise class]] ) {
        CocoaPromise* otherPromise = (CocoaPromise*) value;
        
        if( otherPromise.state != kCocoaPromisePendingState )
            return [promise transitToState: otherPromise.state withValue: otherPromise.value];
        
        [otherPromise onFulfill: ^id (id value) {
            [promise fulfill: value];
            return value;
        } onReject: ^id (NSError* err) {
            [promise reject: err];
            return err;
        }];
    } else {
        [promise transitToState: kCocoaPromiseFulfilledState withValue: value];
    }
}

@end
