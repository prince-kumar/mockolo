import Foundation

class NonSimpleVarTests: MockoloTestCase {
    
    func testSubscripts() {
        verify(srcContent: subscripts,
               dstContent: subscriptsMocks,
               parser: .swiftSyntax)
    }
    

    func testNonSimpleVars() {
        verify(srcContent: nonSimpleVars,
               dstContent: nonSimpleVarsMock)
    }
    
    func testRxVar() {
        verify(srcContent: rxVar,
               dstContent: rxVarMock,
               concurrencyLimit: nil)
    }

    func testRxVarInherited() {
        verify(srcContent: rxVarInherited,
               dstContent: rxVarInheritedMock,
               concurrencyLimit: nil)
    }

    func testRxVarBehavior() {
        verify(srcContent: rxVarBehavior,
               dstContent: rxVarBehaviorMock,
               concurrencyLimit: nil)
    }

    func testVariadicFuncs() {
        verify(srcContent: variadicFunc,
               dstContent: variadicFuncMock,
               concurrencyLimit: nil)
    }

    func testAutoclosureArgFuncs() {
        verify(srcContent: autoclosureArgFunc,
               dstContent: autoclosureArgFuncMock,
               concurrencyLimit: nil)
    }

    func testClosureArgFuncs() {
        verify(srcContent: closureArgFunc,
               dstContent: closureArgFuncMock,
               concurrencyLimit: nil)
    }

    func testForArgFuncs() {
        verify(srcContent: forArgClosureFunc,
               dstContent: forArgClosureFuncMock,
               concurrencyLimit: nil)
    }
}
