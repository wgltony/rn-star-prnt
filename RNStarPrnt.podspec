
Pod::Spec.new do |s|
  s.name         = "RNStarPrnt"
  s.version      = "1.0.0"
  s.summary      = "RNStarPrnt"
  s.description  = <<-DESC
                  RNStarPrnt
                   DESC
  s.homepage     = "https://github.com/axelmarciano/rn-star-prnt"
  s.license      = "MIT"
  # s.license      = { :type => "MIT", :file => "FILE_LICENSE" }
  s.author             = { "author" => "author@domain.cn" }
  s.platform     = :ios, "9.0"
  s.source       = { :git => "https://github.com/axelmarciano/rn-star-prnt.git", :tag => "master" }
  s.source_files  = "ios/**/*.{h,m,mm}"
  s.requires_arc = true


  s.dependency "React"
  s.frameworks = 'CoreBluetooth', 'ExternalAccessory'
  s.vendored_frameworks = 'ios/Frameworks/StarIO/StarIO.xcframework', 'ios/Frameworks/StarIO_Extension/StarIO_Extension.xcframework'
  #s.dependency "others"

end

  