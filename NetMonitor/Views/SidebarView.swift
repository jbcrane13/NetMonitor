import SwiftUI

struct SidebarView: View {
    @Binding var selection: Section?

    var body: some View {
        List(Section.allCases, selection: $selection) { section in
            Label(section.rawValue, systemImage: section.iconName)
                .tag(section)
                .accessibilityIdentifier("sidebar_\(section.rawValue.lowercased())")
        }
        .navigationTitle("NetMonitor")
        .frame(minWidth: 220)
        .accessibilityIdentifier("sidebar_navigation")
    }
}

#Preview {
    @Previewable @State var selection: Section? = .dashboard

    SidebarView(selection: $selection)
}
