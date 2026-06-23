import WidgetKit
import SwiftUI

// 1. The Provider tells the widget when to update and what data to load.
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), title: "Placeholder Habit", streak: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), title: "Snapshot Habit", streak: 3)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        
        // 🚨 GRAB THE FLUTTER DATA HERE 🚨
        let userDefaults = UserDefaults(suiteName: "group.com.orbitroutine.orbit")
        let title = userDefaults?.string(forKey: "title") ?? "No Habit Data"
        let streak = userDefaults?.integer(forKey: "streak") ?? 0

        let entry = SimpleEntry(date: Date(), title: title, streak: streak)

        // Policy '.never' means iOS won't update this on its own schedule.
        // It will only update when your Flutter app tells it to via HomeWidget.updateWidget()
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// 2. The Entry holds the data that gets passed into your UI.
struct SimpleEntry: TimelineEntry {
    let date: Date
    let title: String
    let streak: Int
}

// 3. The View defines what the widget actually looks like on the home screen.
struct HabitWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            // A dark blue background matching Orbit's theme
            Color(red: 5/255, green: 16/255, blue: 36/255)
            
            VStack(spacing: 8) {
                Text(entry.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                if entry.streak > 0 {
                    Text("🔥 \(entry.streak) Day Streak!")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }
            .padding()
        }
        if #available(iOS 17.0, *) {
            self
                .containerBackground(Color(red: 5/255, green: 16/255, blue: 36/255), for: .widget)
                .widgetURL(URL(string: "orbit://habit?title=\(entry.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"))
        } else {
            self
                .background(Color(red: 5/255, green: 16/255, blue: 36/255))
                .widgetURL(URL(string: "orbit://habit?title=\(entry.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"))
        }
    }
}

// 4. The Main Widget Configuration
struct HabitWidget: Widget {
    // 🚨 This MUST exactly match the `iOSName` you pass to `HomeWidget.updateWidget()` in Flutter!
    let kind: String = "HabitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            HabitWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Habit Widget")
        .description("Keep track of your habits directly from your home screen.")
    }
}

#Preview {
    HabitWidgetEntryView(entry: SimpleEntry(date: Date(), title: "Read 10 Pages", streak: 5))
}
