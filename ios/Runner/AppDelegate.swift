import AuthenticationServices
import Flutter
import ObjectiveC
import UIKit
import UserNotifications

/// 아이패드에서 Apple 로그인 창의 기준 창이 없으면
/// AuthorizationError 1000이 나고 로그인 오류만 보인다.
final class RounderAppleSignInAnchor: NSObject, ASAuthorizationControllerPresentationContextProviding {
  static let shared = RounderAppleSignInAnchor()

  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for scene in scenes {
      if let window = scene.windows.first(where: { $0.isKeyWindow }) {
        return window
      }
    }
    if let window = scenes.lazy.compactMap({ $0.windows.first }).first {
      return window
    }
    if let scene = scenes.first {
      return UIWindow(windowScene: scene)
    }
    return UIWindow()
  }
}

extension ASAuthorizationController {
  static func rounderInstallIPadAnchor() {
    guard
      let original = class_getInstanceMethod(
        ASAuthorizationController.self,
        #selector(performRequests)
      ),
      let swizzled = class_getInstanceMethod(
        ASAuthorizationController.self,
        #selector(rounder_performRequests)
      )
    else { return }
    method_exchangeImplementations(original, swizzled)
  }

  @objc func rounder_performRequests() {
    if presentationContextProvider == nil {
      presentationContextProvider = RounderAppleSignInAnchor.shared
    }
    rounder_performRequests()
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    ASAuthorizationController.rounderInstallIPadAnchor()
    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
