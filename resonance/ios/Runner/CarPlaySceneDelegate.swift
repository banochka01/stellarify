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

  func attach(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "app.resonance/carplay", binaryMessenger: messenger)
  }

  func children(of parentId: String, completion: @escaping ([[String: Any]]) -> Void) {
    guard let channel else { return completion([]) }
    channel.invokeMethod("children", arguments: ["parentId": parentId]) { result in
      completion(result as? [[String: Any]] ?? [])
    }
  }

  func play(mediaId: String, completion: @escaping () -> Void) {
    guard let channel else { return completion() }
    channel.invokeMethod("play", arguments: ["mediaId": mediaId]) { _ in completion() }
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
