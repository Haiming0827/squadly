import SwiftUI
import UIKit
import WidgetKit
import SquadlyWidgetCore

private let widgetKind = "SquadPhotoWidget"

struct SquadPhotoEntry: TimelineEntry {
  let date: Date
  let manifest: WidgetManifest
  let unavailable: Bool
  var state: WidgetDisplayState { unavailable ? .unavailable : manifest.state(at: WidgetClock()) }
}

struct SquadPhotoProvider: TimelineProvider {
  func placeholder(in context: Context) -> SquadPhotoEntry {
    SquadPhotoEntry(date: Date(), manifest: WidgetManifest(), unavailable: false)
  }
  func getSnapshot(in context: Context, completion: @escaping (SquadPhotoEntry) -> Void) {
    completion(context.isPreview ? placeholder(in: context) : load())
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<SquadPhotoEntry>) -> Void) {
    let entry = load()
    var entries = [entry]
    if entry.state == .photo, let expiry = entry.manifest.photo?.expiresAt, expiry > entry.date {
      var expired = entry.manifest; expired.photo = nil; expired.hasExpiredPhoto = true
      entries.append(SquadPhotoEntry(date: expiry, manifest: expired, unavailable: false))
    }
    // App/remote events request new timelines. The scheduled expired entry
    // never contains pixels; request acceptance is not proof of desktop paint.
    completion(Timeline(entries: entries, policy: .never))
  }
  private func load() -> SquadPhotoEntry {
    guard let group = Bundle.main.object(forInfoDictionaryKey: "SquadlyWidgetAppGroup") as? String,
          let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group),
          let manifest = try? WidgetStore(directory: directory).read() else {
      return SquadPhotoEntry(date: Date(), manifest: WidgetManifest(), unavailable: true)
    }
    return SquadPhotoEntry(date: Date(), manifest: manifest, unavailable: false)
  }
}

struct SquadPhotoView: View {
  let entry: SquadPhotoEntry
  private let brand = Color(red: 252/255, green: 102/255, blue: 52/255)
  private var label: String {
    switch entry.state {
    case .unconfigured: return "在 App 中绑定小队"
    case .signedOut: return "联网登录后更新"
    case .hidden: return "照片预览已隐藏"
    case .empty: return "小队还没有照片"
    case .unavailable: return "暂时无法更新"
    case .expired: return "打开 App 更新照片"
    case .photo: return "点开回拍一张"
    }
  }
  private var content: some View {
    VStack(alignment: .leading, spacing: 8) {
      if entry.state != .signedOut, let name = entry.manifest.binding?.squadName {
        Text(name).font(.caption.weight(.semibold)).lineLimit(1)
      } else { Text("小队照片").font(.caption.weight(.semibold)) }
      if entry.state == .photo, let bytes = entry.manifest.photo?.jpeg, let image = UIImage(data: bytes) {
        GeometryReader { geometry in
          Image(uiImage: image).resizable().scaledToFill()
            .frame(width: geometry.size.width, height: geometry.size.height).clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12)).privacySensitive()
        }
      } else {
        VStack(spacing: 8) {
          Image(systemName: entry.state == .hidden ? "eye.slash" : "camera.fill")
            .font(.title2).foregroundStyle(brand)
          Text(label).font(.caption).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      if entry.state == .photo { Text(label).font(.caption2).foregroundStyle(.secondary) }
    }
    .widgetURL(entry.manifest.link(at: WidgetClock(), scheme: Bundle.main.object(forInfoDictionaryKey: "SquadlyWidgetURLScheme") as? String ?? "squadly"))
  }
  var body: some View {
    if #available(iOSApplicationExtension 17.0, *) {
      content.containerBackground(for: .widget) { Color(.systemBackground) }
    } else { content.padding(12).background(Color(.systemBackground)) }
  }
}

@main
struct SquadPhotoWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: widgetKind, provider: SquadPhotoProvider()) { entry in SquadPhotoView(entry: entry) }
      .configurationDisplayName("小队照片")
      .description("把小队的新照片带到桌面。")
      .supportedFamilies([.systemSmall, .systemMedium])
  }
}
