import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), streak: "7", intention: "Master your day.")
    }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), streak: "7", intention: "Master your day.")
        completion(entry)
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.orbitroutine.orbit")
        let streak = userDefaults?.string(forKey: "widget_streak") ?? "0"
        let intention = userDefaults?.string(forKey: "widget_intention") ?? "Set an intention today."
        
        let entry = SimpleEntry(date: Date(), streak: streak, intention: intention)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let streak: String
    let intention: String
}

struct OrbitWidgetEntryView : View {
    var entry: Provider.Entry
    var body: some View {
        ZStack {
            Color(red: 5/255, green: 1/255, blue: 18/255) // Deep Space BG #050112
            Circle() // Glowing Orb
                .fill(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.3))
                .frame(width: 150, height: 150).blur(radius: 30).offset(x: 50, y: -50)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill").foregroundColor(.orange)
                    Text("\(entry.streak) Day Streak").font(.headline).foregroundColor(.orange).bold()
                }
                Spacer()
                Text("DAILY INTENTION").font(.system(size: 10, weight: .black)).foregroundColor(.white.opacity(0.5)).tracking(1.5)
                Text("\"\(entry.intention)\"").font(.system(size: 14, weight: .semibold, design: .serif)).foregroundColor(.white).italic().lineLimit(2)
            }.padding()
        }
    }
}

struct OrbitWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OrbitWidget", provider: Provider()) { entry in
            OrbitWidgetEntryView(entry: entry)
        }.configurationDisplayName("Orbit Status").description("Keep your streak and intention on your home screen.").supportedFamilies([.systemSmall, .systemMedium])
    }
}
