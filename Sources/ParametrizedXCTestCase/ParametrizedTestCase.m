//
//  ParametrizedTestCase.m
//  SwiftletModelPerformanceTestSuite
//

#import <Foundation/Foundation.h>
#import "ParametrizedTestCase.h"

@interface _QuickSelectorWrapper ()
@property(nonatomic, assign) SEL selector;
@end

@implementation _QuickSelectorWrapper
- (instancetype)initWithSelector:(SEL)selector {
    self = [super init];
    _selector = selector;
    return self;
}
@end

@implementation ParametrizedTestCase

+ (NSArray<NSInvocation *> *)testInvocations {
    // Pull the selector list provided by the subclass and wrap each one in the
    // NSInvocation that XCTest expects to drive a test method.
    NSArray<_QuickSelectorWrapper *> *wrappers = [self _qck_testMethodSelectors];
    NSMutableArray<NSInvocation *> *invocations = [NSMutableArray arrayWithCapacity:wrappers.count];

    for (_QuickSelectorWrapper *wrapper in wrappers) {
        SEL selector = wrapper.selector;
        NSMethodSignature *signature = [self instanceMethodSignatureForSelector:selector];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.selector = selector;
        [invocations addObject:invocation];
    }

    return invocations;
}

+ (NSArray<_QuickSelectorWrapper *> *)_qck_testMethodSelectors {
    return @[];
}

@end
