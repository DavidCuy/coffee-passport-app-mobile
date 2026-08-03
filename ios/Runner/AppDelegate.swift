import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Requerido por `google_maps_flutter` (feature `shop_directory`, vista
    // de mapa). ⚠️ Placeholder: sin una API key real de Google Maps
    // (Google Cloud Console, restringida al bundle id de este target), el
    // mapa compila pero no carga teselas en iOS. Reemplazar antes de un
    // build real de QA/producción — mismo aviso que
    // `android/app/src/main/AndroidManifest.xml`.
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
