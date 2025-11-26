//
//  ContentView.swift
//  Minutly
//
//  Created by Benjamin Patin on 25/11/2025.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var recorder = ScreenRecorder()
    @State private var showPermissionAlert = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 24) {
            // App Title with Settings button
            HStack {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "record.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(recorder.isRecording ? .red : .primary)

                    Text("Minutly")
                        .font(.title)
                        .fontWeight(.bold)
                }

                Spacer()

                VStack {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")

                    Spacer()
                }
            }
            .padding(.top)
            
            // Status
            VStack(spacing: 8) {
                Text(recorder.isRecording ? "Recording..." : "Ready to record")
                    .font(.headline)
                    .foregroundStyle(recorder.isRecording ? .red : .secondary)
                
                if recorder.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("System Audio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Record Button
            Button(action: {
                print("🔘 Record button pressed, current state: \(recorder.isRecording ? "Recording" : "Not Recording")")
                Task {
                    if recorder.isRecording {
                        print("📍 Calling stopRecording()")
                        await recorder.stopRecording()
                        print("📍 stopRecording() returned")
                    } else {
                        print("📍 Calling startRecording()")
                        await recorder.startRecording()
                        print("📍 startRecording() returned")
                    }
                }
            }) {
                Label(
                    recorder.isRecording ? "Stop Recording" : "Start Recording",
                    systemImage: recorder.isRecording ? "stop.circle.fill" : "circle.circle.fill"
                )
                .font(.headline)
                .frame(width: 200)
                .padding()
                .background(recorder.isRecording ? Color.red : Color.accentColor)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            // Recordings List

            if !recorder.recordings.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recordings")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(recorder.recordings, id: \.self) { url in
                                RecordingRow(
                                    url: url,
                                    onDelete: {
                                        recorder.deleteRecording(at: url)
                                    },
                                    onRename: { newName in
                                        recorder.renameRecording(from: url, to: newName)
                                    },
                                    transcriptionService: recorder.transcriptionService
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            // Error Message
            if let error = recorder.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 600)
        .onAppear {
            recorder.fetchRecordings()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}



#Preview {
    ContentView()
}
