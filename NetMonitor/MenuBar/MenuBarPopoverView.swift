//
//  MenuBarPopoverView.swift
//  NetMonitor
//
//  Created on 2026-01-13.
//

import SwiftUI

/// Menu bar popover content view (stub - full implementation in Task 9)
struct MenuBarPopoverView: View {
    @Bindable var session: MonitoringSession
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("NetMonitor")
                .font(.headline)

            HStack {
                Circle()
                    .fill(session.isMonitoring ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(session.isMonitoring ? "Monitoring" : "Stopped")
            }

            Button("Close") {
                onClose()
            }
        }
        .padding()
        .frame(width: 320, height: 200)
    }
}
