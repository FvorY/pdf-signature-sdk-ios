Pod::Spec.new do |s|
  s.name             = 'PdfSignatureSDK'
  s.version          = '0.0.0'
  s.summary          = 'Native iOS PDF viewer for placing signatures and E-Materai.'
  s.description      = <<-DESC
    Renders PDF documents and lets users place, drag, resize and remove
    signature and E-Materai (Indonesian electronic stamp duty) boxes.
    Returns positions in PDF points, identical to the web SDK
    pdf-signature-esign-sdk, so the same backend can complete the signing.
  DESC
  s.homepage         = 'https://github.com/FvorY/pdf-signature-sdk-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Muhammad Ferdy Cahya Pratama' => '38639406+FvorY@users.noreply.github.com' }
  s.source           = { :git => 'https://github.com/FvorY/pdf-signature-sdk-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '14.0'
  s.swift_versions   = ['5.9']

  s.source_files     = 'Sources/PdfSignatureSDK/**/*.swift'
  s.resource_bundles = { 'PdfSignatureSDK' => ['Sources/PdfSignatureSDK/Resources/**/*'] }
  s.frameworks       = 'UIKit', 'PDFKit'
end
