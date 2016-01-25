import XCTest
@testable import Beamformer
import ObjectMapper



class BeamformerTests: XCTestCase
{
    private var verasonicsProcessor: VerasonicsDelay?
    private var verasonicsFrame: VerasonicsFrame?

    private var complexVector: [[Complex<Double>]]?
    private var complexImageVector: [Complex<Double>]?
    private var imageAmplitudes: [UInt8]?
    
    override func setUp()
    {
        super.setUp()

        self.verasonicsProcessor = VerasonicsDelay(withDelays: VerasonicsDelay.defaultDelays)

        var frameJSON: String?
        let bundle = NSBundle(forClass: self.dynamicType)
        let URL = bundle.URLForResource("VerasonicsFrame", withExtension: "json")
        let path = URL?.path
        if (path != nil && NSFileManager().fileExistsAtPath(path!)) {
            do {
                let frameData = try NSData(contentsOfURL: URL!, options: .DataReadingMappedIfSafe)
                frameJSON = String(data: frameData, encoding: NSUTF8StringEncoding)
            } catch let error as NSError {
                print ("Error: \(error.localizedDescription)")
            }
        }

        var token: dispatch_once_t = 0
        dispatch_once(&token) { () -> Void in
            self.processVerasonicsFrame(frameJSON)
        }
    }

    override func tearDown()
    {
        super.tearDown()
    }

    func processVerasonicsFrame(frameJSON: String?)
    {
        let executionTime = self.executionTimeInterval {
            self.verasonicsFrame = Mapper<VerasonicsFrame>().map(frameJSON)
            self.complexVector = (self.verasonicsProcessor?.IQDataWithVerasonicsFrame(self.verasonicsFrame))!
            self.complexImageVector = self.verasonicsProcessor?.complexImageVectorWithIQData(self.complexVector, width: self.verasonicsProcessor!.imageXPixelCount, height: self.verasonicsProcessor!.imageZPixelCount)
            self.imageAmplitudes = self.verasonicsProcessor?.imageAmplitudesFromComplexImageVector(self.complexImageVector)
        }

        print("Execution time: \(executionTime) seconds")
    }

    func executionTimeInterval(block: () -> ()) -> CFTimeInterval
    {
        let start = CACurrentMediaTime()
        block();
        let end = CACurrentMediaTime()
        return end - start
    }
    
    func testIQDataWithVerasonicsFrame()
    {
        XCTAssertEqual(self.complexVector![60][200], Complex<Double>(-53.0+21.0.i))
        XCTAssertEqual(self.complexVector![60][201], Complex<Double>(9.0+5.0.i))
        XCTAssertEqual(self.complexVector![60][202], Complex<Double>(11.0+1.0.i))

        XCTAssertEqual(self.complexVector![61][200], Complex<Double>(0.0+14.0.i))
        XCTAssertEqual(self.complexVector![61][201], Complex<Double>(-23.0-6.0.i))
        XCTAssertEqual(self.complexVector![61][202], Complex<Double>(-15.0+11.0.i))

        XCTAssertEqual(self.complexVector![62][200], Complex<Double>(34.0+31.0.i))
        XCTAssertEqual(self.complexVector![62][201], Complex<Double>(13.0+2.0.i))
        XCTAssertEqual(self.complexVector![62][202], Complex<Double>(11.0-16.0.i))
    }

    func testComplexImageVectorWithIQData()
    {
        let complexImageVector2030Real = trunc(self.complexImageVector![2030].real)
        let complexImageVector2030Imaginary = trunc(self.complexImageVector![2030].imag)
        XCTAssertEqual(complexImageVector2030Real, 77.0)
        XCTAssertEqual(complexImageVector2030Imaginary, 281.0)

        let complexImageVector3050Real = trunc(self.complexImageVector![3050].real)
        let complexImageVector3050Imaginary = trunc(self.complexImageVector![3050].imag)
        XCTAssertEqual(complexImageVector3050Real, 205.0)
        XCTAssertEqual(complexImageVector3050Imaginary, -5.0)

        let complexImageVector8650Real = trunc(self.complexImageVector![8650].real)
        let complexImageVector8650Imaginary = trunc(self.complexImageVector![8650].imag)
        XCTAssertEqual(complexImageVector8650Real, -397.0)
        XCTAssertEqual(complexImageVector8650Imaginary, -808.0)
    }

    func testImageAmplitudesFromComplexImageVector()
    {
        XCTAssertEqual(self.imageAmplitudes![1], 12)
        XCTAssertEqual(self.imageAmplitudes![10], 56)
        XCTAssertEqual(self.imageAmplitudes![100], 38)
        XCTAssertEqual(self.imageAmplitudes![1111], 95)
        XCTAssertEqual(self.imageAmplitudes![10000], 37)
        XCTAssertEqual(self.imageAmplitudes![100000], 84)
        XCTAssertEqual(self.imageAmplitudes![100001], 85)
        XCTAssertEqual(self.imageAmplitudes![100010], 30)
        XCTAssertEqual(self.imageAmplitudes![100100], 23)
        XCTAssertEqual(self.imageAmplitudes![101000], 67)
        XCTAssertEqual(self.imageAmplitudes![110100], 33)
    }
}
