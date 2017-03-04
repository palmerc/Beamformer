import Foundation
import QuartzCore

extension VerasonicsFrameProcessorMetal
{
    func executionTimeInterval(block: () -> ()) -> CFTimeInterval {
        let start = CACurrentMediaTime()
        block();
        let end = CACurrentMediaTime()
        return end - start
    }
}
