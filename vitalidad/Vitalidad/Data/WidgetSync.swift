import Foundation
import WidgetKit

extension HealthStore {
    /// Resumen para los widgets: puntuaciones, frase del día y las tarjetas que tienes en Hoy.
    func widgetData() -> WidgetData {
        let r = ScoreEngine.report(self)
        var w = WidgetData()
        w.recovery = r.recovery?.value
        w.sleep = r.sleep?.value
        w.effort = r.effort?.value
        w.summary = r.summary
        w.mood = r.mood.key
        w.slept = lastNight.map { Fmt.duration($0.asleep) }
        w.advice = r.advice
        w.stepsNow = value(.steps, on: today)
        w.stepsGoal = baseline(.steps)?.median
        w.bedtime = ScoreEngine.usualBedtime(self)
        w.night = r.mood == .night
        let cards = TodayCards.decode(UserDefaults.standard.string(forKey: "hoyTarjetas") ?? TodayCards.defaultString)
        w.items = cards.compactMap { Explainer.insight($0, store: self) }.map { i in
            WidgetData.Item(id: i.metric.rawValue, title: i.metric.title, symbol: i.metric.symbol, value: i.display,
                            unit: i.metric.unit, status: i.status.rawValue, color: i.metric.color.wHex)
        }
        return w
    }

    /// Lo manda al servidor de casa y avisa a los widgets para que lo recojan.
    func pushWidget() async {
        guard !Launch.demo else { return }
        if await widgetData().upload() {
            widgetSent = .now
            widgetFailed = false
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            widgetFailed = true
        }
    }
}
