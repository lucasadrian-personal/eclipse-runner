import SwiftUI

struct CosmicBackground: View {
    var body: some View {
        ZStack {
            Theme.cosmicBackground
                .ignoresSafeArea()
            StarfieldView()
                .ignoresSafeArea()
        }
    }
}
