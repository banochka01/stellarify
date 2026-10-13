import CarPlay
import Flutter
import UIKit

/// Bridges CarPlay templates to the Dart media catalog
/// (`lib/core/playback/carplay_bridge.dart`, channel `app.resonance/carplay`).
///
/// The scene itself is only declared in Info.plist when the app is built with
/// `RESONANCE_CARPLAY=1` (see `ios/CarPlay/README.md`): CarPlay audio apps need
/// the `com.apple.developer.carplay-audio` entitlement approved by Apple, which
/// an unsigned build cannot carry. Without that declaration this class is
/// compiled but never instantiated.
final class CarPlayBridge {
  static let shared = CarPlayBridge()
  private var channel: FlutterMethodChannel?
  private var pending: [(FlutterMethodChannel) -> Void] = []
  private var headlessEngine: FlutterEngine?

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.resonance/carplay", binaryMessenger: messenger)
    self.channel = channel
    let queued = pending
    pending.removeAll()
    queued.forEach { $0(channel) }
  }

  /// CarPlay cold start: the phone UI (and its implicit Flutter engine) may
  /// not exist. Queue the call and, if no window scene shows up shortly,
  /// run a headless engine so Dart can answer.
  private func withChannel(_ work: @escaping (FlutterMethodChannel) -> Void) {
    if let channel { return work(channel) }
    pending.append(work)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
      guard let self, self.channel == nil, self.headlessEngine == nil else { return }
      let hasWindowScene = UIApplication.shared.connectedScenes.contains { $0 is UIWindowScene }
      if hasWindowScene { return }
      let engine = FlutterEngine(name: "resonance-carplay")
      engine.run()
      GeneratedPluginRegistrant.register(with: engine)
      self.headlessEngine = engine
      self.attach(messenger: engine.binaryMessenger)
    }
  }

  func children(of parentId: String, completion: @escaping ([[String: Any]]) -> Void) {
    withChannel { channel in
      channel.invokeMethod("children", arguments: ["parentId": parentId]) { result in
        completion(result as? [[String: Any]] ?? [])
      }
    }
  }

  func play(mediaId: String, completion: @escaping () -> Void) {
    withChannel { channel in
      channel.invokeMethod("play", arguments: ["mediaId": mediaId]) { _ in completion() }
    }
  }
}

@available(iOS 14.0, *)
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
  private var interfaceController: CPInterfaceController?

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController
  ) {
    self.interfaceController = interfaceController
    let root = CPListTemplate(title: "Resonance", sections: [])
    interfaceController.setRootTemplate(root, animated: false, completion: nil)
    loadList(parentId: "root", into: root)
  }

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didDisconnect interfaceController: CPInterfaceController
  ) {
    self.interfaceController = nil
  }

  private func loadList(parentId: String, into template: CPListTemplate) {
    CarPlayBridge.shared.children(of: parentId) { [weak self] nodes in
      guard let self else { return }
      let items: [CPListItem] = nodes.compactMap { node in
        guard let id = node["id"] as? String, let title = node["title"] as? String else {
          return nil
        }
        let item = CPListItem(text: title, detailText: node["subtitle"] as? String)
        let playable = node["playable"] as? Bool ?? false
        if !playable { item.accessoryType = .disclosureIndicator }
        item.handler = { [weak self] _, completion in
          if playable {
            CarPlayBridge.shared.play(mediaId: id) {
              self?.interfaceController?.pushTemplate(
                CPNowPlayingTemplate.shared, animated: true, completion: nil)
              completion()
            }
          } else {
            let child = CPListTemplate(title: title, sections: [])
            self?.interfaceController?.pushTemplate(child, animated: true, completion: nil)
            self?.loadList(parentId: id, into: child)
            completion()
          }
        }
        return item
      }
      template.updateSections([CPListSection(items: items)])
    }
  }
}
