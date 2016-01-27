import XCTest
@testable import Beamformer
import ObjectMapper



class BeamformerTests: XCTestCase
{
    private var verasonicsProcessor: VerasonicsFrameProcessor?
    private var verasonicsFrame: VerasonicsFrame?

    private var elementIQData: [ChannelData]?
    private var complexImageVector: ChannelData?
    private var imageAmplitudes: [UInt8]?
    
    override func setUp()
    {
        super.setUp()

        self.verasonicsProcessor = VerasonicsFrameProcessor(withDelays: VerasonicsFrameProcessor.defaultDelays)

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

        self.processVerasonicsFrame(frameJSON)
    }

    override func tearDown()
    {
        super.tearDown()
    }

    func processVerasonicsFrame(frameJSON: String?)
    {
        let executionTime = self.executionTimeInterval {
            self.verasonicsFrame = Mapper<VerasonicsFrame>().map(frameJSON)
            self.elementIQData = (self.verasonicsProcessor?.IQDataWithVerasonicsFrame(self.verasonicsFrame))!
            self.complexImageVector = self.verasonicsProcessor?.complexImageVectorWithIQData(self.elementIQData, width: self.verasonicsProcessor!.imageXPixelCount, height: self.verasonicsProcessor!.imageZPixelCount)
            self.imageAmplitudes = self.verasonicsProcessor?.imageAmplitudesFromComplexImageVector(self.complexImageVector, width: self.verasonicsProcessor!.imageXPixelCount, height: self.verasonicsProcessor!.imageZPixelCount)
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

    func testAAAComplexImageVectorForElement()
    {

    }

    func testIQDataWithVerasonicsFrame()
    {
        XCTAssertEqual(self.elementIQData![60].complexIQVector[200], Complex<Double>(-53.0+21.0.i))
        XCTAssertEqual(self.elementIQData![60].complexIQVector[201], Complex<Double>(9.0+5.0.i))
        XCTAssertEqual(self.elementIQData![60].complexIQVector[202], Complex<Double>(11.0+1.0.i))

        XCTAssertEqual(self.elementIQData![61].complexIQVector[200], Complex<Double>(0.0+14.0.i))
        XCTAssertEqual(self.elementIQData![61].complexIQVector[201], Complex<Double>(-23.0-6.0.i))
        XCTAssertEqual(self.elementIQData![61].complexIQVector[202], Complex<Double>(-15.0+11.0.i))

        XCTAssertEqual(self.elementIQData![62].complexIQVector[200], Complex<Double>(34.0+31.0.i))
        XCTAssertEqual(self.elementIQData![62].complexIQVector[201], Complex<Double>(13.0+2.0.i))
        XCTAssertEqual(self.elementIQData![62].complexIQVector[202], Complex<Double>(11.0-16.0.i))
    }

    func testComplexImageVectorWithIQData()
    {
        let complexImageVector2030Real = trunc(self.complexImageVector!.real[2030])
        let complexImageVector2030Imaginary = trunc(self.complexImageVector!.imaginary[2030])
        XCTAssertEqual(complexImageVector2030Real, 77.0)
        XCTAssertEqual(complexImageVector2030Imaginary, 281.0)

        let complexImageVector3050Real = trunc(self.complexImageVector!.real[3050])
        let complexImageVector3050Imaginary = trunc(self.complexImageVector!.imaginary[3050])
        XCTAssertEqual(complexImageVector3050Real, 205.0)
        XCTAssertEqual(complexImageVector3050Imaginary, -5.0)

        let complexImageVector8650Real = trunc(self.complexImageVector!.real[8650])
        let complexImageVector8650Imaginary = trunc(self.complexImageVector!.imaginary[8650])
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
