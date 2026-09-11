//
//  LogsView.swift
//  Stingray
//
//  Created by Ben Roberts on 6/30/26.
//

import SwiftUI

/// Shows the current session's logs, newest first, filtered to a minimum severity.
/// Logs are only held in memory for the life of the process, so this list is empty on a fresh launch.
public struct LogsView: View {
    /// Minimum severity to display. Changing it rebuilds `logEntries`
    @State private var logVerbosity: LogLevel = .info
    /// Flattened log chain at the current verbosity. `nil` while the list is still being built
    @State private var logEntries: [LogEntry]?

    public var body: some View {
        VStack {
            Picker("Log Verbosity", selection: self.$logVerbosity) {
                ForEach(LogLevel.allCases, id: \.self) { option in
                    Text(option.localized).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if let logEntries {
                if logEntries.isEmpty {
                    Spacer()
                    Text("No logs available")
                    Spacer()
                }
                else {
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(logEntries) { log in
                                Button {} label: {
                                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                                        Text(log.timestamp.formatted(date: .omitted, time: .standard))
                                        Text(log.level.localized)
                                            .foregroundColor({
                                                switch log.level {
                                                case .debug: nil
                                                case .info: Color.blue
                                                case .warning: Color.yellow
                                                case .error: Color.orange
                                                case .critical: Color.red
                                                }
                                            }())
                                            .frame(width: 125, alignment: .center)
                                        Text(log.message)
                                            .multilineTextAlignment(.leading)
                                        Spacer(minLength: 0)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            else {
                Spacer()
                ProgressView("Loading Logs...")
                Spacer()
            }
        }
        .onChange(of: self.logVerbosity, initial: true) {
            // Build the log array to display
            Task {
                var logs: [LogEntry] = []
                var nextLog = Log.lastLogEntry
                while let goodNextLog = nextLog {
                    nextLog = goodNextLog.previous
                    if goodNextLog.level.severity < self.logVerbosity.severity { continue }
                    logs.append(goodNextLog)
                }
                self.logEntries = logs
            }
        }
        .padding([.horizontal, .top], 64)
    }
}
