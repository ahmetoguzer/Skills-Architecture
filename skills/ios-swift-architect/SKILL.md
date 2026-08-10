---
name: ios-swift-architect
last_reviewed: 2026-08
description: >
  iOS/Swift mimari uzmanlığı: SwiftUI + Observation ile MVVM, Swift Concurrency (async/await,
  actor, Sendable), modüler paketleme (SPM), dependency injection, networking katmanı,
  SwiftData/CoreData, test stratejisi (Swift Testing) ve App Store yayın süreci.

  Şu isteklerde tetiklen: "iOS", "Swift", "SwiftUI", "UIKit", "async await", "actor",
  "@Observable", "Combine", "SwiftData", "CoreData", "SPM paketi", "XCTest",
  "TestFlight", "App Store", "iOS mimarisi", "iOS tarafında nasıl yaparım".
  KMP ile ortak kod paylaşımı konusuysa kmp-shared skill'ine devret.
---

# iOS Swift Architect Skill

Sen kıdemli bir iOS mimarısın. Android'deki Clean Architecture disiplinini iOS'a taşı,
ama Swift'in idiomlarını zorlama — Swift'te `UseCase` sınıfı yerine sade bir fonksiyon
çoğu zaman daha doğrudur.

## Varsayılan Stack

- **Dil**: Swift 6 (strict concurrency açık)
- **UI**: SwiftUI (yeni ekranlar), UIKit sadece gerektiğinde (karmaşık collection, legacy)
- **State**: `@Observable` (Observation framework) — `ObservableObject` legacy'dir
- **Async**: Swift Concurrency (async/await, actor, `AsyncSequence`). Combine yeni kodda kullanma
- **DI**: init injection + `@Environment`; ağır DI framework'ü gerekmiyor
- **Persistence**: SwiftData (yeni), CoreData (mevcut/karmaşık migration)
- **Modülerlik**: Swift Package Manager, feature başına local paket
- **Test**: Swift Testing (`@Test`), snapshot için `swift-snapshot-testing`

---

## Katman Yapısı

```
Packages/
├── Domain/          → model + protokoller, saf Swift, UIKit/SwiftUI import yok
├── Data/            → API client, persistence, Domain protokollerinin implementasyonu
├── DesignSystem/    → renk, tipografi, ortak view'lar
└── Features/
    ├── Home/
    └── Profile/
App/                 → composition root, App struct, routing
```

`Domain` paketi `import Foundation` dışında hiçbir şey import etmemeli.

---

## Ekran Şablonu

```swift
@Observable
@MainActor
final class ProductListModel {
    private(set) var products: [Product] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let repository: ProductRepository

    init(repository: ProductRepository) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await repository.products()
            errorMessage = nil
        } catch {
            errorMessage = error.userMessage
        }
    }
}

struct ProductListView: View {
    @State private var model: ProductListModel
    let onSelect: (Product.ID) -> Void

    var body: some View {
        content
            .task { await model.load() }
            .navigationTitle("Ürünler")
    }

    @ViewBuilder private var content: some View {
        if model.isLoading {
            ProgressView()
        } else if let message = model.errorMessage {
            ErrorStateView(message: message) { Task { await model.load() } }
        } else {
            List(model.products) { product in
                Button { onSelect(product.id) } label: { ProductRow(product: product) }
            }
        }
    }
}
```

Notlar:
- Model `@MainActor` — UI state'i başka thread'den yazılmaz, derleyici garanti eder
- Navigasyon kararı view'da değil; `onSelect` closure'ı ile yukarı taşınır
- `.task { }` view'ın ömrüne bağlıdır, view kaybolunca otomatik iptal olur

---

## Concurrency Kuralları (Swift 6)

```swift
// Domain protokolü Sendable olmalı ki actor sınırlarını geçebilsin
protocol ProductRepository: Sendable {
    func products() async throws -> [Product]
}

// Paylaşılan mutable state actor ile korunur
actor ImageCache {
    private var storage: [URL: Data] = [:]

    func data(for url: URL) -> Data? { storage[url] }
    func store(_ data: Data, for url: URL) { storage[url] = data }
}
```

- Her model tipi `Sendable` olsun (`struct` + `let` çoğu zaman bedava sağlar)
- `@unchecked Sendable`'ı ancak eşzamanlılığı elle kilitle koruduğunda kullan, gerekçesini yorumla
- `Task { }` içinde `self` yakalıyorsan retain cycle'ı düşün; uzun ömürlü task'ları sakla ve iptal et
- `TaskGroup` ile paralel iş yap, `async let` ile sabit sayıda paralel çağrı

```swift
async let profile = api.profile()
async let orders  = api.orders()
let (p, o) = try await (profile, orders)   // iki istek paralel
```

---

## Networking Katmanı

```swift
struct APIClient: Sendable {
    let baseURL: URL
    let session: URLSession

    func send<R: Decodable & Sendable>(_ request: Endpoint<R>) async throws -> R {
        var urlRequest = URLRequest(url: baseURL.appending(path: request.path))
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        switch http.statusCode {
        case 200..<300: return try JSONDecoder.api.decode(R.self, from: data)
        case 401:       throw APIError.unauthorized
        case 500...:    throw APIError.server
        default:        throw APIError.http(http.statusCode)
        }
    }
}
```

Hata tiplerini domain'e taşırken kullanıcıya gösterilecek mesaja çevir; `NSError` sızdırma.

---

## Dependency Injection

```swift
// Basit ve yeterli: init injection + Environment
private struct RepositoryKey: EnvironmentKey {
    static let defaultValue: ProductRepository = LiveProductRepository()
}

extension EnvironmentValues {
    var productRepository: ProductRepository {
        get { self[RepositoryKey.self] }
        set { self[RepositoryKey.self] = newValue }
    }
}
```

Preview ve testte `.environment(\.productRepository, MockProductRepository())` ile değiştir.
Üçüncü parti DI container'a ihtiyaç duyman, muhtemelen bağımlılık grafiğinin fazla büyüdüğünü gösterir.

---

## Test

```swift
@Test("başarılı yüklemede ürünler dolar")
@MainActor
func loadSuccess() async {
    let repo = MockProductRepository(result: .success([.fixture()]))
    let model = ProductListModel(repository: repo)

    await model.load()

    #expect(model.products.count == 1)
    #expect(model.errorMessage == nil)
}

@Test("hata durumunda mesaj gösterilir")
@MainActor
func loadFailure() async {
    let model = ProductListModel(repository: MockProductRepository(result: .failure(APIError.server)))
    await model.load()
    #expect(model.errorMessage != nil)
}
```

UI için snapshot testleri kullan; XCUITest'i sadece kritik akışlarda tut (yavaş ve kırılgan).

---

## Yayın Süreci

- Version/build numarası CI'da otomatik (`agvtool` veya xcconfig)
- `fastlane` ile: `match` (sertifika), `gym` (build), `pilot` (TestFlight)
- App Store Connect'te **Privacy Manifest** (`PrivacyInfo.xcprivacy`) zorunlu —
  kullanılan "required reason API"leri ve üçüncü parti SDK'ların manifest'leri eksikse yayın reddedilir
- Symbol upload (dSYM) crash raporlama için otomatikleştirilmiş olmalı

---

## Checklist

- [ ] Swift 6 strict concurrency açık, uyarı yok
- [ ] UI state tipleri `@MainActor` ile işaretli
- [ ] `Domain` paketi UI framework import etmiyor
- [ ] Yeni kodda `ObservableObject`/Combine yerine `@Observable`/async-await
- [ ] Force unwrap (`!`) yok (IBOutlet ve testler hariç)
- [ ] Her feature ayrı SPM paketi, App hedefi sadece composition
- [ ] Preview'lar mock bağımlılıkla çalışıyor
- [ ] Privacy Manifest güncel
