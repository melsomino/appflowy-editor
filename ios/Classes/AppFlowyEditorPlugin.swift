import Flutter
import UIKit
import UniformTypeIdentifiers

public final class AppFlowyEditorPlugin: NSObject, FlutterPlugin {
  private let registrar: FlutterPluginRegistrar
  private var activeMenu: AnyObject?

  private init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "appflowy_editor/selection_menu", binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(AppFlowyEditorPlugin(registrar: registrar), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "readClipboard" {
      result(EditorClipboard.read())
      return
    }
    guard #available(iOS 16.0, *) else {
      result(FlutterError(code: "unsupported_ios", message: "Native menus require iOS 16", details: nil))
      return
    }
    guard let arguments = call.arguments as? [String: Any],
      let session = arguments["session"] as? Int
    else {
      result(FlutterError(code: "invalid_menu", message: "Missing menu session", details: nil))
      return
    }
    switch call.method {
    case "show":
      guard let view = registrar.viewController?.view,
        let rect = arguments["anchor"] as? [Double], rect.count == 4,
        let items = arguments["items"] as? [[String: String]],
        items.allSatisfy({ $0["title"] != nil && $0["type"] != nil })
      else {
        result(FlutterError(code: "invalid_menu", message: "Missing view or menu items", details: nil))
        return
      }
      (activeMenu as? EditorSelectionMenu)?.cancel()
      let menu = EditorSelectionMenu(
        session: session, view: view,
        anchor: CGRect(x: rect[0], y: rect[1], width: rect[2], height: rect[3]),
        items: items, result: result
      )
      activeMenu = menu
      menu.show()
    case "hide":
      if let menu = activeMenu as? EditorSelectionMenu, menu.session == session {
        menu.cancel()
        activeMenu = nil
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

@available(iOS 16.0, *)
private final class EditorSelectionMenu: NSObject, UIEditMenuInteractionDelegate {
  let session: Int
  private weak var view: UIView?
  private let anchor: CGRect
  private let items: [[String: String]]
  private var result: FlutterResult?
  private var selected: [String: Any]?
  private lazy var interaction = UIEditMenuInteraction(delegate: self)

  init(session: Int, view: UIView, anchor: CGRect, items: [[String: String]],
       result: @escaping FlutterResult) {
    self.session = session
    self.view = view
    self.anchor = anchor
    self.items = items
    self.result = result
  }

  func show() {
    view?.addInteraction(interaction)
    interaction.presentEditMenu(with: UIEditMenuConfiguration(
      identifier: NSNumber(value: session), sourcePoint: CGPoint(x: anchor.midX, y: anchor.minY)
    ))
  }

  func cancel() {
    interaction.dismissMenu()
    finish(nil)
  }

  private func finish(_ selection: [String: Any]?) {
    guard let callback = result else { return }
    result = nil
    view?.removeInteraction(interaction)
    callback(selection)
  }

  func editMenuInteraction(_ interaction: UIEditMenuInteraction,
                          menuFor configuration: UIEditMenuConfiguration,
                          suggestedActions: [UIMenuElement]) -> UIMenu? {
    UIMenu(children: items.enumerated().map { index, item in
      let isPaste = item["type"] == "paste"
      // UIKit recognizes this identifier as an explicit user paste action.
      // Read HTML here, while that permission is active, rather than in Dart.
      return UIAction(title: item["title"]!, identifier: isPaste ? .paste : nil) { [weak self] _ in
        guard let self = self else { return }
        var selection: [String: Any] = ["index": index]
        if isPaste {
          selection["clipboard"] = EditorClipboard.read()
        }
        self.selected = selection
      }
    })
  }

  func editMenuInteraction(_ interaction: UIEditMenuInteraction,
                          targetRectFor configuration: UIEditMenuConfiguration) -> CGRect {
    anchor
  }

  func editMenuInteraction(_ interaction: UIEditMenuInteraction,
                          willDismissMenuFor configuration: UIEditMenuConfiguration,
                          animator: UIEditMenuInteractionAnimating) {
    animator.addCompletion { [weak self] in
      guard let self = self else { return }
      self.finish(self.selected)
    }
  }

}

private enum EditorClipboard {
  static func read() -> [String: Any] {
    let pasteboard = UIPasteboard.general
    var data: [String: Any] = [:]
    if let text = pasteboard.string { data["text"] = text }
    if let html = pasteboard.value(forPasteboardType: UTType.html.identifier) as? String {
      data["html"] = html
    } else if let bytes = pasteboard.data(forPasteboardType: UTType.html.identifier),
      let html = String(data: bytes, encoding: .utf8) {
      data["html"] = html
    }
    var images: [[String: Any]] = []
    for type in ["com.apple.webarchive", "Apple Web Archive pasteboard type"] {
      guard let archive = pasteboard.data(forPasteboardType: type) else { continue }
      do {
        if let contents = try PropertyListSerialization.propertyList(
          from: archive, options: [], format: nil
        ) as? [String: Any] {
          collectArchiveImages(contents, into: &images)
        }
      } catch {
        // Preserve text/HTML and report corrupt archive data to the caller.
        data["archiveError"] = error.localizedDescription
      }
      break
    }
    // A copied image or photo may have no HTML representation at all.
    if images.isEmpty {
      for image in pasteboard.images ?? [] {
        if let bytes = image.pngData() {
          images.append(["bytes": FlutterStandardTypedData(bytes: bytes)])
        }
      }
    }
    if !images.isEmpty { data["images"] = images }
    return data
  }

  private static func collectArchiveImages(_ archive: [String: Any],
                                           into images: inout [[String: Any]]) {
    var resources = archive["WebSubresources"] as? [[String: Any]] ?? []
    if let main = archive["WebMainResource"] as? [String: Any] { resources.append(main) }
    for resource in resources {
      guard let mime = resource["WebResourceMIMEType"] as? String,
        mime.hasPrefix("image/"), let bytes = resource["WebResourceData"] as? Data
      else { continue }
      var image: [String: Any] = ["bytes": FlutterStandardTypedData(bytes: bytes)]
      if let source = resource["WebResourceURL"] as? String { image["source"] = source }
      images.append(image)
    }
    for frame in archive["WebSubframeArchives"] as? [[String: Any]] ?? [] {
      collectArchiveImages(frame, into: &images)
    }
  }
}
