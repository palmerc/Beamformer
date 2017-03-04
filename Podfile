use_frameworks!

def common_pods()
    pod 'Zip', '~> 0.7'
    pod 'SocketRocket'
    pod 'SwiftProtobuf', '~> 0.9.903'

end

target 'SmartWave macOS' do
    platform :osx, '10.12'
    common_pods()
    pod 'HockeySDK-Mac' #, '~> 4.1.1'
end
 
target 'SmartWave iOS' do
    platform :ios, '10.0'
    common_pods()
    pod 'HockeySDK' #, '~> 4.1.1'
end

project 'SmartWave/SmartWave.xcodeproj'
