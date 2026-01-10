import SwiftUI

struct DashboardView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Session monitoring will appear here")
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Dashboard")
    }
}

#Preview {
    DashboardView()
}
