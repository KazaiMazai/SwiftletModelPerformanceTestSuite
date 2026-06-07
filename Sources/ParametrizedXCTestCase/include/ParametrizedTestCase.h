//
//  ParametrizedTestCase.h
//  RealmVsSwiftDataBenchmarks
//
//  Runtime-generated parametrized XCTest cases.
//  XCTest has no native parametrization, so we override the list of test
//  invocations and synthesise one `test_<name>_<size>` method per parameter.
//

#ifndef ParametrizedTestCase_h
#define ParametrizedTestCase_h

#import <XCTest/XCTest.h>

/// `SEL` is a pointer to a C struct, so it cannot live inside an `NSArray`
/// directly. This wraps it so subclasses can return an array of selectors.
@interface _QuickSelectorWrapper : NSObject
- (instancetype)initWithSelector:(SEL)selector;
@end

@interface ParametrizedTestCase : XCTestCase
/// List of test selectors to run. Base implementation returns nothing;
/// subclasses override to register their parametrized methods.
+ (NSArray<_QuickSelectorWrapper *> *)_qck_testMethodSelectors;
@end

#endif /* ParametrizedTestCase_h */
