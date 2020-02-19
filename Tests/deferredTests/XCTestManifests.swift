#if !canImport(ObjectiveC)
import XCTest

extension AlignmentTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__AlignmentTests = [
        ("testAlignmentOfPointerToSmallResult", testAlignmentOfPointerToSmallResult),
        ("testAlignmentOfRawPointer", testAlignmentOfRawPointer),
    ]
}

extension DeferredCombinationTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__DeferredCombinationTests = [
        ("testCombine", testCombine),
        ("testCombine2", testCombine2),
        ("testCombine3", testCombine3),
        ("testCombine4", testCombine4),
        ("testCombineCancel", testCombineCancel),
        ("testReduce", testReduce),
        ("testReduceCancel", testReduceCancel),
    ]
}

extension DeferredCombinationTimedTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__DeferredCombinationTimedTests = [
        ("testPerformanceABAProneReduce", testPerformanceABAProneReduce),
        ("testPerformanceCombine", testPerformanceCombine),
        ("testPerformanceReduce", testPerformanceReduce),
    ]
}

extension DeferredExamples {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__DeferredExamples = [
        ("testBigComputation", testBigComputation),
        ("testExample", testExample),
        ("testExample2", testExample2),
        ("testExample3", testExample3),
    ]
}

extension DeferredExtrasTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__DeferredExtrasTests = [
        ("testApply", testApply),
        ("testCancelApply", testCancelApply),
        ("testCancelFlatMap", testCancelFlatMap),
        ("testCancelMap", testCancelMap),
        ("testCancelRecover", testCancelRecover),
        ("testEnqueuing", testEnqueuing),
        ("testExecute", testExecute),
        ("testFlatMap", testFlatMap),
        ("testFlatMapError", testFlatMapError),
        ("testFlatten1", testFlatten1),
        ("testFlatten2", testFlatten2),
        ("testMap", testMap),
        ("testMapError", testMapError),
        ("testOnErrorNever", testOnErrorNever),
        ("testOnValueAndOnError", testOnValueAndOnError),
        ("testOptional", testOptional),
        ("testQoS", testQoS),
        ("testRecover1", testRecover1),
        ("testRecover2", testRecover2),
        ("testRetrying1", testRetrying1),
        ("testRetrying2", testRetrying2),
        ("testSplit", testSplit),
        ("testTryFlatMap", testTryFlatMap),
        ("testTryMap", testTryMap),
        ("testValidate1", testValidate1),
        ("testValidate2", testValidate2),
    ]
}

extension DeferredSelectionTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__DeferredSelectionTests = [
        ("testFirstResolvedCollection", testFirstResolvedCollection),
        ("testFirstResolvedEmptyCollection", testFirstResolvedEmptyCollection),
        ("testFirstResolvedEmptySequence", testFirstResolvedEmptySequence),
        ("testFirstResolvedSequence", testFirstResolvedSequence),
        ("testFirstValueCollection", testFirstValueCollection),
        ("testFirstValueCollectionError", testFirstValueCollectionError),
        ("testFirstValueEmptyCollection", testFirstValueEmptyCollection),
        ("testFirstValueEmptySequence", testFirstValueEmptySequence),
        ("testFirstValueSequence", testFirstValueSequence),
        ("testFirstValueSequenceError", testFirstValueSequenceError),
        ("testSelectFirstResolvedBinary", testSelectFirstResolvedBinary),
        ("testSelectFirstResolvedQuaternary", testSelectFirstResolvedQuaternary),
        ("testSelectFirstResolvedTernary", testSelectFirstResolvedTernary),
        ("testSelectFirstValueBinary1", testSelectFirstValueBinary1),
        ("testSelectFirstValueBinary2", testSelectFirstValueBinary2),
        ("testSelectFirstValueMemoryRelease", testSelectFirstValueMemoryRelease),
        ("testSelectFirstValueQuaternary1", testSelectFirstValueQuaternary1),
        ("testSelectFirstValueQuaternary2", testSelectFirstValueQuaternary2),
        ("testSelectFirstValueRetainMemory", testSelectFirstValueRetainMemory),
        ("testSelectFirstValueTernary1", testSelectFirstValueTernary1),
        ("testSelectFirstValueTernary2", testSelectFirstValueTernary2),
    ]
}

extension DeferredTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__DeferredTests = [
        ("testBeginExecution", testBeginExecution),
        ("testCancel", testCancel),
        ("testError", testError),
        ("testErrorTypes", testErrorTypes),
        ("testGet", testGet),
        ("testNotify", testNotify),
        ("testNotifyWaiters", testNotifyWaiters),
        ("testPeek", testPeek),
        ("testState", testState),
        ("testValue", testValue),
        ("testValueBlocks", testValueBlocks),
        ("testValueUnblocks", testValueUnblocks),
    ]
}

extension DeferredTimeoutTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__DeferredTimeoutTests = [
        ("testTimeout1", testTimeout1),
        ("testTimeout2", testTimeout2),
        ("testTimeout3", testTimeout3),
    ]
}

extension DeferredTimingTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__DeferredTimingTests = [
        ("testPerformanceNotificationCreationTime", testPerformanceNotificationCreationTime),
        ("testPerformanceNotificationExecutionTime", testPerformanceNotificationExecutionTime),
        ("testPerformancePropagationTime", testPerformancePropagationTime),
    ]
}

extension DelayTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__DelayTests = [
        ("testCancelDelay", testCancelDelay),
        ("testDelayError", testDelayError),
        ("testDelayToThePast", testDelayToThePast),
        ("testDelayValue", testDelayValue),
        ("testDistantFutureDelay", testDistantFutureDelay),
        ("testSourceSlowerThanDelay", testSourceSlowerThanDelay),
    ]
}

extension DeletionTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__DeletionTests = [
        ("testDeallocTBD1", testDeallocTBD1),
        ("testDeallocTBD2", testDeallocTBD2),
        ("testDeallocTBD3", testDeallocTBD3),
        ("testDeallocTBD4", testDeallocTBD4),
        ("testDelayedDeallocDeferred", testDelayedDeallocDeferred),
        ("testLongTaskCancellation1", testLongTaskCancellation1),
        ("testLongTaskCancellation2", testLongTaskCancellation2),
    ]
}

extension ParallelTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__ParallelTests = [
        ("testParallel1", testParallel1),
        ("testParallel2", testParallel2),
        ("testParallel3", testParallel3),
        ("testParallel4", testParallel4),
    ]
}

extension ResolverTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__ResolverTests = [
        ("testCancel", testCancel),
        ("testNeverResolved", testNeverResolved),
        ("testNotify", testNotify),
        ("testResolve1", testResolve1),
        ("testResolve2", testResolve2),
        ("testResolverWithoutDeferred", testResolverWithoutDeferred),
    ]
}

extension ResultWrapperTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__ResultWrapperTests = [
        ("testAccessors", testAccessors),
        ("testGet", testGet),
    ]
}

public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(AlignmentTests.__allTests__AlignmentTests),
        testCase(DeferredCombinationTests.__allTests__DeferredCombinationTests),
        testCase(DeferredCombinationTimedTests.__allTests__DeferredCombinationTimedTests),
        testCase(DeferredExamples.__allTests__DeferredExamples),
        testCase(DeferredExtrasTests.__allTests__DeferredExtrasTests),
        testCase(DeferredSelectionTests.__allTests__DeferredSelectionTests),
        testCase(DeferredTests.__allTests__DeferredTests),
        testCase(DeferredTimeoutTests.__allTests__DeferredTimeoutTests),
        testCase(DeferredTimingTests.__allTests__DeferredTimingTests),
        testCase(DelayTests.__allTests__DelayTests),
        testCase(DeletionTests.__allTests__DeletionTests),
        testCase(ParallelTests.__allTests__ParallelTests),
        testCase(ResolverTests.__allTests__ResolverTests),
        testCase(ResultWrapperTests.__allTests__ResultWrapperTests),
    ]
}
#endif
