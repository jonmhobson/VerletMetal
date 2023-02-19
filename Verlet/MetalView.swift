import SwiftUI
import MetalKit

class MetalViewInteractor: ObservableObject {
    let metalView = MTKView()
    let renderer: Renderer

    init() {
        renderer = Renderer(metalView: metalView)
    }
}

struct MetalView: View {
    @StateObject var viewInteractor = MetalViewInteractor()

    var body: some View {
        ZStack {
            MetalViewRepresentable(metalView: viewInteractor.metalView)
            Circle()
                .inset(by: 2)
                .stroke(Color(red: 1.0, green: 0.302, blue: 0.357), lineWidth: 1)
                .frame(width: 802, height: 802)
        }
    }
}

struct MetalViewRepresentable: NSViewRepresentable {
    let metalView: MTKView
    func makeNSView(context: Context) -> some NSView {
        metalView
    }
    func updateNSView(_ nsView: NSViewType, context: Context) {}
}

struct MetalView_Previews: PreviewProvider {
    static var previews: some View {
        MetalView()
    }
}
